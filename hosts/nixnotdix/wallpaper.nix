# Wallpaper rendered from theme.nix at build time: soft colour washes over the
# base tone with a touch of grain. Generating it keeps the desktop and the
# palette in lockstep; change a hue in theme.nix and the wallpaper follows.
# ImageMagick is a build dependency only, nothing lands in the system profile.
{ pkgs }:

let
  theme = import ./theme.nix;
  wp = theme.wallpaper;
  c = theme.colors;

  # Draw small and upscale: the blur is cheaper and comes out smoother.
  scale = 4;
  w = wp.width / scale;
  h = wp.height / scale;

  ellipse = e:
    let
      cx = toString (builtins.floor (e.x * w));
      cy = toString (builtins.floor (e.y * h));
      rx = toString (e.rx / scale);
      ry = toString (e.ry / scale);
    in "-fill '${e.color}' -draw 'ellipse ${cx},${cy} ${rx},${ry} 0,360'";
in

pkgs.runCommand "dusk-wallpaper.png" {
  nativeBuildInputs = [ pkgs.imagemagick ];
} ''
  magick -size ${toString w}x${toString h} xc:'${c.base}' \
    ${pkgs.lib.concatMapStringsSep " \\\n    " ellipse wp.washes} \
    -blur 0x${toString (180 / scale)} \
    -filter Gaussian -resize ${toString wp.width}x${toString wp.height}! \
    \( +clone -fill white -colorize 100 \
       -fill black -draw 'rectangle 0,0 ${toString wp.width},${toString wp.height}' \
       -fill white -draw 'ellipse ${toString (wp.width / 2)},${toString (wp.height / 2)} ${toString (wp.width * 3 / 4)},${toString (wp.height * 3 / 4)} 0,360' \
       -blur 0x${toString (wp.width / 6)} \
       -level 0%,100%,0.6 \) \
    -compose Multiply -composite \
    -attenuate 0.07 +noise Gaussian \
    -colorspace sRGB -depth 8 -strip "$out"
''
