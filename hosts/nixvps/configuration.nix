{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  boot.loader.grub.enable = true;

  networking.hostName = "nixvps";
  networking.usePredictableInterfaceNames = false;
  networking.useDHCP = false;
  networking.interfaces.eth0.useDHCP = true;

  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 80 443 ];

  time.timeZone = "America/Chicago";
  i18n.defaultLocale = "en_US.UTF-8";

  users.users.luke = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keyFiles = [ ../../keys/luke.pub ];
  };

  security.sudo.wheelNeedsPassword = false;

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      MaxAuthTries = 3;
      LoginGraceTime = 20;
      AllowUsers = [ "luke" ];
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
  };

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
      ADMIN_PANEL_ENABLED = true;

      SMTP_HOST = "smtp.migadu.com";
      SMTP_FROM = "shared@jukeluke.com";
      SMTP_FROM_NAME = "Vaultwarden";
      SMTP_PORT = 465;
      SMTP_SECURITY = "force_tls";
      SMTP_USERNAME = "shared@collins.rocks";
    };
  };

  services.caddy = {
    enable = true;
    virtualHosts."vault.jukeluke.com" = {
      extraConfig = ''
        reverse_proxy localhost:8222
      '';
    };
  };

  programs.git = {
    enable = true;
    config = {
      user.name = "Luke Collins";
      user.email = "luke@collins.rocks";
    };
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.trusted-users = [ "luke" ];
  nix.settings.warn-dirty = false;
  nixpkgs.config.allowUnfree = true;

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  nix.optimise = {
    automatic = true;
    dates = "weekly";
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

    # Applications
    claude-code
    github-copilot-cli
  ];

  system.stateVersion = "26.05";
}
