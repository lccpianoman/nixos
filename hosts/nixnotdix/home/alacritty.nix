{ ... }:

let
  theme = import ../theme.nix;
  c = theme.colors;
  t = theme.terminal;
  font = theme.font;
in
{
  programs.alacritty = {
    enable = true;
    settings = {
      # Low enough that swayfx's blur does the work; the wallpaper washes
      # show through as tone, not as readable shapes.
      window.opacity = 0.78;
      window.dynamic_padding = true;
      # Keep text clear of swayfx's rounded corners, which clip flush content.
      window.padding = { x = theme.cornerRadius; y = theme.cornerRadius; };
      font = {
        normal = { family = font.name; style = "Regular"; };
        bold = { family = font.name; style = "Bold"; };
        italic = { family = font.name; style = "Italic"; };
        size = font.size;
      };
      colors = {
        primary = {
          background = c.base;
          foreground = c.text;
        };
        normal = {
          black = c.overlay;
          red = t.red;
          green = t.green;
          yellow = t.gold;
          blue = t.blue;
          magenta = t.purple;
          cyan = t.teal;
          white = c.subtext;
        };
        bright = {
          black = c.muted;
          red = t.redLight;
          green = t.green;
          yellow = t.orange;
          blue = t.blueLight;
          magenta = t.pink;
          cyan = t.teal;
          white = c.text;
        };
        cursor = {
          text = c.base;
          cursor = c.accent;
        };
        selection = {
          text = c.text;
          background = c.overlay;
        };
      };
      keyboard.bindings = [{
        key = "Return";
        mods = "Shift";
        chars = "\\n";
      }];
    };
  };
}
