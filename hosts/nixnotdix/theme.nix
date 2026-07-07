{
  colors = {
    # ===== Kanagawa Wave =====

    base    = "#1f1f28";
    surface = "#2a2a37";
    overlay = "#363646";
    muted   = "#54546d";
    text    = "#dcd7ba";
    subtext = "#c8c093";

    blue    = "#7e9cd8";
    blueLight = "#7fb4ca";
    teal    = "#6a9589";
    green   = "#98bc6d";
    purple  = "#957fb8";
    red     = "#e82424";
    redLight = "#e46876";
    orange  = "#ffa066";
    gold    = "#c0a36e";
    pink    = "#d27e99";
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
    name = "RobotoMono Nerd Font";
    size = 11;
    sizeBar = 10;
  };

  fontUI = {
    name = "Inter";
    size = 11;
  };
}
