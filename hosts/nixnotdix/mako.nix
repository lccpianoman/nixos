{ ... }:

let
  theme = import ./theme.nix;
  c = theme.colors;
  fontUI = theme.fontUI;

  # Translucent card; swayfx blurs what shows through (layer_effects
  # "notifications" in sway.nix), so this reads as frosted glass, not a hole.
  glass = "${c.surface}d9";
in

{
  services.mako = {
    enable = true;
    settings = {
      font             = "${fontUI.name} ${toString fontUI.size}";
      background-color = glass;
      text-color       = c.text;
      border-color     = c.overlay;
      border-size      = 1;
      border-radius    = theme.cornerRadius;
      padding          = "14,18";
      outer-margin     = "${toString (theme.gaps.outer + 2)},${toString theme.gaps.outer}";
      margin           = "6,0";
      width            = 360;
      max-visible      = 5;
      sort             = "-time";
      layer            = "overlay";
      anchor           = "top-right";
      default-timeout  = 7000;
      ignore-timeout   = false;
      progress-color   = "over ${c.overlay}";

      "urgency=low" = {
        background-color = glass;
        text-color       = c.subtext;
        border-color     = c.overlay;
        default-timeout  = 5000;
      };

      "urgency=normal" = {
        background-color = glass;
        text-color       = c.text;
        border-color     = c.overlay;
        default-timeout  = 7000;
      };

      "urgency=critical" = {
        background-color = glass;
        text-color       = c.text;
        border-color     = c.accent;
        border-size      = 2;
        default-timeout  = 0;
      };
    };
  };
}
