# Movies. Localhost-only; reached via radarr.jukeluke.com (caddy.nix).
# group media so imports into the shared library keep the 2775 tree writable.
{ lib, ... }:

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
  # Forced over the module's hard-set 0022, which would leave library
  # folders writable by radarr alone.
  systemd.services.radarr.serviceConfig.UMask = lib.mkForce "0002";
}
