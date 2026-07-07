{ pkgs, ... }:

let
  identity = import ../../common/identity.nix;
  sshPort = 47291;
in

{
  imports = [
    ../../common
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

  services.openssh = {
    enable = true;
    ports = [ sshPort ];
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      MaxAuthTries = 3;
      LoginGraceTime = 20;
      AllowUsers = [ "luke" ];
      # Forwarding features are unused on this host; re-enable
      # AllowTcpForwarding if `ssh -L` tunnels are ever needed.
      AllowAgentForwarding = false;
      AllowTcpForwarding = false;
      X11Forwarding = false;
      PermitTunnel = "no";
      # Drop dead/unresponsive sessions after ~15 minutes
      ClientAliveInterval = 300;
      ClientAliveCountMax = 3;
    };
  };

  services.fail2ban = {
    enable = true;
    maxretry = 3;
    bantime = "1h";
    bantime-increment = {
      enable = true;
      multipliers = "1 2 4 8 16 32 64";
      maxtime = "168h";
    };
    # Ban vault password-guessing, not just SSH. Relies on IP_HEADER =
    # X-Real-IP so the logged IP is the real client, not Caddy.
    jails.vaultwarden.settings = {
      backend = "systemd";
      journalmatch = "_SYSTEMD_UNIT=vaultwarden.service";
      filter = "vaultwarden";
      port = "http,https";
      maxretry = 5;
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
    # Secrets (ADMIN_TOKEN, SMTP_PASSWORD) live here — not in the Nix store
    environmentFile = "/var/lib/vaultwarden/vaultwarden.env";
    config = {
      DOMAIN = "https://vault.jukeluke.com";
      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = 8222;
      SIGNUPS_ALLOWED = false;
      # Disabled 2026-07 (audit): rarely needed; re-enable temporarily for
      # one-off admin tasks. ADMIN_TOKEN stays in vaultwarden.env either way.
      ADMIN_PANEL_ENABLED = false;
      # Caddy sets X-Real-IP unconditionally from the TCP peer, so unlike
      # X-Forwarded-For it can't be influenced by a client-supplied header.
      IP_HEADER = "X-Real-IP";

      SMTP_HOST = "smtp.migadu.com";
      SMTP_FROM = "shared@jukeluke.com";
      SMTP_FROM_NAME = "Vaultwarden";
      SMTP_PORT = 465;
      SMTP_SECURITY = "force_tls";
      SMTP_USERNAME = "shared@collins.rocks";
    };
  };

  # Nightly encrypted offsite backups of Vaultwarden to Backblaze B2.
  # Secrets live outside the Nix store:
  #   /var/lib/restic/b2.env    — B2_ACCOUNT_ID + B2_ACCOUNT_KEY
  #   /var/lib/restic/password  — restic repository encryption password
  # The live SQLite DB is snapshotted with `.backup` first — copying the raw
  # file mid-write can produce a corrupt backup.
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
          header_up X-Real-IP {remote_host}
        }
      '';
    };
  };

  programs.git = {
    enable = true;
    config = {
      user.name = identity.name;
      user.email = identity.email;
    };
  };

  boot.tmp.cleanOnBoot = true;

  environment.systemPackages = with pkgs; [
    # network / diagnostics
    inetutils
    mtr
    sysstat
    curl
    wget
    rsync

    # shell tools
    git
    vim
    tmux
    tree
    eza
    ripgrep
    jq
    file
    unzip
    btop
    ncdu
    nh

    # AI CLIs — kept deliberately (audit 2026-07): used to administer this VPS
    claude-code
    github-copilot-cli
  ];

  system.stateVersion = "26.05";
}
