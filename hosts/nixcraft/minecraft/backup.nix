{ config, pkgs, ... }:

let
  serverName = "survival";
  dataDir = "/srv/minecraft";
  serverDir = "${dataDir}/${serverName}";
  backupDir = "/var/backup/minecraft";
  backupRetentionDays = 14;
  consoleSocket =
    config.services.minecraft-servers.managementSystem.tmux.socketPath serverName;
in
{
  systemd.services."minecraft-backup-${serverName}" = {
    description = "Snapshot the ${serverName} Minecraft world";
    after = [ "minecraft-server-${serverName}.service" ];

    serviceConfig = {
      Type = "oneshot";
      User = config.services.minecraft-servers.user;
      Group = config.services.minecraft-servers.group;
      Nice = 19;
      IOSchedulingClass = "idle";
    };

    path = with pkgs; [ tmux gnutar zstd coreutils findutils ];

    script = ''
      set -euo pipefail

      stamp="$(date +%Y-%m-%dT%H-%M-%S)"
      archive="${backupDir}/${serverName}-$stamp.tar.zst"

      mkdir -p ${backupDir}

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
