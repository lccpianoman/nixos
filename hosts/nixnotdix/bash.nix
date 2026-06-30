{ pkgs, ... }:

let
  theme = import ./theme.nix;
  c = theme.colors;

  # Convert #rrggbb to r;g;b for ANSI escape codes
  ansi = hex:
    let
      r = builtins.substring 1 2 hex;
      g = builtins.substring 3 2 hex;
      b = builtins.substring 5 2 hex;
      toInt = s:
        let
          digits = { "0"=0;"1"=1;"2"=2;"3"=3;"4"=4;"5"=5;"6"=6;"7"=7;"8"=8;"9"=9;
                     "a"=10;"b"=11;"c"=12;"d"=13;"e"=14;"f"=15;
                     "A"=10;"B"=11;"C"=12;"D"=13;"E"=14;"F"=15; };
          hi = digits.${builtins.substring 0 1 s};
          lo = digits.${builtins.substring 1 1 s};
        in hi * 16 + lo;
    in "${toString (toInt r)};${toString (toInt g)};${toString (toInt b)}";
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
      C_CYAN="\e[38;2;${ansi c.blueLight}m"
      C_FG="\e[38;2;${ansi c.text}m"
      C_ACCENT="\e[38;2;${ansi c.blue}m"
      C_GREEN="\e[38;2;${ansi c.green}m"
      C_RED="\e[38;2;${ansi c.red}m"
      C_GRAY="\e[38;2;${ansi c.muted}m"
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
