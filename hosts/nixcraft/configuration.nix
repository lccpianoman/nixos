{ pkgs, lib, ... }:

let
  identity = import ../../common/identity.nix;
  sshPort = 47291;
in

{
  imports = [
    ../../common
    ./hardware-configuration.nix
    ./disko.nix
    ./minecraft.nix
  ];

  networking.hostName = "nixcraft";
  networking.domain = "";

  # Vultr hands out addressing over DHCP on the single virtio NIC.
  networking.useDHCP = lib.mkDefault true;

  networking.firewall.enable = true;
  # The Minecraft port is opened by the server module itself
  # (services.minecraft-servers.servers.<name>.openFirewall).
  networking.firewall.allowedTCPPorts = [ sshPort ];

  users.users.luke = {
    isNormalUser = true;
    # "minecraft" lets Luke read/write the server files and attach to the
    # server console tmux socket without sudo.
    extraGroups = [ "wheel" "minecraft" ];
    openssh.authorizedKeys.keyFiles = [ ../../keys/luke.pub ];
    # Without a password luke could not sudo (wheel needs one) and the Vultr
    # web console would be unusable, since root login is disabled everywhere —
    # a key-only box with no recovery path. This repo is public, so the hash
    # is not committed: it is placed on the host at install time with
    #   nixos-anywhere --extra-files
    # See "Deploying a new VPS" in README.md.
    hashedPasswordFile = "/etc/nixos-secrets/luke.hashedPassword";
  };

  # Same hardening as nixvps — key-only, non-root, non-standard port.
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
      AllowAgentForwarding = false;
      AllowTcpForwarding = false;
      X11Forwarding = false;
      PermitTunnel = "no";
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
  };

  # The JVM heap must never be swapped — a paged-out heap turns a GC pause
  # into a multi-second freeze for everyone online. Swap exists only as an
  # OOM backstop, so make the kernel reach for it as late as possible.
  boot.kernel.sysctl."vm.swappiness" = 10;

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
    zstd
    btop
    ncdu
    nh
  ];

  programs.git = {
    enable = true;
    config = {
      user.name = identity.name;
      user.email = identity.email;
    };
  };

  system.stateVersion = "26.05";
}
