{ ... }:

{
  services.picom = {
    enable = true;
    backend = "glx";
    vSync = true;

    settings = {
      # ===== Performance =====

      unredir-if-possible = true;
      use-damage = true;

      # ===== Detection =====

      detect-transient = true;
      detect-client-opacity = true;
      detect-client-leader = true;
      detect-rounded-corners = true;

      # ===== Shadows =====

      shadow = true;
      shadow-radius = 12;
      shadow-opacity = 0.75;
      shadow-offset-x = -12;
      shadow-offset-y = -12;
      shadow-color = "#1a1b26";

      shadow-exclude = [
        "name = 'Notification'"
        "class_g = 'Conky'"
        "class_g ?= 'Notify-osd'"
        "class_g = 'Cairo-clock'"
        "class_g = 'slop'"
        "class_g = 'Polybar'"
        "_GTK_FRAME_EXTENTS@"
      ];

      # ===== Fading =====

      fading = true;
      fade-in-step = 0.028;
      fade-out-step = 0.03;
      fade-delta = 10;

      # ===== Opacity =====

      inactive-opacity = 0.95;
      frame-opacity = 1.0;
      inactive-opacity-override = false;
      active-opacity = 1.0;
      inactive-dim = 0.05;

      opacity-rule = [
        "100:class_g = 'firefox'"
        "100:class_g = 'VSCodium'"
        "100:class_g = 'Steam'"
        "100:class_g = 'vlc'"
      ];

      # ===== Blur =====

      blur-method = "dual_kawase";
      blur-strength = 2;
      blur-background = false;
      blur-background-frame = false;
      blur-background-fixed = false;

      blur-background-exclude = [
        "window_type = 'dock'"
        "window_type = 'desktop'"
        "class_g = 'slop'"
        "_GTK_FRAME_EXTENTS@"
      ];

      # ===== Rounded Corners =====

      corner-radius = 8;

      rounded-corners-exclude = [
        "window_type = 'dock'"
        "window_type = 'desktop'"
        "class_g = 'Polybar'"
      ];

      # ===== Window Types =====

      wintypes = {
        tooltip = {
          fade = true;
          shadow = false;
          opacity = 0.95;
          focus = true;
          full-shadow = false;
        };
        dock = {
          shadow = false;
          clip-shadow-above = true;
        };
        dnd = {
          shadow = false;
        };
        popup_menu = {
          opacity = 0.95;
          shadow = true;
          fade = true;
        };
        dropdown_menu = {
          opacity = 0.95;
          shadow = true;
          fade = true;
        };
      };
    };
  };
}
