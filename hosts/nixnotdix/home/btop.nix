{ ... }:

let
  theme = import ../theme.nix;
  c = theme.colors;
in
{
  programs.btop = {
    enable = true;
    settings = {
      color_theme = "nebula";
      theme_background = false;
      truecolor = true;
      rounded_corners = true;
      graph_symbol = "braille";
      proc_gradient = true;
    };
    themes.nebula = ''
      theme[main_bg]="${c.base}"
      theme[main_fg]="${c.text}"
      theme[title]="${c.blueLight}"
      theme[hi_fg]="${c.blue}"
      theme[selected_bg]="${c.overlay}"
      theme[selected_fg]="${c.text}"
      theme[inactive_fg]="${c.muted}"
      theme[graph_text]="${c.subtext}"
      theme[meter_bg]="${c.surface}"
      theme[proc_misc]="${c.purple}"
      theme[cpu_box]="${c.blue}"
      theme[mem_box]="${c.green}"
      theme[net_box]="${c.teal}"
      theme[proc_box]="${c.orange}"
      theme[div_line]="${c.overlay}"
      theme[temp_start]="${c.green}"
      theme[temp_mid]="${c.orange}"
      theme[temp_end]="${c.red}"
      theme[cpu_start]="${c.blue}"
      theme[cpu_mid]="${c.teal}"
      theme[cpu_end]="${c.green}"
      theme[free_start]="${c.blueLight}"
      theme[free_mid]="${c.teal}"
      theme[free_end]="${c.green}"
      theme[cached_start]="${c.teal}"
      theme[cached_mid]="${c.blue}"
      theme[cached_end]="${c.purple}"
      theme[available_start]="${c.teal}"
      theme[available_mid]="${c.green}"
      theme[available_end]="${c.gold}"
      theme[used_start]="${c.green}"
      theme[used_mid]="${c.orange}"
      theme[used_end]="${c.red}"
      theme[download_start]="${c.blue}"
      theme[download_mid]="${c.teal}"
      theme[download_end]="${c.green}"
      theme[upload_start]="${c.purple}"
      theme[upload_mid]="${c.pink}"
      theme[upload_end]="${c.red}"
      theme[process_start]="${c.green}"
      theme[process_mid]="${c.gold}"
      theme[process_end]="${c.red}"
    '';
  };

  xdg.configFile = {
    "btop/btop.conf".force = true;
    "btop/themes/nebula.theme".force = true;
  };
}
