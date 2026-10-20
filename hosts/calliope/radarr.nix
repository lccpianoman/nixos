# Movies. Localhost-only; reached via radarr.jukeluke.com (caddy.nix).
# group media so imports into the shared library keep the 2775 tree writable.
{
  services.radarr = {
    enable = true;
    group = "media";
    settings.server = {
      port        = 7878;
      bindaddress = "127.0.0.1";
    };
  };

  systemd.services.radarr.unitConfig.RequiresMountsFor = [
    "/srv/media/downloads"
    "/srv/media/library/movies"
  ];
}
