# TV. Localhost-only; reached via sonarr.jukeluke.com (caddy.nix).
# group media so imports into the shared library keep the 2775 tree writable.
{
  services.sonarr = {
    enable = true;
    group = "media";
    settings.server = {
      port        = 8989;
      bindaddress = "127.0.0.1";
    };
  };

  systemd.services.sonarr.unitConfig.RequiresMountsFor = [
    "/srv/media/downloads"
    "/srv/media/library/shows"
  ];
}
