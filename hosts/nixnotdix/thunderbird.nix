{ ... }:

{
  accounts.email.accounts = {
    "luke@collins.rocks" = {
      primary = true;
      address = "luke@collins.rocks";
      realName = "Luke Collins";
      userName = "luke@collins.rocks";
      imap = {
        host = "imap.migadu.com";
        port = 993;
        tls.enable = true;
      };
      smtp = {
        host = "smtp.migadu.com";
        port = 465;
        tls.enable = true;
      };
      thunderbird.enable = true;
    };

    "shared@collins.rocks" = {
      address = "shared@collins.rocks";
      realName = "Shared Email";
      userName = "shared@collins.rocks";
      imap = {
        host = "imap.migadu.com";
        port = 993;
        tls.enable = true;
      };
      smtp = {
        host = "smtp.migadu.com";
        port = 465;
        tls.enable = true;
      };
      thunderbird.enable = true;
    };
  };

  programs.thunderbird = {
    enable = true;
    profiles."default" = {
      isDefault = true;

      settings = {
        # Force dark theme
        "ui.systemUsesDarkTheme" = 1;
        "extensions.activeThemeID" = "thunderbird-compact-dark@mozilla.org";
        # Enable userChrome.css
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
        # Tokyo Night link colors
        "browser.anchor_color" = "#7aa2f7";
        "browser.visited_color" = "#9d7cd8";
        "browser.display.background_color" = "#1a1b26";
        "browser.display.foreground_color" = "#c0caf5";
      };

      userChrome = ''
        /* Tokyo Night */
        :root {
          --layout-background-0: #1a1b26 !important;
          --layout-background-1: #16161e !important;
          --layout-background-2: #24283b !important;
          --layout-background-3: #2f354d !important;

          --layout-color-0: #c0caf5 !important;
          --layout-color-1: #a9b1d6 !important;
          --layout-color-2: #565f89 !important;
          --layout-color-3: #3b4261 !important;

          --color-accent-primary: #7aa2f7 !important;
          --color-accent-primary-hover: #7dcfff !important;
          --color-accent-primary-active: #7aa2f7 !important;

          --toolbar-bgcolor: #16161e !important;
          --toolbar-color: #c0caf5 !important;

          --sidebar-background-color: #16161e !important;
          --sidebar-text-color: #c0caf5 !important;

          --tabs-toolbar-background-color: #16161e !important;
          --tab-selected-bgcolor: #1a1b26 !important;

          --border-color-card: #3b4261 !important;
          --border-color-toolbar: #3b4261 !important;

          --button-hover-bgcolor: #24283b !important;
          --button-active-bgcolor: #2f354d !important;
        }
      '';
    };
  };
}
