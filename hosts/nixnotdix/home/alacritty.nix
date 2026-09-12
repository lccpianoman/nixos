{ ... }:

let
  theme = import ../theme.nix;
  c = theme.colors;
  font = theme.font;
in
{
  programs.alacritty = {
    enable = true;
    settings = {
      window.opacity = 0.85;
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
          red = c.red;
          green = c.green;
          yellow = c.gold;
          blue = c.blue;
          magenta = c.purple;
          cyan = c.teal;
          white = c.subtext;
        };
        bright = {
          black = c.muted;
          red = c.redLight;
          green = c.green;
          yellow = c.orange;
          blue = c.blueLight;
          magenta = c.pink;
          cyan = c.teal;
          white = c.text;
        };
        cursor = {
          text = c.base;
          cursor = c.blue;
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
