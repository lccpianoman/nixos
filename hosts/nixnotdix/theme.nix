{
  colors = {
    # ===== Saturated nebula =====

    base    = "#0b1022";
    surface = "#151d34";
    overlay = "#223258";
    muted   = "#6e7fb0";
    text    = "#f5f7ff";
    subtext = "#d0dbff";

    blue    = "#6fa8ff";
    blueLight = "#9dd7ff";
    teal    = "#43e8d8";
    green   = "#8fff7a";
    purple  = "#c781ff";
    red     = "#ff6b8b";
    redLight = "#ff9cb0";
    orange  = "#ffb45c";
    gold    = "#ffd76a";
    pink    = "#ff75d5";
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
    size = 11;
    sizeBar = 10;
  };

  fontUI = {
    name = "Inter";
    size = 11;
  };
}
