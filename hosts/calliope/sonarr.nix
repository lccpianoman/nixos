# TV. Localhost-only; reached via sonarr.jukeluke.com (caddy.nix).
# group media so imports into the shared library keep the 2775 tree writable.
{ config, lib, ... }:

{
  # Pins Sonarr's API key for recyclarr.nix, as radarr.nix does for Radarr.
  # YAML, not dotenv: sops-nix ignores `key` for dotenv.
  sops.secrets."sonarr-api-key" = {
    sopsFile = ../../secrets/calliope/sonarr.yaml;
    key      = "api_key";
  };

  # restartUnits because a changed secret alone leaves the unit text identical.
  sops.templates."sonarr.env" = {
    content = ''
      SONARR__AUTH__APIKEY=${config.sops.placeholder."sonarr-api-key"}
    '';
    restartUnits = [ "sonarr.service" ];
  };

  services.sonarr = {
    enable = true;
    group = "media";
    settings.server = {
      port        = 8989;
      bindaddress = "127.0.0.1";
    };
    # No login, as with qBittorrent: the LAN guard on the Caddy vhost is the
    # access control. Also stops Sonarr demanding a user on first start.
    settings.auth.method = "External";
    environmentFiles = [ config.sops.templates."sonarr.env".path ];
  };

  systemd.services.sonarr.unitConfig.RequiresMountsFor = [
    "/srv/media/downloads"
    "/srv/media/library/shows"
  ];
  # Forced over the module's hard-set 0022, which would leave library
  # folders writable by sonarr alone.
  systemd.services.sonarr.serviceConfig.UMask = lib.mkForce "0002";
}
