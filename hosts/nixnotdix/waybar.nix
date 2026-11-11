{ config, pkgs, ... }:

let
  theme = import ./theme.nix;
  c = theme.colors;
  font = theme.font;
  fontUI = theme.fontUI;
  gaps = theme.gaps;

  weatherConfig = (import ./constants.nix).weather;

  # Relative to ~/.config; Waybar's `exec` needs the absolute form.
  weatherSubdir = "waybar/scripts/weather";
  weatherDir = "${config.xdg.configHome}/${weatherSubdir}";
  weatherSh  = "${weatherDir}/weather.sh";
  weatherPy  = pkgs.python3.withPackages (ps: [ ps.requests ]);
in

{
  # ===== Weather Script =====
  # The API key lives in ~/.config/openweathermap/api_key, outside the
  # Nix store and outside git; it is read at runtime, never at build time.

  xdg.configFile."${weatherSubdir}/weather.sh" = {
    executable = true;
    text = ''
      #!/bin/sh
      keyfile="$HOME/.config/openweathermap/api_key"
      if [ -f "$keyfile" ]; then
        export OPENWEATHER_API_KEY="$(${pkgs.coreutils}/bin/cat "$keyfile")"
      fi
      # Waybar hides a custom module's output when the exec exits non-zero,
      # which would swallow the script's "N/A" fallback, so swallow the
      # exit code here (the script keeps honest exit codes for CLI use).
      ${weatherPy}/bin/python3 "${weatherDir}/main.py" \
        -u ${weatherConfig.units} \
        -c "${weatherConfig.location}" || true
    '';
  };

  xdg.configFile."${weatherSubdir}/main.py".source = ./assets/weather/main.py;

  # ===== Waybar =====

  programs.waybar = {
    enable = true;
    # Run as a systemd user service (graphical-session.target) instead of a
    # sway startup exec: restart-on-crash, `systemctl --user restart waybar`,
    # logs in `journalctl --user -u waybar`.
    systemd.enable = true;

    settings = [{
      # "top", not "bottom": swayfx cannot apply layer_effects to the bottom layer.
      layer         = "top";
      position      = "top";
      height        = 32;
      spacing       = 0;
      # Match the window gaps so the islands line up with the tiles below.
      margin-top    = gaps.outer;
      margin-left   = gaps.outer;
      margin-right  = gaps.outer;

      "modules-left"   = [ "sway/workspaces" "sway/mode" "sway/window" ];
      "modules-center" = [ "clock" ];
      "modules-right"  = [ "custom/weather" "pulseaudio" "tray" ];

      "sway/workspaces" = {
        format = "{icon}";
        # Every state is a dot; CSS stretches the focused one into a pill
        # and paints the glyph the same colour as the pill to hide it.
        "format-icons" = {
          focused = "●";
          urgent  = "●";
          default = "●";
        };
        "persistent-workspaces" = {
          "*" = [ 1 2 3 4 5 6 ];
        };
      };

      "sway/mode" = {
        format = "{}";
      };

      "sway/window" = {
        "max-length"  = 48;
        "all-outputs" = false;
        "format"      = "{}";
      };

      clock = {
        format     = "{:%H:%M}";
        "format-alt" = "{:%a %d %b   %H:%M:%S}";
        interval   = 1;
        tooltip    = false;
      };

      "custom/weather" = {
        exec     = weatherSh;
        interval = weatherConfig.interval;
        format   = "<span color='${c.accent}'></span>  {}";
        tooltip  = false;
      };

      pulseaudio = {
        format        = "<span color='${c.accent}'>{icon}</span>  {volume}%";
        "format-muted" = "<span color='${c.muted}'>󰝟</span>  {volume}%";
        "format-icons" = {
          headphone = "󰋋";
          default   = [ "󰕿" "󰖀" "󰕾" ];
        };
        "scroll-step"    = 2;
        "on-click"       = "${pkgs.pavucontrol}/bin/pavucontrol";
        "on-click-right" = "${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
        tooltip          = false;
      };

      tray = {
        "icon-size" = 16;
        spacing     = 8;
      };
    }];

    style = ''
      @define-color base    ${c.base};
      @define-color surface ${c.surface};
      @define-color overlay ${c.overlay};
      @define-color muted   ${c.muted};
      @define-color text    ${c.text};
      @define-color subtext ${c.subtext};
      @define-color accent  ${c.accent};
      @define-color red     ${c.red};
      @define-color orange  ${c.orange};

      * {
        font-family: "${fontUI.name}", "${font.name}", monospace;
        font-size: ${toString font.sizeBar}pt;
        border: none;
        border-radius: 0;
        min-height: 0;
        margin: 0;
        padding: 0;
      }

      /* The window itself is transparent; the three module groups float as
         separate glass islands. swayfx blurs only the painted pixels
         (blur_ignore_transparent), so the gap between islands stays clear.
         That is also why the islands carry no box-shadow: a shadow's faint
         pixels count as painted, so swayfx blurs (and noise-dithers) the
         whole shadow extent, clipped to the bar's rectangle, which shows up
         as an off-colour box behind each island. */
      window#waybar {
        background: transparent;
        color: @text;
      }

      .modules-left,
      .modules-center,
      .modules-right {
        background-color: alpha(@base, 0.72);
        border: 1px solid alpha(@overlay, 0.9);
        border-radius: 999px;
        padding: 0 6px;
      }

      /* ===== Workspaces ===== */

      #workspaces {
        padding: 0 2px;
      }

      #workspaces button {
        padding: 0 6px;
        margin: 7px 2px;
        color: @muted;
        background: transparent;
        box-shadow: none;
        border-radius: 999px;
        transition: all 250ms cubic-bezier(0.2, 0.8, 0.2, 1);
      }

      #workspaces button.focused {
        padding: 0 14px;
        color: @accent;
        background: @accent;
      }

      #workspaces button.urgent {
        color: @red;
      }

      #workspaces button:hover {
        background: alpha(@overlay, 0.9);
        color: @subtext;
        box-shadow: none;
      }

      #workspaces button.focused:hover {
        color: @accent;
        background: @accent;
      }

      /* ===== Mode and window title ===== */

      #mode {
        padding: 0 12px;
        color: @accent;
        font-weight: 600;
      }

      #window {
        padding: 0 12px;
        color: @muted;
      }

      window#waybar.empty #window {
        padding: 0;
      }

      /* ===== Clock ===== */

      #clock {
        padding: 0 16px;
        color: @text;
        font-weight: 600;
        letter-spacing: 0.5px;
      }

      /* ===== Right modules ===== */

      #custom-weather,
      #pulseaudio,
      #tray {
        padding: 0 12px;
        color: @subtext;
        transition: color 150ms ease;
      }

      #pulseaudio:hover,
      #custom-weather:hover {
        color: @text;
      }

      #pulseaudio.muted {
        color: @muted;
      }

      #tray > .passive {
        -gtk-icon-effect: dim;
      }

      #tray > .needs-attention {
        -gtk-icon-effect: highlight;
        color: @orange;
      }

      tooltip {
        background-color: alpha(@surface, 0.96);
        border: 1px solid @overlay;
        border-radius: ${toString theme.cornerRadius}px;
      }

      tooltip label {
        color: @text;
        padding: 4px 8px;
      }
    '';
  };
}
