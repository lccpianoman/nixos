{ ... }:

let
  theme = import ./theme.nix;
  c = theme.colors;
  font = theme.font;

  hex = theme.lib.stripHash;
in

{
  programs.fuzzel = {
    enable = true;
    settings = {
      main = {
        font              = "${font.name}:size=${toString font.size}";
        dpi-aware         = "yes";
        lines             = 8;
        width             = 64;
        horizontal-pad    = 22;
        vertical-pad      = 14;
        inner-pad         = 12;
        line-height       = 22;
        letter-spacing    = 0;
        icons-enabled     = true;
        icon-theme        = "hicolor";
        fields            = "name,generic,comment,categories,filename,keywords";
        terminal          = "alacritty -e";
        layer             = "overlay";
        # Match swayfx layer_effects "launcher" so this surface gets the same
        # corner/shadow treatment as other themed layers.
        namespace         = "launcher";
        exit-on-keyboard-focus-loss = true;
      };

      colors = {
        background    = "${hex c.base}f0";
        text          = "${hex c.text}ff";
        prompt        = "${hex c.subtext}ff";
        input         = "${hex c.text}ff";
        match         = "${hex c.blue}ff";
        selection     = "${hex c.surface}ff";
        selection-text = "${hex c.text}ff";
        selection-match = "${hex c.blue}ff";
        border        = "${hex c.blue}ff";
        placeholder   = "${hex c.muted}ff";
        counter       = "${hex c.muted}ff";
      };

      border = {
        width  = 2;
        radius = theme.cornerRadius;
      };
    };
  };
}
