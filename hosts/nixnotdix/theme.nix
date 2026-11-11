{
  colors = {
    # ===== Dusk =====
    # Violet-tinted ink with one warm accent. Low saturation everywhere except
    # `accent`, so the UI reads as calm surfaces with a single point of focus.

    base    = "#14121c";
    surface = "#1c1926";
    overlay = "#2a2639";
    muted   = "#6e6886";
    text    = "#ebe6f2";
    subtext = "#bdb5cf";

    # The one colour allowed to shout: focus borders, active workspace,
    # selection, links. Everything that used to be "blue" for emphasis.
    accent  = "#efa88e";

    blue    = "#8fb4e8";
    blueLight = "#b6d0f2";
    teal    = "#8fd3c6";
    green   = "#a9d4a0";
    purple  = "#c1a8ec";
    red     = "#ec8b9b";
    redLight = "#f3b3bf";
    orange  = "#eeb07a";
    gold    = "#e9cb8d";
    pink    = "#eaa6cf";
  };

  # ===== Terminal hues =====
  # The pastels above read flat as terminal text: plenty of brightness
  # contrast, very little saturation. These are the same hues (same OKLCH hue
  # angle, same key names) pushed to roughly the most chroma sRGB can show,
  # giving up a little lightness where the gamut demands it. Use them for
  # anything drawn inside a terminal (alacritty's ANSI colours, the prompt,
  # btop); the desktop UI keeps `colors`, so `accent` stays the only loud
  # colour out there.
  terminal = {
    blue      = "#4a95fc";
    blueLight = "#7fb5fb";
    teal      = "#21e1c9";
    green     = "#82e16e";
    purple    = "#b078fc";
    red       = "#fc3270";
    redLight  = "#fc7b9a";
    orange    = "#fd951b";
    gold      = "#fec11e";
    pink      = "#fd6fcd";
  };

  # ===== Color helpers =====
  # Use these instead of re-implementing hex munging in each module.

  lib = {
    # "#rrggbb" -> "rrggbb" (swaylock/fuzzel want bare hex)
    stripHash = hex: builtins.substring 1 6 hex;

    # "#rrggbb" -> "r;g;b" for truecolor ANSI escapes (bash prompt)
    ansiRgb = hex:
      let
        toInt = s:
          let
            digits = { "0"=0;"1"=1;"2"=2;"3"=3;"4"=4;"5"=5;"6"=6;"7"=7;"8"=8;"9"=9;
                       "a"=10;"b"=11;"c"=12;"d"=13;"e"=14;"f"=15;
                       "A"=10;"B"=11;"C"=12;"D"=13;"E"=14;"F"=15; };
            hi = digits.${builtins.substring 0 1 s};
            lo = digits.${builtins.substring 1 1 s};
          in hi * 16 + lo;
        r = builtins.substring 1 2 hex;
        g = builtins.substring 3 2 hex;
        b = builtins.substring 5 2 hex;
      in "${toString (toInt r)};${toString (toInt g)};${toString (toInt b)}";
  };

  font = {
    name = "JetBrainsMono Nerd Font";
    size = 12;
    sizeBar = 10;
  };

  # Pointer theme. The greeter runs as a different user and cannot see
  # home-manager's cursor settings, so greetd gets these via XCURSOR_* too.
  cursor = {
    name = "Bibata-Modern-Ice";
    size = 22;
  };

  # Window corner radius. swayfx clips window content to this arc, so anything
  # drawing flush to its edge (terminal padding, mako) must match it.
  cornerRadius = 12;

  # Window gaps. Waybar's side margins match `outer` so the bar's islands line
  # up with the window edges below them.
  gaps = {
    inner = 10;
    outer = 6;
  };

  fontUI = {
    name = "Inter";
    size = 11;
  };

  # Wallpaper washes, rendered by wallpaper.nix into soft blurred blobs over
  # `base`. Deep versions of the palette hues, so the blur lands between
  # `surface` and `overlay` in brightness and the UI still floats above it.
  wallpaper = {
    width  = 2560;
    height = 1440;
    washes = [
      # x y (fraction of canvas), radius x/y (px), colour; painted in order
      { x = 0.10; y = 0.14; rx = 860; ry = 560; color = "#3b2a52"; } # plum, top-left
      { x = 0.80; y = 0.12; rx = 640; ry = 400; color = "#26294d"; } # indigo, top-right
      { x = 0.88; y = 0.86; rx = 980; ry = 520; color = "#5a383c"; } # ember, bottom-right
      { x = 0.38; y = 0.96; rx = 720; ry = 260; color = "#45293f"; } # rose, bottom
      { x = 0.84; y = 0.78; rx = 300; ry = 300; color = "#8a5a50"; } # the setting sun
    ];
  };
}
