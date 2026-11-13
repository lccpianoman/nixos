# Test Fabric server on 26.3, ahead of possibly moving nixcraft here. Structure
# follows hosts/nixcraft/minecraft/; the differences are the version, the
# multicore chunk mods, ZGC, NUMA pinning, and backups landing on the pool.
#
# LAN-only: the firewall port is open but the router forwards only 80/443.
# Going public later is a router forward, nothing here.
#
# The world lives on the NVMe (/srv/minecraft on root), not the raidz2 pool:
# region-file writes are small and random, which spindles are worst at.
{ config, pkgs, lib, ... }:

let
  # Parked after testing: false = no start at boot and no nightly backup timer.
  # Everything else stays declared; `systemctl start` still works for a one-off.
  active = false;

  serverName = "survival";
  dataDir    = "/srv/minecraft";
  serverDir  = "${dataDir}/${serverName}";
  # On storage/backups, so it is off the single boot disk and under sanoid.
  backupDir  = "/srv/backups/minecraft";
  backupRetentionDays = 14;
  mcUser  = config.services.minecraft-servers.user;
  mcGroup = config.services.minecraft-servers.group;
  consoleSocket =
    config.services.minecraft-servers.managementSystem.tmux.socketPath serverName;

  # Pinned by URL + hash. To add/update one:
  #   nix run github:Infinidoge/nix-minecraft#nix-modrinth-prefetch -- <versionId>
  #
  # No ScalableLux (or Moonrise): both are Starlight-based, which reorders light
  # updates and breaks light suppression, and Carpet means technical play.
  mods = {
    fabric-api = pkgs.fetchurl {
      url = "https://cdn.modrinth.com/data/P7dR8mSH/versions/Zns5SSRA/fabric-api-0.166.2%2B26.3.jar";
      sha512 = "fb686a9fa923248328107a12498229d6951e316257f18b7d0e4cbd6885ba447ed50a44076a8a5ba47cfe2043b329db3587ab000aeab1face26b2587a5d4ba6b5";
    };
    carpet = pkgs.fetchurl {
      url = "https://cdn.modrinth.com/data/TQTTVgYE/versions/yt9oDFOj/fabric-carpet-26.3%2Bv260915.jar";
      sha512 = "7a479ba69eb5049cb94365d5044bd58c9f970c50b3484861fe3675f1917f7c99c1b1f50a5e01bdd9ded940d76a995539009a3656e05be2f513f20ec14de991a7";
    };
    # Upstream (gnembon) has no 26.3 build and its fabric.mod.json hard-requires
    # 26.2.x. This fork is upstream plus a small API port, built and release-
    # uploaded by its own CI with gametests. Swap back once upstream ships 26.3.
    carpet-extra = pkgs.fetchurl {
      url = "https://github.com/vvcDaDa/carpet-extra/releases/download/v26.3/carpet-extra-26.3.jar";
      sha256 = "f3f7a39a3525c32bc364c14a53efd08ec2a22cd66c976ae4e71f7aee1d33cf20";
    };
    # Fixes MC-311727: 26.3 checks support blocks before applying the player's
    # move, so it force-resends blocks and logs "standing on air" every ~10 s.
    # One mixin, reviewed; GitHub-only. Drop once Mojang fixes MC-311727.
    standing-on-air = pkgs.fetchurl {
      url = "https://github.com/syrupderg/standing-on-air/releases/download/1.0.0/standing_on_air-fabric-26.3-1.0.0.jar";
      sha256 = "916d6d70b86b852f5d733fc628728237d62add969997989b77828e58b3cf6e7a";
    };
    carpet-tis-addition = pkgs.fetchurl {
      url = "https://cdn.modrinth.com/data/jE0SjGuf/versions/EkoQdQKl/carpet-tis-addition-v1.83.2-mc26.3.jar";
      sha512 = "12df137d6ac7f6796eec9570821d2d4d610d0844259281921d1f2718617675157c554bb8a97a1d878c4be2a534003611eee9e38f72da0ae67e768eebfc1428a5";
    };
    servux = pkgs.fetchurl {
      url = "https://cdn.modrinth.com/data/zQhsx8KF/versions/azA4UG3T/servux-fabric-26.3-0.12.2.jar";
      sha512 = "ea630371c61502b2787fbdfc3c94f6bf218c7ca20e1579682af4122e431c538f8b11d239acb16f79203fa1d1d8e6d8479673e28d1432effa843729c0280208bc";
    };
    lithium = pkgs.fetchurl {
      url = "https://cdn.modrinth.com/data/gvQqBUqZ/versions/fWv5bnZk/lithium-fabric-0.26.3%2Bmc26.3.jar";
      sha512 = "2ca92fb530135d2baddf0ba4cc4f93976234876a38c4aa02b487b2552400f005afcfbeebf5373fb4396fe2020537a42d7597b8da5a52b904355ef51d5fef07ad";
    };
    ferritecore = pkgs.fetchurl {
      url = "https://cdn.modrinth.com/data/uXXizFIs/versions/d5ddUdiB/ferritecore-9.0.0-fabric.jar";
      sha512 = "d81fa97e11784c19d42f89c2f433831d007603dd7193cee45fa177e4a6a9c52b384b198586e04a0f7f63cd996fed713322578bde9a8db57e1188854ae5cbe584";
    };
    # Alpha devbuild: multithreaded chunk gen/IO, the one place 56 threads pay off.
    c2me = pkgs.fetchurl {
      url = "https://cdn.modrinth.com/data/VSNURh3q/versions/aOP6eqZA/c2me-fabric-mc26.3-0.4.2-alpha.0.116.jar";
      sha512 = "5db513d05f909d7b09d035b40f0d31945ec8911f4d7b75fa258bb6e6338761b8847c9d1804d40b647e1781cfc143ff7dd0e0a4389f19ec46e031be7bbb7b5052";
    };
    # Alpha, on trial: ticks entities in parallel, which is most of this box's
    # tick cost. `async config toggle` flips it live for A/B profiling.
    async = pkgs.fetchurl {
      url = "https://cdn.modrinth.com/data/vEC2jm6I/versions/gcduhoHv/async-fabric-0.2.5%2Balpha-26.3.jar";
      sha512 = "dc7662973c1493ccd29ccf390583192bc49d33782dfd5245002427d160a2752fb6b4b09e9e1c7a3dd0f3f373454ed0ea4f9ae9a23752994dcb389662506489dc";
    };
    vmp = pkgs.fetchurl {
      url = "https://cdn.modrinth.com/data/wnEe9KBa/versions/2TFDVjDf/vmp-fabric-mc26.3-0.2.0%2Bbeta.7.238-all.jar";
      sha512 = "c8658ccf8818a258e1160a2d394c80fd52708611570dc28d6bc391671a23e193760766ef77ddc5907e1a3a757cf20f4def67ae2bc184269effa547da1f377667";
    };
    krypton = pkgs.fetchurl {
      url = "https://cdn.modrinth.com/data/fQEb0iXm/versions/UugdIYJw/krypton-0.3.2.jar";
      sha512 = "d1d57ebd41395b75b01f130cd9503eb8d208212424a399ff9f367f50be8fbc1c6472442b33c686e777c3148f6a609520e8fb732c755157c358cb207fd4d1123a";
    };
    chunky = pkgs.fetchurl {
      url = "https://cdn.modrinth.com/data/fALzjamp/versions/86FKD9qx/Chunky-Fabric-1.5.66.jar";
      sha512 = "6f0323daa69d61bd3b3fbe9d8b713664d9b7c69182183f8dcff6362b43783639778a96e32215dbfd329588f06b60a5d93656dbb1d391c660db203482aa972d5e";
    };
    spark = pkgs.fetchurl {
      url = "https://cdn.modrinth.com/data/l6YH9Als/versions/e3hsPc1o/spark-1.10.187-fabric.jar";
      sha512 = "c74bf5d5a16b2445ec6ea717eac756412b272a8015e91f91a7bf5a27e6f2f99c4a11878d434510f941f37b0344b3a7d1ba0dd6c34e80642762c48fb6e9a93894";
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
      autoStart = active;
      openFirewall = true;

      # Same Java 25 override as nixcraft; see the pins table in docs/operations.md.
      package = pkgs.fabricServers.fabric-26_3.override {
        jre_headless = pkgs.jdk25_headless;
      };

      # ZGC rather than nixcraft's G1: RAM is plentiful here and ZGC keeps pauses
      # sub-millisecond. Heap is fixed and pre-touched so it is never grown mid-game.
      jvmOpts = lib.concatStringsSep " " [
        "-Xms10G"
        "-Xmx10G"
        "-XX:+UseZGC"
        "-XX:+AlwaysPreTouch"
        "-XX:+DisableExplicitGC"
        "-XX:+UseTransparentHugePages"
        "-XX:+UseCompactObjectHeaders"
        "-XX:+PerfDisableSharedMem"
      ];

      serverProperties = {
        server-port = 25565;
        motd = "\\u00A7b\\u00A7lcalliope \\u00A78\\u00BB \\u00A77test server";
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
        # Matches nixcraft so farms behave the same; drop to 6-8 if spark says tick-bound.
        simulation-distance = 10;
        enable-command-block = true;
        # Keep vanilla default explicit; lower values can break redstone chains.
        max-chained-neighbor-updates = 1000000;
        enable-rcon = false;
      };

      inherit (import ../../common/minecraft-players.nix) whitelist operators;

      symlinks.mods = pkgs.linkFarmFromDrvs "mods" (lib.attrValues mods);
    };
  };

  # Keep the JVM on socket 0, CPUs and memory both: the tick thread is latency
  # bound and cross-socket (QPI) memory access slows it. C2ME still gets 28 threads.
  # The tmux server is forked from ExecStart, so java inherits both policies.
  systemd.services."minecraft-server-${serverName}".serviceConfig = {
    NUMAPolicy   = "bind";
    NUMAMask     = "0";
    CPUAffinity  = "numa";
    # C2ME demotes its workers to SCHED_BATCH|RESET_ON_FORK so the tick and Async
    # threads win; RestrictRealtime's seccomp rejects the flagged policy. Real-time
    # stays blocked regardless: LimitRTPRIO is 0.
    RestrictRealtime = lib.mkForce false;
  };

  # Console socket and server files without sudo, as on nixcraft.
  users.users.luke.extraGroups = [ "minecraft" ];

  # Nightly world snapshot; same pause/flush/resume as nixcraft's backup.nix.
  systemd.services."minecraft-backup-${serverName}" = {
    description = "Snapshot the ${serverName} Minecraft world";
    after = [ "minecraft-server-${serverName}.service" ];

    unitConfig.RequiresMountsFor = [ "/srv/backups" ];

    serviceConfig = {
      Type  = "oneshot";
      User  = mcUser;
      Group = mcGroup;
      # /srv/backups is 0770 luke:media; the group is what lets this user reach it.
      SupplementaryGroups = [ "media" ];
      Nice = 19;
      IOSchedulingClass = "idle";
    };

    path = with pkgs; [ tmux gnutar zstd coreutils findutils ];

    script = ''
      set -euo pipefail

      stamp="$(date +%Y-%m-%dT%H-%M-%S)"
      archive="${backupDir}/${serverName}-$stamp.tar.zst"

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
        console "save-off"
        console "save-all flush"
        sleep 10
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

      # sanoid's daily storage/backups snapshots keep pruned archives a week longer.
      find ${backupDir} -name '${serverName}-*.tar.zst' -type f \
        -mtime +${toString backupRetentionDays} -delete
    '';
  };

  systemd.timers."minecraft-backup-${serverName}" = {
    # enable = false masks the timer, so a rebuild stops it rather than leaving it armed.
    enable = active;
    description = "Nightly ${serverName} world snapshot";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "04:00";
      Persistent = true;
      RandomizedDelaySec = "10m";
    };
  };

  # Lands on the NVMe if the pool failed to mount; harmless, since the backup
  # unit's RequiresMountsFor keeps it from writing there.
  systemd.tmpfiles.rules = [
    "d ${backupDir} 0750 ${mcUser} ${mcGroup} -"
  ];
}
