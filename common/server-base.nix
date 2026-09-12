{ pkgs, ... }:

let
  identity = import ./identity.nix;
  sshPort = 47291;
in
{
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

  # Admin keys for every server. New device: drop its pubkey in keys/ and list it.
  users.users.luke.openssh.authorizedKeys.keyFiles = [
    ../keys/luke-nixnotdix.pub
  ];

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

  environment.systemPackages = with pkgs; [
    inetutils
    mtr
    sysstat
    curl
    wget
    rsync
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
    just
  ];

  programs.git = {
    enable = true;
    config = {
      user.name = identity.name;
      user.email = identity.email;
    };
  };
}
