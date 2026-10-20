# Seerr (the continuation of Overseerr/Jellyseerr): media requests for Plex
# users. The one deliberately public service — Cloudflare-proxied at
# request.jukeluke.com via caddy.nix. Runs as a DynamicUser sandbox with its
# own state dir and talks to Plex/radarr/sonarr over localhost HTTP, so it
# needs no media group and no mounts.
{
  services.seerr = {
    enable = true;
    port = 5055;
  };
}
