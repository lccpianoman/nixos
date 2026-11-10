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
        font              = "${font.name}:size=${toString (font.size + 1)}";
        dpi-aware         = "auto";
        lines             = 8;
        width             = 48;
        horizontal-pad    = 24;
        vertical-pad      = 18;
        inner-pad         = 10;
        letter-spacing    = 0;
        icons-enabled     = true;
        icon-theme        = "hicolor";
        fields            = "name,generic,comment,categories,filename,keywords";
        terminal          = "alacritty -e";
        layer             = "overlay";
        prompt            = "\"   \"";
        placeholder       = "search";
        # Match swayfx layer_effects "launcher" so this surface gets the same
        # blur/corner/shadow treatment as other themed layers.
        namespace         = "launcher";
        exit-on-keyboard-focus-loss = true;
      };

      # Background is translucent and the launcher layer is blurred, so the
      # list floats as frosted glass over whatever is behind it.
      colors = {
        background    = "${hex c.base}cc";
        text          = "${hex c.subtext}ff";
        prompt        = "${hex c.accent}ff";
        input         = "${hex c.text}ff";
        match         = "${hex c.accent}ff";
        selection     = "${hex c.overlay}e6";
        selection-text = "${hex c.text}ff";
        selection-match = "${hex c.accent}ff";
        border        = "${hex c.overlay}ff";
        placeholder   = "${hex c.muted}ff";
        counter       = "${hex c.muted}ff";
      };

      border = {
        width  = 1;
        radius = theme.cornerRadius;
      };
    };
  };
}
