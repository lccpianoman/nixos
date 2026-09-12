{ pkgs, ... }:

let
  theme = import ./theme.nix;
  constants = import ./constants.nix;
  c = theme.colors;
  fontUI = theme.fontUI;
  monitors = constants.monitors;
  hex = theme.lib.stripHash;

  mod = "Mod4";

  # Keep this as a store path so sway's config check works in build sandboxes.
  wallpaper = ./assets/wallpapers/a_space_shuttle_in_the_sky.jpg;

  swaylock-cmd = "${pkgs.swaylock}/bin/swaylock -f "
    + "--color ${hex c.base} "
    + "--inside-color ${hex c.surface} "
    + "--inside-clear-color ${hex c.surface} "
    + "--inside-ver-color ${hex c.surface} "
    + "--inside-wrong-color ${hex c.surface} "
    + "--ring-color ${hex c.blue} "
    + "--ring-clear-color ${hex c.teal} "
    + "--ring-ver-color ${hex c.purple} "
    + "--ring-wrong-color ${hex c.red} "
    + "--key-hl-color ${hex c.green} "
    + "--bs-hl-color ${hex c.redLight} "
    + "--text-color ${hex c.text} "
    + "--text-clear-color ${hex c.text} "
    + "--text-ver-color ${hex c.text} "
    + "--text-wrong-color ${hex c.red} "
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
    checkConfig = true;

    config = {
      modifier = mod;
      terminal = "${pkgs.alacritty}/bin/alacritty";
      menu = "${pkgs.fuzzel}/bin/fuzzel";

      output = builtins.listToAttrs (map
        (m: {
          name = m.name;
          value = {
            inherit (m) mode pos;
            bg = "${wallpaper} fill";
          };
        })
        (builtins.attrValues monitors));

      workspaceOutputAssign = builtins.attrValues (builtins.mapAttrs
        (workspace: output: { inherit workspace output; })
        constants.workspaceOutputs);

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
        names = [ fontUI.name ];
        size = fontUI.size * 1.0;
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

      keybindings = {
        "${mod}+Return"       = "exec ${pkgs.alacritty}/bin/alacritty";
        "${mod}+space"        = "exec ${pkgs.fuzzel}/bin/fuzzel";
        "${mod}+ctrl+l"       = "exec ${swaylock-cmd}";

        "${mod}+BackSpace"    = "kill";
        "${mod}+Shift+q"      = "kill";
        "${mod}+Shift+r"      = "reload";
        "${mod}+Shift+e"      = "exec swaynag -t warning -m 'Exit sway?' -b 'Yes' 'swaymsg exit'";

        "${mod}+t"            = "layout toggle split";
        "${mod}+f"            = "fullscreen toggle";
        "${mod}+s"            = "floating toggle";
        "${mod}+Shift+s"      = "layout stacking";

        "${mod}+h"            = "focus left";
        "${mod}+j"            = "focus down";
        "${mod}+k"            = "focus up";
        "${mod}+l"            = "focus right";

        "${mod}+Shift+h"      = "move left";
        "${mod}+Shift+j"      = "move down";
        "${mod}+Shift+k"      = "move up";
        "${mod}+Shift+l"      = "move right";

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

        "Delete"              = "exec ${pkgs.sway-contrib.grimshot}/bin/grimshot copy area";
        "Shift+Delete"        = "exec ${pkgs.sway-contrib.grimshot}/bin/grimshot save area ~/Pictures/$(date +%Y-%m-%d_%H-%M-%S).png";
      };

      bars = [];
    };
  };

  systemd.user.services.autotiling = {
    Unit = {
      Description = "Automatic tiling direction for sway";
      PartOf = [ "sway-session.target" ];
      After = [ "sway-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.autotiling-rs}/bin/autotiling-rs";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "sway-session.target" ];
  };

  services.swayidle = {
    enable = true;
    timeouts = [
      { timeout = 300; command = swaylock-cmd; }
      {
        timeout = 600;
        command = "${pkgs.sway}/bin/swaymsg 'output * dpms off'";
        resumeCommand = "${pkgs.sway}/bin/swaymsg 'output * dpms on'";
      }
    ];
    events."before-sleep" = swaylock-cmd;
  };
}
