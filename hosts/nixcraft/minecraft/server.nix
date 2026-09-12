{ pkgs, lib, ... }:

let
  serverName = "survival";
  dataDir = "/srv/minecraft";

  # Mods are pinned by URL + hash for reproducible rebuilds. To add/update, run:
  #   nix run github:Infinidoge/nix-minecraft#nix-modrinth-prefetch -- <versionId>
  mods = {
    fabric-api = pkgs.fetchurl {
      url = "https://cdn.modrinth.com/data/P7dR8mSH/versions/NqwNSxwA/fabric-api-0.158.0%2B26.2.jar";
      sha512 = "4c2c1ebe74ffd54875a01ff371b53ba3d8674ac98d561f7dae02a96d3d37fbdbc5f5abc6e820f73b6154d6f873ddd05a442b0998ed2d456863dc0ad972e040a6";
    };
    carpet = pkgs.fetchurl {
      url = "https://cdn.modrinth.com/data/TQTTVgYE/versions/bGrLxJ8v/fabric-carpet-26.2%2Bv260616.jar";
      sha512 = "8b8fac6979bd3153f5cfb4faa6bab52e1357eab814492a6658f3c0e1ac2856ad37a626c0a03a0839c39abb7bf56661f77b09d05d10ac01173bcdd373a33c6265";
    };
    carpet-extra = pkgs.fetchurl {
      url = "https://cdn.modrinth.com/data/VX3TgwQh/versions/Z5BJRYil/carpet-extra-26.2-26.2.jar";
      sha512 = "39bcfd81340cee04c2e9b9e61d628c297a13af2f96464d0081040ffa9e6336a64d36d95b76371aa00f343cef334bff3d0c6773cfb96994a9441e62ff7632da8d";
    };
    carpet-tis-addition = pkgs.fetchurl {
      url = "https://cdn.modrinth.com/data/jE0SjGuf/versions/lW1s6HL1/carpet-tis-addition-v1.82.4-mc26.2.jar";
      sha512 = "ebe83e448b882c67afb9fca74899bd1146e23eca1fc25e412b5793e884f79ef4020290051951746ab6117f80d311072c2cbfca7a7c553915cfcc81488c8cd363";
    };
    servux = pkgs.fetchurl {
      url = "https://cdn.modrinth.com/data/zQhsx8KF/versions/Er2wlain/servux-fabric-26.2-0.11.3.jar";
      sha512 = "42ec8769ba50ecf1ac6b3da4caa554d5dad6e8226ebb4faf0918a483c0a7823e3a1a69ae39c1157029209b4272df6a6fb025c5b797fd0d4402ab9ddcc800ae67";
    };
    lithium = pkgs.fetchurl {
      url = "https://cdn.modrinth.com/data/gvQqBUqZ/versions/f7vZ0VWU/lithium-fabric-0.25.3%2Bmc26.2.jar";
      sha512 = "148b638f3c6229fbaf487120a2344a0af5e411a5aa6533d5db9d75da0a8c0d8304f63eb4cca13f4d03b2c9b4c23d559dd74c1d832422ef8a3087bd005e62a8bd";
    };
    ferritecore = pkgs.fetchurl {
      url = "https://cdn.modrinth.com/data/uXXizFIs/versions/d5ddUdiB/ferritecore-9.0.0-fabric.jar";
      sha512 = "d81fa97e11784c19d42f89c2f433831d007603dd7193cee45fa177e4a6a9c52b384b198586e04a0f7f63cd996fed713322578bde9a8db57e1188854ae5cbe584";
    };
    krypton = pkgs.fetchurl {
      url = "https://cdn.modrinth.com/data/fQEb0iXm/versions/5WeL0Nkz/krypton-0.3.1.jar";
      sha512 = "b8d9af34cd0050493afb8a6232cb8f785daa9d8887b7045f6e6a53c6bb9b5ffc4318fd9b0347a940eacfeba4773f10cb80ae0be1e79ce4c1888f96eda21e564e";
    };
    spark = pkgs.fetchurl {
      url = "https://cdn.modrinth.com/data/l6YH9Als/versions/iYFOl6lQ/spark-1.10.173-fabric.jar";
      sha512 = "1dcbf2b76ceacf07523afaeaf63d3625b0318077cc6ce588bb701aea4a494bc2a5179fd2ca5aeda9513c6a2248c2ec590387e8aec6ac9fd8e3d01760bbc3dbfb";
    };
  };
in
{
  services.minecraft-servers = {
    enable = true;
    eula = true;
    inherit dataDir;

    servers.${serverName} = {
      enable = true;
      openFirewall = true;

      # Keep Java 25 override until nix-minecraft picks the right JRE here.
      package = pkgs.fabricServers.fabric-26_2.override {
        jre_headless = pkgs.jdk25_headless;
      };

      # Fixed 6G heap leaves RAM for off-heap JVM usage and page cache.
      jvmOpts = lib.concatStringsSep " " [
        "-Xms6G"
        "-Xmx6G"
        "-XX:+UseG1GC"
        "-XX:+ParallelRefProcEnabled"
        "-XX:MaxGCPauseMillis=200"
        "-XX:+UnlockExperimentalVMOptions"
        "-XX:+DisableExplicitGC"
        "-XX:+AlwaysPreTouch"
        "-XX:G1NewSizePercent=30"
        "-XX:G1MaxNewSizePercent=40"
        "-XX:G1HeapRegionSize=8M"
        "-XX:G1ReservePercent=20"
        "-XX:G1HeapWastePercent=5"
        "-XX:G1MixedGCCountTarget=4"
        "-XX:InitiatingHeapOccupancyPercent=15"
        "-XX:G1MixedGCLiveThresholdPercent=90"
        "-XX:G1RSetUpdatingPauseTimePercent=5"
        "-XX:SurvivorRatio=32"
        "-XX:+PerfDisableSharedMem"
        "-XX:MaxTenuringThreshold=1"
      ];

      serverProperties = {
        server-port = 25565;
        motd = "\\u00A7b\\u00A7lnixcraft \\u00A78\\u00BB \\u00A77survival & technical\\n\\u00A78\\u00BB \\u00A77rebuilt, never reinstalled";
        difficulty = "hard";
        gamemode = "survival";
        max-players = 20;
        online-mode = true;
        white-list = true;
        enforce-whitelist = true;
        enforce-secure-profile = true;
        spawn-protection = 0;
        pvp = true;
        view-distance = 10;
        simulation-distance = 10;
        enable-command-block = true;
        # Keep vanilla default explicit; lower values can break redstone chains.
        max-chained-neighbor-updates = 1000000;
        enable-rcon = false;
      };

      whitelist = {
        ScoreSpy = "8c98c93b-e269-446e-8df8-23c8a82b5397";
        ScathaPro = "d94be89d-b808-481d-a1dd-ed9b564d8e8d";
        Samwy = "92a17f3d-abd8-49f0-9342-797dbf1f2cf0";
        bedwargod = "b0af0d0b-6760-48f5-bbac-5c5f15db0222";
        WormPro = "4cd5441f-94b7-4bbf-a809-7578eb6bd5b4";
        coolrunnings22 = "72ec6d21-f772-4db3-9e8f-fffc45fa4c76";
        Golden_Wraith = "5e584a8e-c3da-4c99-ad04-ea1696334cf5";
      };

      operators = {
        ScoreSpy = "8c98c93b-e269-446e-8df8-23c8a82b5397";
        ScathaPro = "d94be89d-b808-481d-a1dd-ed9b564d8e8d";
      };

      symlinks.mods = pkgs.linkFarmFromDrvs "mods" (lib.attrValues mods);
    };
  };
}
