{ config, pkgs, ... }:

let
  inherit (config.lib.formats.rasi) mkLiteral;

  colors = {
    bg = "#1a1b26";
    bg-alt = "#24283b";
    fg = "#c0caf5";
    fg-alt = "#565f89";
    accent = "#7aa2f7";
    accent-alt = "#7dcfff";
    green = "#9ece6a";
    red = "#f7768e";
  };
in

{
  programs.rofi = {
    enable = true;
    terminal = "${pkgs.alacritty}/bin/alacritty";

    theme = {
      "*" = {
        bg = mkLiteral colors.bg;
        bg-alt = mkLiteral colors.bg-alt;
        fg = mkLiteral colors.fg;
        fg-alt = mkLiteral colors.fg-alt;
        accent = mkLiteral colors.accent;
        accent-alt = mkLiteral colors.accent-alt;
        green = mkLiteral colors.green;
        red = mkLiteral colors.red;

        background-color = mkLiteral "transparent";
        text-color = mkLiteral "@fg";

        margin = 0;
        padding = 0;
        spacing = 0;
      };

      "window" = {
        location = mkLiteral "center";
        width = 640;
        background-color = mkLiteral "@bg";
        border = 2;
        border-color = mkLiteral "@accent";
        border-radius = 8;
      };

      "mainbox" = {
        padding = 12;
        children = map mkLiteral [ "inputbar" "message" "listview" ];
      };

      "inputbar" = {
        padding = mkLiteral "12px";
        spacing = mkLiteral "12px";
        children = map mkLiteral [ "prompt" "entry" ];
        background-color = mkLiteral "@bg-alt";
        border-radius = 4;
        margin = mkLiteral "0 0 12px 0";
      };

      "prompt" = {
        text-color = mkLiteral "@accent";
        font = "Hack Nerd Font Bold 10";
      };

      "entry" = {
        placeholder = "Search...";
        placeholder-color = mkLiteral "@fg-alt";
      };

      "message" = {
        margin = mkLiteral "0 0 12px 0";
        border-radius = 4;
        border-color = mkLiteral "@accent";
        background-color = mkLiteral "@bg-alt";
      };

      "textbox" = {
        padding = mkLiteral "8px 12px";
      };

      "listview" = {
        lines = 10;
        columns = 1;
        fixed-height = false;
        scrollbar = true;
      };

      "scrollbar" = {
        handle-width = 4;
        handle-color = mkLiteral "@accent";
        background-color = mkLiteral "@bg-alt";
        border-radius = 4;
      };

      "element" = {
        padding = mkLiteral "8px 12px";
        spacing = mkLiteral "8px";
        border-radius = 4;
      };

      "element normal normal" = {
        background-color = mkLiteral "transparent";
        text-color = mkLiteral "@fg";
      };

      "element normal urgent" = {
        background-color = mkLiteral "@red";
        text-color = mkLiteral "@bg";
      };

      "element normal active" = {
        background-color = mkLiteral "transparent";
        text-color = mkLiteral "@accent";
      };

      "element selected normal" = {
        background-color = mkLiteral "@accent";
        text-color = mkLiteral "@bg";
      };

      "element selected urgent" = {
        background-color = mkLiteral "@red";
        text-color = mkLiteral "@bg";
      };

      "element selected active" = {
        background-color = mkLiteral "@accent-alt";
        text-color = mkLiteral "@bg";
      };

      "element-icon" = {
        size = mkLiteral "1em";
        vertical-align = mkLiteral "0.5";
      };

      "element-text" = {
        text-color = mkLiteral "inherit";
      };
    };
  };
}
