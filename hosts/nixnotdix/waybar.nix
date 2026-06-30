{ config, pkgs, ... }:

let
  theme = import ./theme.nix;
  c = theme.colors;
  font = theme.font;

  weatherConfig = {
    location = "Aurora,US";
    units = "imperial";
    interval = 1800;
  };

  weatherDir = "${config.xdg.configHome}/waybar/scripts/weather";
  weatherSh  = "${weatherDir}/weather.sh";
  weatherPy  = pkgs.python3.withPackages (ps: [ ps.requests ]);
in

{
  # ===== Weather Script =====

  home.file."${weatherDir}/weather.sh" = {
    executable = true;
    text = ''
      #!/bin/sh
      keyfile="$HOME/.config/openweathermap/api_key"
      if [ -f "$keyfile" ]; then
        export OPENWEATHER_API_KEY="$(${pkgs.coreutils}/bin/cat "$keyfile")"
      fi
      exec ${weatherPy}/bin/python3 "${weatherDir}/main.py" \
        -u ${weatherConfig.units} \
        -c "${weatherConfig.location}"
    '';
  };

  home.file."${weatherDir}/main.py".source = ./assets/weather/main.py;

  # ===== Waybar =====

  programs.waybar = {
    enable = true;

    settings = [{
      layer    = "bottom";
      position = "bottom";
      height   = 30;
      spacing  = 0;

      "modules-left"   = [ "sway/workspaces" ];
      "modules-center" = [ "sway/window" ];
      "modules-right"  = [ "custom/weather" "clock" "tray" ];

      "sway/workspaces" = {
        format = "{icon}";
        "format-icons" = {
          focused = "◉";
          urgent  = "●";
          default = "○";
        };
        "persistent-workspaces" = {
          "*" = [ 1 2 3 4 5 6 ];
        };
      };

      "sway/window" = {
        "max-length"  = 60;
        "all-outputs" = false;
        "format"      = "{}";
      };

      clock = {
        format     = " {:%H:%M}";
        "format-alt" = " {:%a, %b %d %H:%M:%S}";
        interval   = 1;
        tooltip    = false;
      };

      "custom/weather" = {
        exec     = weatherSh;
        interval = weatherConfig.interval;
        format   = " {}";
        tooltip  = false;
      };

      tray = {
        "icon-size" = 16;
        spacing     = 6;
      };
    }];

    style = ''
      @define-color base    ${c.base};
      @define-color surface ${c.surface};
      @define-color overlay ${c.overlay};
      @define-color muted   ${c.muted};
      @define-color text    ${c.text};
      @define-color subtext ${c.subtext};
      @define-color blue    ${c.blue};
      @define-color teal    ${c.teal};
      @define-color green   ${c.green};
      @define-color purple  ${c.purple};
      @define-color red     ${c.red};
      @define-color gold    ${c.gold};
      @define-color orange  ${c.orange};

      * {
        font-family: "${font.name}", monospace;
        font-size: ${toString font.sizeBar}pt;
        border: none;
        border-radius: 0;
        min-height: 0;
        margin: 0;
        padding: 0;
      }

      window#waybar {
        background: transparent;
        color: @text;
      }

      /* ===== Workspaces ===== */

      #workspaces {
        padding: 0 4px;
      }

      #workspaces button {
        padding: 0 7px;
        color: @muted;
        background: transparent;
        box-shadow: none;
        border-radius: 0;
        transition: color 0.1s ease;
      }

      #workspaces button.focused {
        color: @text;
      }

      #workspaces button.urgent {
        color: @red;
      }

      #workspaces button.visible {
        color: @subtext;
      }

      #workspaces button:hover {
        background: transparent;
        color: @blue;
        box-shadow: none;
      }

      /* ===== Window title ===== */

      #window {
        padding: 0 12px;
        color: @subtext;
      }

      /* ===== Right modules ===== */

      #clock {
        padding: 0 10px;
        color: @gold;
      }

      #custom-weather {
        padding: 0 10px;
        color: @teal;
      }

      #tray {
        padding: 0 8px;
      }

      #tray > .passive {
        -gtk-icon-effect: dim;
      }

      #tray > .needs-attention {
        -gtk-icon-effect: highlight;
        color: @orange;
      }
    '';
  };
}
