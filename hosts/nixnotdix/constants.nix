# Host constants for nixnotdix — monitors, workspace layout, weather.
# Theme values (colors, fonts) live in theme.nix; keep host facts here so
# sway.nix / waybar.nix don't each hard-code them.
rec {
  monitors = {
    primary = {
      name = "DP-3";
      mode = "1920x1080@144Hz";
      pos = "1920 0";
    };
    secondary = {
      name = "HDMI-A-1";
      mode = "1920x1080@60Hz";
      pos = "0 0";
    };
  };

  # Workspaces 1–3 on the 144Hz primary, 4–6 on the secondary
  workspaceOutputs = {
    "1" = monitors.primary.name;
    "2" = monitors.primary.name;
    "3" = monitors.primary.name;
    "4" = monitors.secondary.name;
    "5" = monitors.secondary.name;
    "6" = monitors.secondary.name;
  };

  weather = {
    location = "Aurora,US";
    units = "imperial";
    interval = 1800; # seconds between Waybar refreshes
  };
}
