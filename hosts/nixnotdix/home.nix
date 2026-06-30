{ pkgs, ... }:

let
  theme = import ./theme.nix;
  c = theme.colors;
  font = theme.font;
in

{
  imports = [
    ./bash.nix
    ./mako.nix
    ./sway.nix
    ./waybar.nix
    ./fuzzel.nix
  ];

  # ===== User Profile =====

  home.username    = "luke";
  home.homeDirectory = "/home/luke";
  home.stateVersion  = "25.11";

  home.sessionVariables.EDITOR = "vim";

  programs.home-manager.enable = true;

  # ===== XDG =====

  xdg = {
    enable = true;
    userDirs = {
      enable = true;
      createDirectories = true;
      setSessionVariables = false;
    };
  };

  # ===== Packages =====

  home.packages = with pkgs; [
    # Utilities
    eza
    tree
    file
    wl-clipboard
    btop
    nh
    killall
    fastfetch
    ttyper
    grimblast
    swayidle
    swaylock

    # Applications
    firefox
    vlc
    pavucontrol
    vesktop
    plex-desktop
    spotify

    # Development
    claude-code
    vscodium
    github-copilot-cli

    # Gaming
    clonehero
    prismlauncher
    lunar-client
  ];

  # ===== Wallpaper =====

  home.file.".background-image".source = ./assets/wallpapers/purple-simple.png;

  # ===== Theme =====

  home.pointerCursor = {
    gtk.enable  = true;
    sway.enable = true;
    name    = "Bibata-Modern-Ice";
    package = pkgs.bibata-cursors;
    size    = 22;
  };

  gtk = {
    enable = true;
    font = {
      name    = font.name;
      size    = font.size;
      package = pkgs.nerd-fonts.caskaydia-cove;
    };
  };

  # ===== Applications =====

  programs.alacritty = {
    enable = true;
    settings = {
      window.opacity = 0.15;
      font = {
        normal = { family = font.name; style = "Regular"; };
        bold   = { family = font.name; style = "Bold"; };
        italic = { family = font.name; style = "Italic"; };
        size   = font.size;
      };
      colors = {
        primary = {
          background = c.base;
          foreground = c.text;
        };
        normal = {
          black   = c.overlay;
          red     = c.red;
          green   = c.green;
          yellow  = c.gold;
          blue    = c.blue;
          magenta = c.purple;
          cyan    = c.teal;
          white   = c.subtext;
        };
        bright = {
          black   = c.muted;
          red     = c.redLight;
          green   = c.green;
          yellow  = c.orange;
          blue    = c.blueLight;
          magenta = c.pink;
          cyan    = c.teal;
          white   = c.text;
        };
        cursor = {
          text   = c.base;
          cursor = c.blue;
        };
        selection = {
          text       = c.text;
          background = c.overlay;
        };
      };
      keyboard.bindings = [{
        key   = "Return";
        mods  = "Shift";
        chars = "\\n";
      }];
    };
  };

  programs.git = {
    enable = true;
    settings = {
      user.name         = "Luke Collins";
      user.email        = "luke@collins.rocks";
      init.defaultBranch = "master";
    };
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      "nixvps" = {
        Hostname     = "66.228.49.38";
        User         = "luke";
        Port         = 47291;
        IdentityFile = "~/.ssh/id_ed25519";
      };
    };
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
