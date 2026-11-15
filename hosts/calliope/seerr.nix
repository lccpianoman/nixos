{ pkgs, ... }:

# Seerr (the continuation of Overseerr/Jellyseerr): media requests for Plex
# users. The one deliberately public service, Cloudflare-proxied through
# caddy.nix under two names. Runs as a DynamicUser sandbox with its own state
# dir and talks to Plex/radarr/sonarr over localhost HTTP, so it needs no
# media group and no mounts.
#
# seerr-gate is a prank on one user. request.jukeluke.com asks it about every
# request (Caddy's forward_auth) and it answers 502 when the session belongs
# to one of `blocked`, so for that user the normal name looks like a dead
# origin and only the second domain works. It has to ask Seerr, because the
# session cookie is opaque to Caddy, and keying on the account rather than
# an address is what survives a new device, network or cleared cookies.
# Logged-out visitors pass: the block lands on the first request after
# signing in. A gate that is down blocks nobody: caddy.nix proxies anyway.

let
  port     = 5055;
  gatePort = 5056;

  # Seerr user ids, from Users in the UI (the number in /users/N).
  blocked = [ 2 ];
in
{
  services.seerr = {
    enable = true;
    inherit port;
  };

  systemd.services.seerr-gate = {
    description = "Per-user gate for Seerr's main vhost";
    wantedBy    = [ "multi-user.target" ];

    environment = {
      SEERR_GATE_PORT     = toString gatePort;
      SEERR_GATE_UPSTREAM = "http://127.0.0.1:${toString port}";
      SEERR_GATE_BLOCKED  = builtins.concatStringsSep "," (map toString blocked);
    };

    serviceConfig = {
      ExecStart  = "${pkgs.python3}/bin/python3 ${./seerr/gate.py}";
      Restart    = "always";
      RestartSec = 1;

      DynamicUser      = true;
      IPAddressDeny    = "any";
      IPAddressAllow   = "localhost";
      NoNewPrivileges  = true;
      ProtectSystem    = "strict";
      ProtectHome      = true;
      PrivateTmp       = true;
      PrivateDevices   = true;
      ProtectKernelTunables = true;
      ProtectControlGroups  = true;
      CapabilityBoundingSet   = "";
      RestrictAddressFamilies = [ "AF_INET" "AF_INET6" ];
      SystemCallArchitectures = "native";
    };
  };
}
