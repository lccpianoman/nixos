{ pkgs, lib, ... }:

let
  sshPort = 47291;

  # Keep Caddy trusted proxies and fail2ban ignoreip in sync.
  cloudflareRanges = lib.concatStringsSep " " [
    "173.245.48.0/20" "103.21.244.0/22" "103.22.200.0/22" "103.31.4.0/22"
    "141.101.64.0/18" "108.162.192.0/18" "190.93.240.0/20" "188.114.96.0/20"
    "197.234.240.0/22" "198.41.128.0/17" "162.158.0.0/15" "104.16.0.0/13"
    "104.24.0.0/14" "172.64.0.0/13" "131.0.72.0/22"
    "2400:cb00::/32" "2606:4700::/32" "2803:f800::/32" "2405:b500::/32"
    "2405:8100::/32" "2a06:98c0::/29" "2c0f:f248::/32"
  ];
in

{
  imports = [
    ../../common
    ../../common/server-base.nix
    ./hardware-configuration.nix
  ];

  boot.loader.grub.enable = true;

  networking.hostName = "nixvps";
  networking.usePredictableInterfaceNames = false;
  networking.useDHCP = false;
  networking.interfaces.eth0.useDHCP = true;

  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ sshPort 80 443 ];

  users.users.luke = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keyFiles = [ ../../keys/luke.pub ];
  };

  services.fail2ban = {
    # Ban Vaultwarden login guesses from journald logs.
    jails.vaultwarden.settings = {
      backend = "systemd";
      journalmatch = "_SYSTEMD_UNIT=vaultwarden.service";
      filter = "vaultwarden";
      port = "http,https";
      maxretry = 5;
      ignoreip = cloudflareRanges;
    };
  };

  environment.etc."fail2ban/filter.d/vaultwarden.conf".text = ''
    [Definition]
    failregex = ^.*Username or password is incorrect\. Try again\. IP: <HOST>\. Username:.*$
    journalmatch = _SYSTEMD_UNIT=vaultwarden.service
  '';

  services.vaultwarden = {
    enable = true;
    dbBackend = "sqlite";
    environmentFile = "/var/lib/vaultwarden/vaultwarden.env";
    config = {
      DOMAIN = "https://vault.jukeluke.com";
      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = 8222;
      SIGNUPS_ALLOWED = false;
      ADMIN_PANEL_ENABLED = false;
      IP_HEADER = "X-Real-IP";

      SMTP_HOST = "smtp.migadu.com";
      SMTP_FROM = "shared@jukeluke.com";
      SMTP_FROM_NAME = "Vaultwarden";
      SMTP_PORT = 465;
      SMTP_SECURITY = "force_tls";
      SMTP_USERNAME = "shared@collins.rocks";
    };
  };

  # Use sqlite `.backup` so restic never captures a partially-written DB.
  services.restic.backups.vaultwarden = {
    initialize = true;
    repository = "b2:jukeluke-vaultwarden-backup:";
    environmentFile = "/var/lib/restic/b2.env";
    passwordFile = "/var/lib/restic/password";
    paths = [
      "/var/lib/vaultwarden"
      "/var/backup/vaultwarden"
    ];
    exclude = [
      "/var/lib/vaultwarden/db.sqlite3*" # backed up via the staged copy below
      "/var/lib/vaultwarden/icon_cache" # regenerable
    ];
    backupPrepareCommand = ''
      mkdir -p /var/backup/vaultwarden
      ${pkgs.sqlite}/bin/sqlite3 /var/lib/vaultwarden/db.sqlite3 \
        ".backup '/var/backup/vaultwarden/db.sqlite3'"
    '';
    timerConfig = {
      OnCalendar = "03:00";
      Persistent = true;
      RandomizedDelaySec = "15m";
    };
    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 4"
      "--keep-monthly 6"
    ];
  };

  services.caddy = {
    enable = true;
    globalConfig = ''
      servers {
        client_ip_headers CF-Connecting-IP
        trusted_proxies static ${cloudflareRanges}
      }
    '';
    virtualHosts."vault.jukeluke.com" = {
      extraConfig = ''
        header {
          Strict-Transport-Security "max-age=31536000"
          X-Content-Type-Options "nosniff"
          Referrer-Policy "same-origin"
          Permissions-Policy "camera=(), geolocation=(), microphone=(), payment=(), usb=()"
          X-Frame-Options "SAMEORIGIN"
        }
        reverse_proxy 127.0.0.1:8222 {
          header_up X-Real-IP {client_ip}
        }
      '';
    };
  };

  boot.tmp.cleanOnBoot = true;

  environment.systemPackages = with pkgs; [
    claude-code
    github-copilot-cli
  ];

  system.stateVersion = "26.05";
}
