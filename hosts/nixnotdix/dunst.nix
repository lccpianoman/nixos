{ ... }:

{
  services.dunst = {
    enable = true;
    settings = {
      global = {
        origin = "top-right";
        offset = "(12, 12)";
        notification_limit = 5;
        gap_size = 6;

        progress_bar = true;
        progress_bar_height = 8;
        progress_bar_corner_radius = 4;

        frame_width = 1;
        frame_color = "#3b4261";
        corner_radius = 8;

        padding = 14;
        horizontal_padding = 16;
        text_icon_padding = 12;

        font = "Hack Nerd Font 11";
        line_height = 4;
        markup = "full";
        format = "<b>%s</b>\\n%b";
        alignment = "left";
        word_wrap = true;

        icon_position = "left";
        min_icon_size = 32;
        max_icon_size = 48;

        mouse_left_click = "close_current";
        mouse_right_click = "do_action, close_current";
      };

      urgency_low = {
        background = "#1a1b26";
        foreground = "#565f89";
        frame_color = "#3b4261";
        timeout = 5;
      };

      urgency_normal = {
        background = "#1a1b26";
        foreground = "#c0caf5";
        frame_color = "#3b4261";
        timeout = 7;
      };

      urgency_critical = {
        background = "#1a1b26";
        foreground = "#f7768e";
        frame_color = "#f7768e";
        timeout = 0;
      };
    };
  };
}
