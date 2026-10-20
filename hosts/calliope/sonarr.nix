# TV. Localhost-only; reached via sonarr.jukeluke.com (caddy.nix).
# group media so imports into the shared library keep the 2775 tree writable.
{ lib, ... }:

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
  # Forced over the module's hard-set 0022, which would leave library
  # folders writable by sonarr alone.
  systemd.services.sonarr.serviceConfig.UMask = lib.mkForce "0002";
}
