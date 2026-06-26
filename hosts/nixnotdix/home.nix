{ pkgs, ... }:

{
  imports = [
    ./bash.nix
    ./dunst.nix
    ./picom.nix
    ./polybar.nix
    ./rofi.nix
    ./thunderbird.nix
  ];

  # ===== User Profile =====

  home.username = "luke";
  home.homeDirectory = "/home/luke";
  home.stateVersion = "25.11";

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
    feh
    tree
    file
    xclip
    btop
    nh
    killall
    fastfetch
    ttyper

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

  # ===== X Session =====

  xsession.enable = true;
  xsession.initExtra = ''
    ${pkgs.xrandr}/bin/xrandr \
      --output HDMI-0 --mode 1920x1080 --rate 60 --pos 0x0 --rotate normal \
      --output DP-0 --off \
      --output DP-1 --off \
      --output DP-2 --off \
      --output DP-3 --off \
      --output DP-4 --primary --mode 1920x1080 --rate 144 --pos 1920x0 --rotate normal \
      --output DP-5 --off
    ${pkgs.feh}/bin/feh --bg-fill "$HOME/.background-image" &
  '';

  home.file.".background-image".source = ./assets/wallpapers/purple-simple.png;

  # ===== Window Manager =====

  xsession.windowManager.bspwm = {
    enable = true;
    monitors = {
      HDMI-0 = [ "4" "5" "6" ];
      DP-4 = [ "1" "2" "3" ];
    };
    settings = {
      focus_follows_pointer = true;
      border_width = 2;
      window_gap = 4;
      top_padding = 4;
      bottom_padding = 4;
      left_padding = 4;
      right_padding = 4;
      normal_border_color = "#414868";
      focused_border_color = "#7aa2f7";
      borderless_monocle = true;
      gapless_monocle = true;
    };
  };

  # ===== Hotkeys =====

  services.sxhkd = {
    enable = true;
    keybindings = {
      "super + Return" = "alacritty";
      "super + @space" = "rofi -show drun";
      "super + alt + {q,r}" = "bspc {quit,wm -r}";
      "super + {_,shift + }BackSpace" = "bspc node -{c,k}";
      "super + {t,shift + t,s,f}" = "bspc node -t {tiled,pseudo_tiled,floating,fullscreen}";
      "super + {_,shift + }{h,j,k,l}" = "bspc node -{f,s} {west,south,north,east}";
      "super + {_,shift + }{1-6}" = "bspc {desktop -f,node -d} '{1-6}'";
      "Print" = "flameshot gui";
    };
  };

  # ===== Theme =====

  home.pointerCursor = {
    x11.enable = true;
    gtk.enable = true;
    name = "Bibata-Modern-Ice";
    package = pkgs.bibata-cursors;
    size = 22;
  };

  # ===== Applications =====

  programs.alacritty = {
    enable = true;
    theme = "tokyo_night";
    settings = {
      window.opacity = 0.15;
      font = {
        normal = {
          family = "Hack Nerd Font";
          style = "Regular";
        };
        bold = {
          family = "Hack Nerd Font";
          style = "Bold";
        };
        italic = {
          family = "Hack Nerd Font";
          style = "Italic";
        };
        size = 12;
      };
      keyboard.bindings = [{
        key = "Return";
        mods = "Shift";
        chars = "\\n";
      }];
    };
  };

  programs.git = {
    enable = true;
    settings = {
      user.name = "Luke Collins";
      user.email = "luke@collins.rocks";
      init.defaultBranch = "master";
    };
  };

  services.flameshot = {
    enable = true;
    settings.General = {
      disabledTrayIcon = true;
      showStartupLaunchMessage = false;
    };
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      "nixvps" = {
        Hostname = "66.228.49.38";
        User = "luke";
        IdentityFile = "~/.ssh/id_ed25519";
      };
    };
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
