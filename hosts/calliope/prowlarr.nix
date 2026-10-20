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
    # No login, as with qBittorrent: the LAN guard on the Caddy vhost is the
    # access control. Also stops Prowlarr demanding a user on first start.
    settings.auth.method = "External";
  };
}
