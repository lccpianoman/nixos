{ pkgs, ... }:

let
  theme = import ../theme.nix;
  fontUI = theme.fontUI;
in
{
  home.username = "luke";
  home.homeDirectory = "/home/luke";
  home.stateVersion = "25.11";

  home.sessionVariables.EDITOR = "vim";

  programs.home-manager.enable = true;

  xdg = {
    enable = true;
    userDirs = {
      enable = true;
      createDirectories = true;
      setSessionVariables = false;
    };
  };

  home.packages = with pkgs; [
    eza
    tree
    file
    wl-clipboard
    btop
    nh
    just
    killall
    fastfetch
    sway-contrib.grimshot
    swayidle
    swaylock
    xeyes
    glow
    ansible
    vlc
    pavucontrol
    vesktop
    plex-desktop
    spotify
    claude-code
    vscodium
    github-copilot-cli
    clonehero
    prismlauncher
  ];

  home.pointerCursor = {
    gtk.enable = true;
    sway.enable = true;
    name = "Bibata-Modern-Ice";
    package = pkgs.bibata-cursors;
    size = 22;
  };

  gtk = {
    enable = true;
    font = {
      name = fontUI.name;
      size = fontUI.size;
      package = pkgs.inter;
    };
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
