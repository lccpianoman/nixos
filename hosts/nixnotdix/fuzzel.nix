{ ... }:

let
  theme = import ./theme.nix;
  c = theme.colors;
  font = theme.font;
  fontUI = theme.fontUI;

  hex = s: builtins.substring 1 6 s;
in

{
  programs.fuzzel = {
    enable = true;
    settings = {
      main = {
        font              = "${fontUI.name}:size=${toString fontUI.size}";
        dpi-aware         = "no";
        lines             = 10;
        width             = 40;
        horizontal-pad    = 16;
        vertical-pad      = 12;
        inner-pad         = 8;
        line-height       = 22;
        letter-spacing    = 0;
        icons-enabled     = true;
        icon-theme        = "hicolor";
        fields            = "name,generic,comment,categories,filename,keywords";
        terminal          = "alacritty -e";
        layer             = "overlay";
        exit-on-keyboard-focus-loss = true;
      };

      colors = {
        background    = "${hex c.base}f0";
        text          = "${hex c.text}ff";
        match         = "${hex c.blue}ff";
        selection     = "${hex c.surface}ff";
        selection-text = "${hex c.text}ff";
        selection-match = "${hex c.blue}ff";
        border        = "${hex c.blue}ff";
        placeholder   = "${hex c.muted}ff";
      };

      border = {
        width  = 2;
        radius = 6;
      };
    };
  };
}
