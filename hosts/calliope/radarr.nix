# Movies. Localhost-only; reached via radarr.jukeluke.com (caddy.nix).
# group media so imports into the shared library keep the 2775 tree writable.
{ config, lib, ... }:

{
  # Pins Radarr's API key, so recyclarr.nix can read it from the same secret
  # instead of it living only in Radarr's config.xml. restartUnits because a
  # changed secret alone leaves the unit text identical.
  sops.secrets."radarr.env" = {
    sopsFile = ../../secrets/calliope/radarr.env;
    format   = "dotenv";
    key      = "";
    restartUnits = [ "radarr.service" ];
  };

  services.radarr = {
    enable = true;
    group = "media";
    settings.server = {
      port        = 7878;
      bindaddress = "127.0.0.1";
    };
    # No login, as with qBittorrent: the LAN guard on the Caddy vhost is the
    # access control. Also stops Radarr demanding a user on first start.
    settings.auth.method = "External";
    environmentFiles = [ config.sops.secrets."radarr.env".path ];
  };

  systemd.services.radarr.unitConfig.RequiresMountsFor = [
    "/srv/media/downloads"
    "/srv/media/library/movies"
  ];
  # Forced over the module's hard-set 0022, which would leave library
  # folders writable by radarr alone.
  systemd.services.radarr.serviceConfig.UMask = lib.mkForce "0002";
}
