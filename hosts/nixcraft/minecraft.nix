{ pkgs, config, lib, ... }:

let
  serverName = "survival";
  dataDir = "/srv/minecraft";
  serverDir = "${dataDir}/${serverName}";
  backupDir = "/var/backup/minecraft";
  backupRetentionDays = 14;

  # Console socket for the server's tmux session. Writing to it is how the
  # backup job talks to the running server (save-off / save-all / save-on).
  consoleSocket =
    config.services.minecraft-servers.managementSystem.tmux.socketPath serverName;

  # Mods are pinned by URL + hash so a rebuild always produces the identical
  # mod set. To add or bump one, grab the version ID from the Modrinth page
  # and run:
  #   nix run github:Infinidoge/nix-minecraft#nix-modrinth-prefetch -- <versionId>
  # All of these must match the Minecraft version below — a stale jar is the
  # usual cause of the server refusing to start after a version bump.
  mods = {
    # Required by most Fabric mods.
    fabric-api = pkgs.fetchurl {
      url = "https://cdn.modrinth.com/data/P7dR8mSH/versions/NqwNSxwA/fabric-api-0.158.0%2B26.2.jar";
      sha512 = "4c2c1ebe74ffd54875a01ff371b53ba3d8674ac98d561f7dae02a96d3d37fbdbc5f5abc6e820f73b6154d6f873ddd05a442b0998ed2d456863dc0ad972e040a6";
    };
    # General server-tick optimisations, no behaviour changes.
    lithium = pkgs.fetchurl {
      url = "https://cdn.modrinth.com/data/gvQqBUqZ/versions/f7vZ0VWU/lithium-fabric-0.25.3%2Bmc26.2.jar";
      sha512 = "148b638f3c6229fbaf487120a2344a0af5e411a5aa6533d5db9d75da0a8c0d8304f63eb4cca13f4d03b2c9b4c23d559dd74c1d832422ef8a3087bd005e62a8bd";
    };
    # Deduplicates blockstate data — large heap saving on big worlds.
    ferritecore = pkgs.fetchurl {
      url = "https://cdn.modrinth.com/data/uXXizFIs/versions/d5ddUdiB/ferritecore-9.0.0-fabric.jar";
      sha512 = "d81fa97e11784c19d42f89c2f433831d007603dd7193cee45fa177e4a6a9c52b384b198586e04a0f7f63cd996fed713322578bde9a8db57e1188854ae5cbe584";
    };
    # Faster network stack.
    krypton = pkgs.fetchurl {
      url = "https://cdn.modrinth.com/data/fQEb0iXm/versions/5WeL0Nkz/krypton-0.3.1.jar";
      sha512 = "b8d9af34cd0050493afb8a6232cb8f785daa9d8887b7045f6e6a53c6bb9b5ffc4318fd9b0347a940eacfeba4773f10cb80ae0be1e79ce4c1888f96eda21e564e";
    };
    # Dynamic mobcaps / tick throttling. Server-side only.
    servercore = pkgs.fetchurl {
      url = "https://cdn.modrinth.com/data/4WWQxlQP/versions/edrtnY9v/servercore-fabric-1.5.19%2B26.2.jar";
      sha512 = "aa4cfc93f8e02172910302444330e37713dfcf2047d28e55eb7323a3cd5d51493374a0959aa3e626ec2bf43fc707a755508b83454bb34b6d57d65c069929074b";
    };
    # Profiler — `/spark tps` and `/spark profiler` for diagnosing lag.
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

      # Fabric for Minecraft 26.2. Attribute names replace "." with "_", so
      # 26.2 -> fabric-26_2. The Fabric loader is the latest pinned by the
      # nix-minecraft flake input; it moves only when that input is updated.
      #
      # The jre_headless override is required, not cosmetic. Minecraft 26.2 is
      # compiled for Java 25 (class file version 69), but nix-minecraft only
      # selects a matching JDK for `vanillaServers` — `mkTextileServer`, which
      # builds the Fabric/Quilt launchers, takes jre_headless from the package
      # scope and so silently gets nixpkgs' default Java 21. The server then
      # dies on every start with:
      #   UnsupportedClassVersionError: net/minecraft/bundler/Main has been
      #   compiled by a more recent version of the Java Runtime (class file
      #   version 69.0) ... only recognizes class file versions up to 65.0
      # Recheck on nix-minecraft updates; drop this once it passes the right JDK.
      package = pkgs.fabricServers.fabric-26_2.override {
        jre_headless = pkgs.jdk25_headless;
      };

      # Aikar's G1GC flags. 6 GB heap on an 8 GB box leaves headroom for the
      # JVM's own off-heap use and the OS page cache — handing the heap all
      # 8 GB is the classic way to get the server OOM-killed.
      # Xms == Xmx on purpose: a fixed heap avoids resize pauses.
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
        motd = "nixcraft";
        difficulty = "normal";
        gamemode = "survival";
        max-players = 10;
        online-mode = true;
        white-list = true;
        # Without this, players already connected when the whitelist changes
        # are not re-checked.
        enforce-whitelist = true;
        # Only meaningful with online-mode off; set explicitly so a future
        # change to online-mode can't silently drop IP-based protection.
        enforce-secure-profile = true;
        spawn-protection = 0;
        view-distance = 10;
        simulation-distance = 8;
        # RCON is a plaintext protocol with a password in server.properties;
        # the tmux console covers admin access, so leave it off.
        enable-rcon = false;
      };

      whitelist = {
        ScoreSpy = "8c98c93b-e269-446e-8df8-23c8a82b5397";
        ScathaPro = "d94be89d-b808-481d-a1dd-ed9b564d8e8d";
        Samwy = "92a17f3d-abd8-49f0-9342-797dbf1f2cf0";
        bedwargod = "b0af0d0b-6760-48f5-bbac-5c5f15db0222";
      };

      operators = {
        ScoreSpy = "8c98c93b-e269-446e-8df8-23c8a82b5397";
      };

      # Replace the whole mods directory atomically. linkFarmFromDrvs builds a
      # store directory of just these jars, so a removed mod actually
      # disappears instead of lingering on disk.
      symlinks.mods = pkgs.linkFarmFromDrvs "mods" (lib.attrValues mods);
    };
  };

  # ---------------------------------------------------------------------
  # World backups (local snapshots on this host).
  #
  # Deliberately local-only for now. That protects against the common cases —
  # griefing, a bad command, a corrupt chunk — but NOT against losing the VPS
  # itself. If this world becomes worth keeping, add an offsite restic target
  # the way nixvps backs up Vaultwarden.
  # ---------------------------------------------------------------------
  systemd.services."minecraft-backup-${serverName}" = {
    description = "Snapshot the ${serverName} Minecraft world";
    # Never snapshot mid-generation of the world files.
    after = [ "minecraft-server-${serverName}.service" ];

    serviceConfig = {
      Type = "oneshot";
      User = config.services.minecraft-servers.user;
      Group = config.services.minecraft-servers.group;
      # tar reads the live world; nice it so backups never cost tick time.
      Nice = 19;
      IOSchedulingClass = "idle";
    };

    path = with pkgs; [ tmux gnutar zstd coreutils findutils ];

    script = ''
      set -euo pipefail

      stamp="$(date +%Y-%m-%dT%H-%M-%S)"
      archive="${backupDir}/${serverName}-$stamp.tar.zst"

      mkdir -p ${backupDir}

      # Only talk to the console if the server is actually up; a backup of a
      # stopped server is just a plain copy and is already consistent.
      server_running() {
        tmux -S ${consoleSocket} has-session 2>/dev/null
      }

      console() {
        tmux -S ${consoleSocket} send-keys C-u "$1" Enter
      }

      resume_saves() {
        if server_running; then
          console "save-on" || true
        fi
      }

      if server_running; then
        # Flush pending writes, then hold further ones for the duration of the
        # copy. Without save-off, tar can capture a half-written region file.
        console "save-off"
        console "save-all flush"
        # save-all is asynchronous — there is no completion signal on stdout,
        # so give the flush a moment to land before reading the files.
        sleep 10
        # Guarantee saves resume even if tar fails or the unit is killed.
        trap resume_saves EXIT
      fi

      tar \
        --use-compress-program='zstd -3 -T0' \
        --exclude=./mods \
        --exclude=./logs \
        --exclude=./crash-reports \
        --exclude=./cache \
        --exclude=./libraries \
        --exclude=./versions \
        --exclude=./.fabric \
        -cf "$archive" -C ${serverDir} .

      # Retention. Runs after a successful tar only, so a failing backup can
      # never prune away the last good snapshot.
      find ${backupDir} -name '${serverName}-*.tar.zst' -type f \
        -mtime +${toString backupRetentionDays} -delete
    '';
  };

  systemd.timers."minecraft-backup-${serverName}" = {
    description = "Nightly ${serverName} world snapshot";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "04:00";
      Persistent = true;
      RandomizedDelaySec = "10m";
    };
  };

  systemd.tmpfiles.rules = [
    "d ${backupDir} 0750 ${config.services.minecraft-servers.user} ${config.services.minecraft-servers.group} -"
  ];
}
