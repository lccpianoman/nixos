{ pkgs, ... }:

let
  theme = import ./theme.nix;
  constants = import ./constants.nix;
  c = theme.colors;
  fontUI = theme.fontUI;
  monitors = constants.monitors;
  hex = theme.lib.stripHash;
  radius = toString theme.cornerRadius;
  cursor = theme.cursor;

  mod = "Mod4";

  wallpaper = import ./wallpaper.nix { inherit pkgs; };

  swaylock-cmd = "${pkgs.swaylock-effects}/bin/swaylock -f "
    + "--screenshots --effect-blur 12x6 --effect-vignette 0.4:0.6 "
    + "--fade-in 0.3 --grace 2 --grace-no-mouse "
    + "--clock --indicator --indicator-radius 120 --indicator-thickness 6 "
    + "--timestr '%H:%M' --datestr '%a, %b %d' "
    + "--font '${fontUI.name}' --font-size 24 "
    + "--color ${hex c.base} "
    + "--inside-color ${hex c.base}cc "
    + "--inside-clear-color ${hex c.base}cc "
    + "--inside-ver-color ${hex c.base}cc "
    + "--inside-wrong-color ${hex c.base}cc "
    + "--ring-color ${hex c.overlay} "
    + "--ring-clear-color ${hex c.teal} "
    + "--ring-ver-color ${hex c.accent} "
    + "--ring-wrong-color ${hex c.red} "
    + "--key-hl-color ${hex c.accent} "
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
  # systemd user units (swayidle) treat `%` as specifiers; escape to keep
  # swaylock's strftime tokens intact.
  swaylock-cmd-systemd = builtins.replaceStrings [ "%" ] [ "%%" ] swaylock-cmd;
in

{
  wayland.windowManager.sway = {
    enable = true;
    package = pkgs.swayfx;
    xwayland = true;
    # SwayFX's renderer is GLES2-only (no pixman fallback), so it cannot start
    # in the Nix sandbox with no DRM FD. Validate with `just check-sway` instead.
    checkConfig = false;

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
        inner = theme.gaps.inner;
        outer = theme.gaps.outer;
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
          border      = c.accent;
          background  = c.surface;
          text        = c.text;
          indicator   = c.purple;
          childBorder = c.accent;
        };
        focusedInactive = {
          border      = c.overlay;
          background  = c.base;
          text        = c.muted;
          indicator   = c.overlay;
          childBorder = c.overlay;
        };
        unfocused = {
          border      = c.surface;
          background  = c.base;
          text        = c.muted;
          indicator   = c.surface;
          childBorder = c.surface;
        };
        urgent = {
          border      = c.red;
          background  = c.base;
          text        = c.text;
          indicator   = c.red;
          childBorder = c.red;
        };
      };

      seat."*".xcursor_theme = "${cursor.name} ${toString cursor.size}";

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

    # SwayFX-only options; home-manager has no typed options for these.
    extraConfig = ''
      animation_duration_ms 300

      corner_radius ${radius}
      smart_corner_radius enable

      # Three passes at radius 6 is the frosted-glass sweet spot: enough that
      # text behind a window dissolves into tone, not so much that the blur
      # ghosts past window edges. Brightness and saturation lift the glass
      # slightly so the dusk washes show through translucent surfaces.
      blur enable
      blur_passes 3
      blur_radius 6
      blur_noise 0.03
      blur_brightness 1.05
      blur_contrast 1.0
      blur_saturation 1.2

      # Soft, wide, barely offset: a window should look lifted, not lit.
      shadows enable
      shadows_on_csd disable
      shadow_blur_radius 36
      shadow_color #0a0810b3
      shadow_inactive_color #0a081059
      shadow_offset 0 6

      default_dim_inactive 0.08
      dim_inactive_colors.unfocused ${c.base}

      # Brace blocks are required: a single line would be split on `;` into
      # separate global commands. Namespaces confirmed via WAYLAND_DEBUG.
      # Waybar paints detached islands on a transparent window, so blur only
      # the painted pixels and leave shadows/rounding to its own CSS.
      layer_effects "waybar" {
        blur enable;
        blur_ignore_transparent enable;
      }

      layer_effects "notifications" {
        blur enable;
        blur_ignore_transparent enable;
        shadows enable;
        corner_radius ${radius};
      }

      layer_effects "launcher" {
        blur enable;
        shadows enable;
        corner_radius ${radius};
      }

      # Block swayidle while any window is fullscreen. Wayland's idle-inhibit
      # protocol expects the app to take an inhibitor itself, but XWayland
      # (Steam/Proton: controllers aren't seat input, so pad play never
      # resets the timer) can't speak it and Firefox's is flaky; this rule
      # judges the window instead of trusting the app.
      for_window [all] inhibit_idle fullscreen
    '';
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
      { timeout = 300; command = swaylock-cmd-systemd; }
      {
        timeout = 600;
        command = "${pkgs.swayfx}/bin/swaymsg 'output * dpms off'";
        resumeCommand = "${pkgs.swayfx}/bin/swaymsg 'output * dpms on'";
      }
    ];
    events."before-sleep" = swaylock-cmd-systemd;
  };
}
