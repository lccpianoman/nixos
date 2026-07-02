{ pkgs, config, ... }:

let
  theme = import ./theme.nix;
  c = theme.colors;
  font = theme.font;
  fontUI = theme.fontUI;
  identity = import ../../common/identity.nix;
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
    xeyes

    # Applications
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

  home.file.".background-image".source = ./assets/wallpapers/interestellar.jpg;

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
      name    = fontUI.name;
      size    = fontUI.size;
      package = pkgs.inter;
    };
  };

  # ===== Applications =====

  programs.alacritty = {
    enable = true;
    settings = {
      window.opacity = 0.85;
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
      user.name         = identity.name;
      user.email        = identity.email;
      init.defaultBranch = "main";
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

  programs.firefox = {
    enable = true;
    configPath = "${config.xdg.configHome}/mozilla/firefox";
    profiles.default = {
      extensions.packages = with pkgs.nur.repos.rycee.firefox-addons; [
        ublock-origin
        bitwarden
      ];
      settings = {
        "layout.css.devPixelsPerPx" = "1.0";

        # Dark mode
        "ui.systemUsesDarkTheme" = 1;

        # Telemetry
        "datareporting.healthreport.uploadEnabled" = false;
        "datareporting.policy.dataSubmissionEnabled" = false;
        "toolkit.telemetry.unified" = false;
        "toolkit.telemetry.enabled" = false;
        "toolkit.telemetry.archive.enabled" = false;
        "toolkit.telemetry.newProfilePing.enabled" = false;
        "toolkit.telemetry.shutdownPingSender.enabled" = false;
        "toolkit.telemetry.updatePing.enabled" = false;
        "toolkit.telemetry.bhrPing.enabled" = false;
        "toolkit.telemetry.firstShutdownPing.enabled" = false;
        "browser.ping-centre.telemetry" = false;

        # Tracking protection (strict)
        "privacy.trackingprotection.enabled" = true;
        "privacy.trackingprotection.socialtracking.enabled" = true;
        "browser.contentblocking.category" = "strict";
        "privacy.globalprivacycontrol.enabled" = true;

        # No password / form saving
        "signon.rememberSignons" = false;
        "signon.autofillForms" = false;
        "extensions.formautofill.addresses.enabled" = false;
        "extensions.formautofill.creditCards.enabled" = false;
        "browser.formfill.enable" = false;
      };
    };
  };
}
