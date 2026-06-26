{ pkgs, ... }:

{
  programs.bash = {
    enable = true;

    # ===== History =====

    historySize = 10000;
    historyFileSize = 20000;
    historyControl = [ "ignoredups" "ignorespace" ];

    # ===== Aliases =====

    shellAliases = {
      ls = "eza --icons=auto";
      ll = "eza -lh --icons=auto --git";
      la = "eza -lah --icons=auto --git";
      lt = "eza --tree --icons=auto";
      grep = "grep --color=auto";
      fgrep = "fgrep --color=auto";
      egrep = "egrep --color=auto";
      cp = "cp -i";
      mv = "mv -i";
      rm = "rm -i";
      clear = "command clear; __FIRST_PROMPT=1";
    };

    # ===== Prompt =====

    initExtra = ''
      C_CYAN="\e[38;2;125;207;255m"
      C_FG="\e[38;2;192;202;245m"
      C_ACCENT="\e[38;2;122;162;247m"
      C_GREEN="\e[38;2;158;206;106m"
      C_RED="\e[38;2;247;118;142m"
      C_GRAY="\e[38;2;86;95;137m"
      C_RESET="\e[0m"

      ICON_GIT=$''

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
          git_info="  \[''${C_GRAY}\]''${ICON_GIT} \[''${C_ACCENT}\]$branch\[''${C_RESET}\]"
        fi

        if [ $exit_code -eq 0 ]; then
          status_color="''${C_GREEN}"
        else
          status_color="''${C_RED}"
        fi

        PS1="''${spacing}\[''${C_CYAN}\]\u@\h\[''${C_RESET}\] \[''${C_FG}\]\w\[''${C_RESET}\]''${git_info}\n\[''${status_color}\]❯\[''${C_RESET}\] "
      }

      PROMPT_COMMAND=__build_prompt
      bind '"\C-l": "clear\n"'
    '';
  };
}
