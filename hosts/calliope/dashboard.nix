# homepage-dashboard at dash.jukeluke.com — LAN-only via caddy.nix, because it
# has no authentication of its own and its widgets will eventually carry
# service API keys (put those in environmentFiles, never in settings — the
# settings land in the world-readable store).
{
  services.homepage-dashboard = {
    enable = true;
    listenPort = 8082;
    allowedHosts = "dash.jukeluke.com,localhost:8082,127.0.0.1:8082";

    settings = {
      title = "Calliope";
      language = "en";
      headerStyle = "clean";
      hideVersion = true;
      target = "_blank";
    };

    widgets = [
      {
        resources = {
          cpu = true;
          memory = true;
          disk = [ "/" "/srv/media" ];
        };
      }
    ];

    # Links only for now; per-service API widgets come when each service is
    # configured. Everything except Plex goes through the Caddy vhosts — the
    # services themselves are localhost-only and unreachable by IP:port.
    services = [
      {
        Media = [
          { Seerr       = { href = "https://request.jukeluke.com";  description = "Requests"; }; }
          { Plex        = { href = "http://192.168.0.10:32400/web"; description = "Media server"; }; }
          { qBittorrent = { href = "https://qb.jukeluke.com";       description = "Torrent client"; }; }
          { Radarr      = { href = "https://radarr.jukeluke.com";   description = "Movies"; }; }
          { Sonarr      = { href = "https://sonarr.jukeluke.com";   description = "TV"; }; }
          { Prowlarr    = { href = "https://prowlarr.jukeluke.com"; description = "Indexers"; }; }
        ];
      }
      # fans.nix. The iframe has to be same-origin with the dashboard, which is
      # why fanctl lives under /fans/ on this vhost rather than its own name.
      {
        Hardware = [
          {
            Fans = {
              href        = "https://dash.jukeluke.com/fans/";
              description = "Temperatures and fan control";
              widget = {
                type    = "iframe";
                name    = "fans";
                src     = "https://dash.jukeluke.com/fans/?embed";
                classes = "h-96 sm:h-96 md:h-96 lg:h-96 xl:h-96 2xl:h-96";
              };
            };
          }
        ];
      }
    ];
  };
}
