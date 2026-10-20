# Plex is the one service clients talk to directly rather than through Caddy:
# openFirewall exposes 32400 plus the GDM/DLNA discovery ports to the LAN, and
# remote streaming goes through plex.tv relay/NAT traversal, not port 443.
# group media grants read access to the 2775 library tree.
{
  services.plex = {
    enable = true;
    group = "media";
    openFirewall = true;
  };

  systemd.services.plex.unitConfig.RequiresMountsFor = [ "/srv/media/library" ];
}
