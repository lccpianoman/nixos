{ config, lib, pkgs, ... }:

let
  theme = import ../theme.nix;
  c = theme.colors;

  # Tokens substituted into the CSS templates in ./firefox. Done in Nix rather
  # than with pkgs.replaceVars so the result stays a plain string — no
  # import-from-derivation just to inline the start page's CSS.
  vars = c // {
    radius = toString theme.cornerRadius;
    fontUI = theme.fontUI.name;
    fontMono = theme.font.name;
  };

  subst =
    file:
    builtins.replaceStrings (map (n: "@${n}@") (builtins.attrNames vars)) (
      builtins.attrValues vars
    ) (builtins.readFile file);

  # Start page tiles. Edit this list; nothing else needs to change.
  startPage = import ./firefox/startpage.nix {
    inherit lib;
    css = subst ./firefox/startpage.css;
    host = "nixnotdix";
    search = {
      action = "https://duckduckgo.com/";
      param = "q";
    };
    links = [
      { name = "GitHub";       url = "https://github.com";                        accent = c.text; }
      { name = "Nix Packages"; url = "https://search.nixos.org/packages";         accent = c.blue; }
      { name = "NixOS Wiki";   url = "https://wiki.nixos.org";                    accent = c.blueLight; }
      { name = "HM Options";   url = "https://home-manager-options.extranix.com"; accent = c.teal; }
      { name = "Reddit";       url = "https://reddit.com";                        accent = c.orange; }
      { name = "YouTube";      url = "https://youtube.com";                       accent = c.red; }
      { name = "Hacker News";  url = "https://news.ycombinator.com";              accent = c.gold; }
      { name = "Spotify";      url = "https://open.spotify.com";                  accent = c.green; }
    ];
  };

  # One URL serves as both homepage and new tab page. ./firefox/newtab.cfg
  # makes it Firefox's new tab URL, which is what keeps the URL bar empty.
  startPageFile = pkgs.writeText "firefox-start.html" startPage.document;
  startPageUrl = "file://${startPageFile}";

  # Must be a derivation, not a bare path: the wrapper splices extraPrefsFiles
  # in with toString, which strips the string context a path would need to
  # become a build input.
  newTabCfg = pkgs.writeText "newtab.cfg" (builtins.readFile ./firefox/newtab.cfg);
in

{
  programs.firefox = {
    enable = true;
    package = pkgs.firefox.override { extraPrefsFiles = [ newTabCfg ]; };
    configPath = "${config.xdg.configHome}/mozilla/firefox";
    profiles.default = {
      extensions.packages = with pkgs.nur.repos.rycee.firefox-addons; [
        ublock-origin
        bitwarden
      ];

      userChrome = subst ./firefox/userChrome.css;
      userContent = subst ./firefox/userContent.css;

      search = {
        force = true;
        default = "ddg";
        privateDefault = "ddg";
        order = [
          "ddg"
          "nix-packages"
          "nix-options"
          "home-manager-options"
          "nixos-wiki"
          "google"
        ];
        engines = {
          nix-packages = {
            name = "Nix Packages";
            urls = [
              {
                template = "https://search.nixos.org/packages";
                params = [
                  { name = "type"; value = "packages"; }
                  { name = "query"; value = "{searchTerms}"; }
                ];
              }
            ];
            icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
            definedAliases = [ "@np" ];
          };

          nix-options = {
            name = "NixOS Options";
            urls = [
              {
                template = "https://search.nixos.org/options";
                params = [
                  { name = "type"; value = "options"; }
                  { name = "query"; value = "{searchTerms}"; }
                ];
              }
            ];
            icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
            definedAliases = [ "@no" ];
          };

          home-manager-options = {
            name = "Home Manager Options";
            urls = [
              { template = "https://home-manager-options.extranix.com/?query={searchTerms}"; }
            ];
            icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
            definedAliases = [ "@hm" ];
          };

          nixos-wiki = {
            name = "NixOS Wiki";
            urls = [
              { template = "https://wiki.nixos.org/w/index.php?search={searchTerms}"; }
            ];
            icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
            definedAliases = [ "@nw" ];
          };

          bing.metaData.hidden = true;
          amazondotcom-us.metaData.hidden = true;
          ebay.metaData.hidden = true;
        };
      };

      settings = {
        "layout.css.devPixelsPerPx" = "1.0";

        # ===== Theming =====
        # userChrome.css / userContent.css above are inert without this.
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
        "ui.systemUsesDarkTheme" = 1;
        "browser.theme.toolbar-theme" = 0;
        "browser.theme.content-theme" = 0;
        # Report dark to sites that honour prefers-color-scheme.
        "layout.css.prefers-color-scheme.content-override" = 0;
        # Expose the compact-density toggle in Customize; density left at normal.
        "browser.compactmode.show" = true;
        "browser.tabs.firefox-view" = false;
        "browser.aboutConfig.showWarning" = false;

        # ===== Start page =====
        "browser.startup.page" = 1;
        "browser.startup.homepage" = startPageUrl;
        # Read by ./firefox/newtab.cfg, which makes this the new tab URL too.
        "nixos.newtab.url" = startPageUrl;
        # Extensions installed from the Nix store are a "system" scope, which
        # Firefox disables by default.
        "extensions.autoDisableScopes" = 0;
        # Fallback if the autoconfig hook ever fails: a stock about:newtab
        # stripped of sponsored tiles, Pocket stories, weather and telemetry.
        "browser.newtabpage.activity-stream.showSponsored" = false;
        "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
        "browser.newtabpage.activity-stream.feeds.topsites" = false;
        "browser.newtabpage.activity-stream.feeds.section.topstories" = false;
        "browser.newtabpage.activity-stream.section.highlights.includePocket" = false;
        "browser.newtabpage.activity-stream.discoverystream.enabled" = false;
        "browser.newtabpage.activity-stream.showWeather" = false;
        "browser.newtabpage.activity-stream.default.sites" = "";
        "browser.newtabpage.activity-stream.telemetry" = false;
        "browser.newtabpage.activity-stream.feeds.telemetry" = false;
        "browser.topsites.contile.enabled" = false;
        "extensions.pocket.enabled" = false;

        # ===== Address bar =====
        # Firefox Suggest is sponsored placement; trending and weather are noise.
        "browser.urlbar.quicksuggest.enabled" = false;
        "browser.urlbar.suggest.quicksuggest.sponsored" = false;
        "browser.urlbar.suggest.quicksuggest.nonsponsored" = false;
        "browser.urlbar.sponsoredTopSites" = false;
        "browser.urlbar.suggest.trending" = false;
        "browser.urlbar.trending.featureGate" = false;
        "browser.urlbar.weather.featureGate" = false;
        "browser.urlbar.suggest.weather" = false;

        # ===== Telemetry =====
        "datareporting.healthreport.uploadEnabled" = false;
        "datareporting.policy.dataSubmissionEnabled" = false;
        "toolkit.telemetry.unified" = false;
        "toolkit.telemetry.enabled" = false;
        "toolkit.telemetry.archive.enabled" = false;
        "toolkit.telemetry.newProfilePing.enabled" = false;
        "toolkit.telemetry.shutdownPingSender.enabled" = false;
        "toolkit.telemetry.updatePing.enabled" = false;
        "toolkit.telemetry.bhrPing.enabled" = false;
        "toolkit.telemetry.firstShutdownPing.enabled" = false;
        "browser.ping-centre.telemetry" = false;

        # ===== Privacy =====
        "privacy.trackingprotection.enabled" = true;
        "privacy.trackingprotection.socialtracking.enabled" = true;
        "browser.contentblocking.category" = "strict";
        "privacy.globalprivacycontrol.enabled" = true;
        "signon.rememberSignons" = false;
        "signon.autofillForms" = false;
        "extensions.formautofill.addresses.enabled" = false;
        "extensions.formautofill.creditCards.enabled" = false;
        "browser.formfill.enable" = false;
      };
    };
  };
}
