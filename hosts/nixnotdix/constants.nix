# Host constants for nixnotdix — monitors, workspace layout, weather.
# Theme values (colors, fonts) live in theme.nix; keep host facts here so
# sway.nix / waybar.nix don't each hard-code them.
rec {
  # Single-monitor setup: ASUS VG278 on DP-1. The panel's top mode reports as
  # 144.001Hz; sway picks the nearest match, so "144Hz" resolves to it.
  # To add a monitor back, add an entry here and give it a slice of
  # workspaceOutputs — sway.nix builds its output block from this attrset.
  monitors = {
    primary = {
      name = "DP-1";
      mode = "1920x1080@144Hz";
      pos = "0 0";
    };
  };

  # All workspaces on the single output
  workspaceOutputs = {
    "1" = monitors.primary.name;
    "2" = monitors.primary.name;
    "3" = monitors.primary.name;
    "4" = monitors.primary.name;
    "5" = monitors.primary.name;
    "6" = monitors.primary.name;
  };

  weather = {
    location = "Aurora,US";
    units = "imperial";
    interval = 1800; # seconds between Waybar refreshes
  };
}
