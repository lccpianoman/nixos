{ ... }:

let
  theme = import ./theme.nix;
  c = theme.colors;
  fontUI = theme.fontUI;
in

{
  services.mako = {
    enable = true;
    settings = {
      font             = "${fontUI.name} ${toString fontUI.size}";
      background-color = c.surface;
      text-color       = c.text;
      border-color     = c.overlay;
      border-size      = 1;
      border-radius    = 8;
      padding          = "14,16";
      margin           = "12";
      width            = 340;
      max-visible      = 5;
      gap              = 6;
      sort             = "-time";
      layer            = "overlay";
      anchor           = "top-right";
      default-timeout  = 7000;
      ignore-timeout   = false;

      "[urgency=low]" = {
        background-color = c.surface;
        text-color       = c.muted;
        border-color     = c.overlay;
        default-timeout  = 5000;
      };

      "[urgency=normal]" = {
        background-color = c.surface;
        text-color       = c.text;
        border-color     = c.overlay;
        default-timeout  = 7000;
      };

      "[urgency=critical]" = {
        background-color = c.surface;
        text-color       = c.red;
        border-color     = c.red;
        default-timeout  = 0;
      };
    };
  };
}
