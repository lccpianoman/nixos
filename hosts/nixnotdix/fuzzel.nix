{ ... }:

let
  theme = import ./theme.nix;
  c = theme.colors;
  fontUI = theme.fontUI;

  hex = theme.lib.stripHash;
in

{
  programs.fuzzel = {
    enable = true;
    settings = {
      main = {
        font              = "${fontUI.name}:size=12";
        dpi-aware         = "yes";
        lines             = 11;
        width             = 42;
        horizontal-pad    = 18;
        vertical-pad      = 14;
        inner-pad         = 10;
        line-height       = 24;
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
