{ pkgs, ... }:

let
  theme = import ./theme.nix;
  c = theme.colors;

  # Convert #rrggbb to r;g;b for ANSI escape codes
  ansi = theme.lib.ansiRgb;
in

{
  programs.bash = {
    enable = true;

    # ===== History =====

    historySize     = 10000;
    historyFileSize = 20000;
    historyControl  = [ "ignoredups" "ignorespace" ];

    # ===== Aliases =====

    shellAliases = {
      ls    = "eza --icons=auto";
      ll    = "eza -lh --icons=auto --git";
      la    = "eza -lah --icons=auto --git";
      lt    = "eza --tree --icons=auto";
      grep  = "grep --color=auto";
      fgrep = "fgrep --color=auto";
      egrep = "egrep --color=auto";
      cp    = "cp -i";
      mv    = "mv -i";
      rm    = "rm -i";
      clear = "command clear; __FIRST_PROMPT=1";
    };

    # ===== Prompt =====

    initExtra = ''
      # Named by role, not by hue, so a palette swap can't strand these.
      # Never use c.text here: alacritty already paints normal output with it.
      C_HOST="\e[38;2;${ansi c.teal}m"
      C_PATH="\e[38;2;${ansi c.blueLight}m"
      C_GIT="\e[38;2;${ansi c.purple}m"
      C_OK="\e[38;2;${ansi c.green}m"
      C_ERR="\e[38;2;${ansi c.red}m"
      C_DIM="\e[38;2;${ansi c.muted}m"
      C_RESET="\e[0m"

      ICON_GIT=$''

      __FIRST_PROMPT=1

      __build_prompt() {
        local exit_code=$?
        local git_info=""
        local status_color=""
        local spacing=""

        if [ "$__FIRST_PROMPT" -eq 1 ]; then
          __FIRST_PROMPT=0
        else
          spacing="\n"
        fi

        local branch=$(${pkgs.git}/bin/git symbolic-ref --short HEAD 2>/dev/null)
        if [ -n "$branch" ]; then
          git_info="  \[''${C_DIM}\]''${ICON_GIT} \[''${C_GIT}\]$branch\[''${C_RESET}\]"
        fi

        if [ $exit_code -eq 0 ]; then
          status_color="''${C_OK}"
        else
          status_color="''${C_ERR}"
        fi

        PS1="''${spacing}\[''${C_HOST}\]\u@\h\[''${C_RESET}\] \[''${C_PATH}\]\w\[''${C_RESET}\]''${git_info}\n\[''${status_color}\]❯\[''${C_RESET}\] "
      }

      # Prepend rather than overwrite so hooks like direnv keep working;
      # __build_prompt must run first so $? is the user's last command.
      PROMPT_COMMAND="__build_prompt''${PROMPT_COMMAND:+; ''${PROMPT_COMMAND}}"
      bind '"\C-l": "clear\n"'
    '';
  };
}
