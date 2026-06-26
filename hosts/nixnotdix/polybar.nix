{ config, pkgs, ... }:

let
  colors = {
    fg = "#fafafa";
    fg-alt = "#bdbdbd";
    red = "#ff1744";
    trans = "#00000000";
  };

  fonts = {
    main = "Hack Nerd Font:style=Regular:size=10;3";
    icons = "Hack Nerd Font:style=Regular:size=13;4";
  };

  weatherConfig = {
    location = "Aurora,US";
    units = "imperial";
    interval = 1800;
  };

  weatherDir = "${config.xdg.configHome}/polybar/scripts/weather";
  weatherSh = "${weatherDir}/weather.sh";
  weatherPy = pkgs.python3.withPackages (ps: [ ps.requests ]);

  mkLabel = name: icon: fg: {
    "label-${name}" = "%{T2}${icon}%{T-}";
    "label-${name}-foreground" = fg;
    "label-${name}-padding" = 1;
  };
in

{
  # ===== Weather Script =====

  home.file."${weatherDir}/weather.sh" = {
    executable = true;
    text = ''
      #!/bin/sh
      keyfile="$HOME/.config/openweathermap/api_key"
      if [ -f "$keyfile" ]; then
        export OPENWEATHER_API_KEY="$(cat "$keyfile")"
      fi
      exec ${weatherPy}/bin/python3 "${weatherDir}/main.py" \
        -u ${weatherConfig.units} \
        -c "${weatherConfig.location}"
    '';
  };

  home.file."${weatherDir}/main.py".source = ./assets/polybar/weather/main.py;

  # ===== Polybar Service =====

  services.polybar = {
    enable = true;
    package = pkgs.polybarFull;

    script = ''
      ${pkgs.procps}/bin/pkill -x polybar || true
      sleep 2
      for m in $(${pkgs.xrandr}/bin/xrandr --query | ${pkgs.gnugrep}/bin/grep -w connected | ${pkgs.gawk}/bin/awk '{print $1}'); do
        MONITOR="$m" ${pkgs.polybarFull}/bin/polybar -r main &
      done
    '';

    settings = {
      settings."screenchange-reload" = true;

      "bar/main" = {
        width = "100%";
        height = 30;
        bottom = true;
        "fixed-center" = true;
        monitor = "\${env:MONITOR:}";

        "wm-restack" = "bspwm";

        "modules-left" = "bspwm";
        "modules-center" = "title";
        "modules-right" = "date weather";

        "tray-background" = colors.trans;
        "tray-padding" = 2;
        "tray-position" = "right";
        "tray-maxsize" = 16;

        "cursor-click" = "pointer";
        "cursor-scroll" = "ns-resize";
        "scroll-up" = "next";
        "scroll-down" = "prev";
        "enable-ipc" = true;

        background = colors.trans;
        foreground = colors.fg;
        "font-0" = fonts.main;
        "font-1" = fonts.icons;
      };

      "module/bspwm" = {
        type = "internal/bspwm";
        format = "<label-state>";
      } // mkLabel "focused"  "◉" colors.fg
        // mkLabel "occupied" "●" colors."fg-alt"
        // mkLabel "urgent"   "●" colors.red
        // mkLabel "empty"    "○" colors."fg-alt";

      "module/title" = {
        type = "internal/xwindow";
        label = "%title%";
        "label-maxlen" = 60;
        "label-empty" = "";
      };

      "module/date" = {
        type = "internal/date";
        interval = 1;
        time = "%H:%M";
        "time-alt" = "%a, %b %d %H:%M:%S";
        format = "%{T1}%{T-} <label>";
        "format-padding" = 1;
        label = "%{T0}%time%%{T-}";
      };

      "module/weather" = {
        type = "custom/script";
        interval = toString weatherConfig.interval;
        exec = weatherSh;
        "format-padding" = 1;
        "format-prefix" = "%{T1}%{T-}";
        label = "%{T0} %output%%{T-}";
      };
    };
  };
}
