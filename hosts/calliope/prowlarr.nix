# Indexer manager for radarr/sonarr. Localhost-only; reached via
# prowlarr.jukeluke.com (caddy.nix). Touches no media files, so unlike the
# other *arrs it stays out of the media group and needs no mounts.
{
  services.prowlarr = {
    enable = true;
    settings.server = {
      port        = 9696;
      bindaddress = "127.0.0.1";
    };
  };
}
