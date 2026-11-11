{ ... }:

let
  theme = import ../theme.nix;
  c = theme.colors;
  t = theme.terminal;
in
{
  programs.btop = {
    enable = true;
    settings = {
      color_theme = "dusk";
      theme_background = false;
      truecolor = true;
      rounded_corners = true;
      graph_symbol = "braille";
      proc_gradient = true;
    };
    themes.dusk = ''
      theme[main_bg]="${c.base}"
      theme[main_fg]="${c.text}"
      theme[title]="${c.accent}"
      theme[hi_fg]="${c.accent}"
      theme[selected_bg]="${c.overlay}"
      theme[selected_fg]="${c.text}"
      theme[inactive_fg]="${c.muted}"
      theme[graph_text]="${c.subtext}"
      theme[meter_bg]="${c.surface}"
      theme[proc_misc]="${t.purple}"
      theme[cpu_box]="${t.purple}"
      theme[mem_box]="${t.green}"
      theme[net_box]="${t.teal}"
      theme[proc_box]="${c.accent}"
      theme[div_line]="${c.overlay}"
      theme[temp_start]="${t.green}"
      theme[temp_mid]="${t.orange}"
      theme[temp_end]="${t.red}"
      theme[cpu_start]="${t.blue}"
      theme[cpu_mid]="${t.teal}"
      theme[cpu_end]="${t.green}"
      theme[free_start]="${t.blueLight}"
      theme[free_mid]="${t.teal}"
      theme[free_end]="${t.green}"
      theme[cached_start]="${t.teal}"
      theme[cached_mid]="${t.blue}"
      theme[cached_end]="${t.purple}"
      theme[available_start]="${t.teal}"
      theme[available_mid]="${t.green}"
      theme[available_end]="${t.gold}"
      theme[used_start]="${t.green}"
      theme[used_mid]="${t.orange}"
      theme[used_end]="${t.red}"
      theme[download_start]="${t.blue}"
      theme[download_mid]="${t.teal}"
      theme[download_end]="${t.green}"
      theme[upload_start]="${t.purple}"
      theme[upload_mid]="${t.pink}"
      theme[upload_end]="${t.red}"
      theme[process_start]="${t.green}"
      theme[process_mid]="${t.gold}"
      theme[process_end]="${t.red}"
    '';
  };

  xdg.configFile = {
    "btop/btop.conf".force = true;
    "btop/themes/dusk.theme".force = true;
  };
}
