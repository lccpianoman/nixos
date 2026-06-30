{ pkgs, ... }:

let
  theme = import ./theme.nix;
  c = theme.colors;
  font = theme.font;

  mod = "Mod4";

  swaylock-cmd = "${pkgs.swaylock}/bin/swaylock -f "
    + "--color ${builtins.substring 1 6 c.base} "
    + "--inside-color ${builtins.substring 1 6 c.surface} "
    + "--inside-clear-color ${builtins.substring 1 6 c.surface} "
    + "--inside-ver-color ${builtins.substring 1 6 c.surface} "
    + "--inside-wrong-color ${builtins.substring 1 6 c.surface} "
    + "--ring-color ${builtins.substring 1 6 c.blue} "
    + "--ring-clear-color ${builtins.substring 1 6 c.teal} "
    + "--ring-ver-color ${builtins.substring 1 6 c.purple} "
    + "--ring-wrong-color ${builtins.substring 1 6 c.red} "
    + "--key-hl-color ${builtins.substring 1 6 c.green} "
    + "--bs-hl-color ${builtins.substring 1 6 c.redLight} "
    + "--text-color ${builtins.substring 1 6 c.text} "
    + "--text-clear-color ${builtins.substring 1 6 c.text} "
    + "--text-ver-color ${builtins.substring 1 6 c.text} "
    + "--text-wrong-color ${builtins.substring 1 6 c.red} "
    + "--separator-color 00000000 "
    + "--line-color 00000000 "
    + "--line-clear-color 00000000 "
    + "--line-ver-color 00000000 "
    + "--line-wrong-color 00000000";
in

{
  wayland.windowManager.sway = {
    enable = true;
    xwayland = true;
    checkConfig = false;

    config = {
      modifier = mod;
      terminal = "${pkgs.alacritty}/bin/alacritty";
      menu = "${pkgs.fuzzel}/bin/fuzzel";

      # ===== Outputs =====

      output = {
        "HDMI-A-1" = {
          mode = "1920x1080@60Hz";
          pos = "0 0";
          bg = "~/.background-image fill";
        };
        "DP-3" = {
          mode = "1920x1080@144Hz";
          pos = "1920 0";
          bg = "~/.background-image fill";
        };
      };

      # ===== Workspaces =====

      workspaceOutputAssign = [
        { workspace = "1"; output = "DP-3"; }
        { workspace = "2"; output = "DP-3"; }
        { workspace = "3"; output = "DP-3"; }
        { workspace = "4"; output = "HDMI-A-1"; }
        { workspace = "5"; output = "HDMI-A-1"; }
        { workspace = "6"; output = "HDMI-A-1"; }
      ];

      # ===== Appearance =====

      gaps = {
        inner = 4;
        outer = 0;
        smartGaps = false;
        smartBorders = "off";
      };

      window = {
        border = 2;
        titlebar = false;
      };

      floating = {
        border = 2;
        titlebar = false;
      };

      fonts = {
        names = [ font.name ];
        size = font.size * 1.0;
      };

      colors = {
        focused = {
          border      = c.blue;
          background  = c.surface;
          text        = c.text;
          indicator   = c.teal;
          childBorder = c.blue;
        };
        focusedInactive = {
          border      = c.overlay;
          background  = c.base;
          text        = c.muted;
          indicator   = c.overlay;
          childBorder = c.overlay;
        };
        unfocused = {
          border      = c.overlay;
          background  = c.base;
          text        = c.muted;
          indicator   = c.overlay;
          childBorder = c.overlay;
        };
        urgent = {
          border      = c.red;
          background  = c.base;
          text        = c.text;
          indicator   = c.red;
          childBorder = c.red;
        };
      };

      seat."*".xcursor_theme = "Bibata-Modern-Ice 22";

      focus.followMouse = true;

      # ===== Keybindings =====

      keybindings = {
        "${mod}+Return"       = "exec ${pkgs.alacritty}/bin/alacritty";
        "${mod}+space"        = "exec ${pkgs.fuzzel}/bin/fuzzel";
        "${mod}+ctrl+l"       = "exec ${swaylock-cmd}";

        # Kill / reload
        "${mod}+BackSpace"    = "kill";
        "${mod}+Shift+q"      = "kill";
        "${mod}+Shift+r"      = "reload";
        "${mod}+Shift+e"      = "exec swaynag -t warning -m 'Exit sway?' -b 'Yes' 'swaymsg exit'";

        # Layout
        "${mod}+t"            = "layout toggle split";
        "${mod}+f"            = "fullscreen toggle";
        "${mod}+s"            = "floating toggle";
        "${mod}+Shift+s"      = "layout stacking";

        # Focus
        "${mod}+h"            = "focus left";
        "${mod}+j"            = "focus down";
        "${mod}+k"            = "focus up";
        "${mod}+l"            = "focus right";

        # Move
        "${mod}+Shift+h"      = "move left";
        "${mod}+Shift+j"      = "move down";
        "${mod}+Shift+k"      = "move up";
        "${mod}+Shift+l"      = "move right";

        # Workspaces
        "${mod}+1"            = "workspace number 1";
        "${mod}+2"            = "workspace number 2";
        "${mod}+3"            = "workspace number 3";
        "${mod}+4"            = "workspace number 4";
        "${mod}+5"            = "workspace number 5";
        "${mod}+6"            = "workspace number 6";
        "${mod}+Shift+1"      = "move container to workspace number 1";
        "${mod}+Shift+2"      = "move container to workspace number 2";
        "${mod}+Shift+3"      = "move container to workspace number 3";
        "${mod}+Shift+4"      = "move container to workspace number 4";
        "${mod}+Shift+5"      = "move container to workspace number 5";
        "${mod}+Shift+6"      = "move container to workspace number 6";

        # Screenshot
        "Print"               = "exec ${pkgs.grimblast}/bin/grimblast copy area";
        "Shift+Print"         = "exec ${pkgs.grimblast}/bin/grimblast save area ~/Pictures/$(date +%Y-%m-%d_%H-%M-%S).png";
      };

      # ===== Startup =====

      startup = [
        { command = "${pkgs.mako}/bin/mako"; }
        { command = "${pkgs.waybar}/bin/waybar"; }
        {
          command = ''
            ${pkgs.swayidle}/bin/swayidle -w \
              timeout 300 '${swaylock-cmd}' \
              timeout 600 'swaymsg "output * dpms off"' \
              resume 'swaymsg "output * dpms on"' \
              before-sleep '${swaylock-cmd}'
          '';
        }
      ];

      bars = [];
    };
  };
}
