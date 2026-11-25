{ config, pkgs, lib, ... }:

# The only module of the media stack that exposes anything (the one other
# public listener on this host is minecraft.nix). Two public vhosts for
# Seerr (request.jukeluke.com and a second domain, Cloudflare-proxied like
# vault on nixvps) and a set of LAN-only vhosts for the admin UIs, all
# proxying to localhost services.
#
# Certificates come from Let's Encrypt via DNS-01 (`acme_dns cloudflare`),
# because the LAN-only names resolve to 192.168.0.10 and can never answer an
# HTTP-01 challenge from the internet. That needs two things set up by hand,
# both described in docs/calliope-media.md "One-time setup":
#   - DNS: request.jukeluke.com and the second domain's apex proxied
#     (orange) to the home IP; dash/qb/radarr/sonarr/prowlarr/
#     photos.jukeluke.com unproxied (grey) A records to 192.168.0.10.
#   - secrets/calliope/cloudflare.env holding a real CLOUDFLARE_API_TOKEN
#     (Zone:DNS:Edit on all zones). The committed file is an encrypted
#     REPLACE_ME placeholder so the config evaluates before the token exists;
#     cert issuance just fails until it is real.

let
  cloudflareRanges = lib.concatStringsSep " " (import ../../common/cloudflare-ranges.nix);

  securityHeaders = ''
    header {
      Strict-Transport-Security "max-age=31536000"
      X-Content-Type-Options "nosniff"
      Referrer-Policy "same-origin"
      Permissions-Policy "camera=(), geolocation=(), microphone=(), payment=(), usb=()"
      X-Frame-Options "SAMEORIGIN"
    }
  '';

  # 443 is forwarded from the router for the public vhost, so DNS pointing a
  # name at 192.168.0.10 hides nothing: anyone can connect to the home IP with
  # that SNI and Host header. remote_ip is the socket address (not a header,
  # not spoofable) and is what actually keeps these vhosts off the internet.
  lanRanges = "192.168.0.0/24 127.0.0.1/8 ::1";

  lanOnly = upstream: ''
    @wan not remote_ip ${lanRanges}
    abort @wan
    ${securityHeaders}
    reverse_proxy ${upstream}
  '';

  # Public, via Cloudflare. The matcher drops anything that reaches the
  # forwarded port directly instead of through Cloudflare's edge, using the
  # same ranges the global trusted_proxies uses. `route` keeps written
  # order: left to Caddy's sorting, forward_auth would run before the abort.
  #
  # With `gated`, seerr-gate (seerr.nix) is asked about every request and its
  # 502 goes straight back to the client. That 502 is a response; a gate
  # that cannot be reached at all is an error, which handle_errors answers by
  # proxying anyway. So a dead gate lets everyone in instead of locking
  # everyone out.
  seerrProxy = ''
    ${securityHeaders}
    reverse_proxy 127.0.0.1:5055 {
      header_up X-Real-IP {client_ip}
    }
  '';

  seerr = gated: ''
    @direct not remote_ip ${cloudflareRanges}
    route {
      abort @direct
      ${lib.optionalString gated ''
        forward_auth 127.0.0.1:5056 {
          uri /
        }
      ''}
      ${seerrProxy}
    }
    ${lib.optionalString gated ''
      handle_errors 502 {
        ${seerrProxy}
      }
    ''}
  '';
in
{
  # restartUnits so that rotating the token actually reaches Caddy: changing
  # only a secret's contents leaves the unit text identical, so a rebuild
  # would otherwise write the new value and leave Caddy holding the old one.
  sops.secrets."cloudflare.env" = {
    sopsFile = ../../secrets/calliope/cloudflare.env;
    format   = "dotenv";
    key      = "";
    restartUnits = [ "caddy.service" ];
  };

  services.caddy = {
    enable = true;

    # Stock caddy has no DNS providers; this rebuilds it with the cloudflare
    # module so acme_dns works. The hash pins the vendored Go dependencies and
    # must be refreshed whenever the plugin version or caddy itself moves;
    # the build fails loudly with the new hash when it does.
    package = pkgs.caddy.withPlugins {
      plugins = [ "github.com/caddy-dns/cloudflare@v0.2.4" ];
      hash = "sha256-tubXIDCJnO2mvdnPlZclwDhNGaeeYLSt7lnni3+pXDo=";
    };

    environmentFile = config.sops.secrets."cloudflare.env".path;

    globalConfig = ''
      acme_dns cloudflare {env.CLOUDFLARE_API_TOKEN}
      servers {
        client_ip_headers CF-Connecting-IP
        trusted_proxies static ${cloudflareRanges}
      }
    '';

    # Seerr under two names. The normal one is gated, so the one user
    # seerr-gate blocks sees a dead origin there; the second domain is the
    # same Seerr with no gate, and so the only name that works for them.
    virtualHosts."request.jukeluke.com".extraConfig = seerr true;
    virtualHosts."michaelakabedwargodlovestosuckcockandsipcum.com".extraConfig = seerr false;

    # LAN-only. homepage-dashboard has no auth of its own, and the *arr UIs
    # and qBittorrent are admin surfaces. None of these may answer the WAN.
    virtualHosts."qb.jukeluke.com".extraConfig       = lanOnly "127.0.0.1:8090";
    virtualHosts."radarr.jukeluke.com".extraConfig   = lanOnly "127.0.0.1:7878";
    virtualHosts."sonarr.jukeluke.com".extraConfig   = lanOnly "127.0.0.1:8989";
    virtualHosts."prowlarr.jukeluke.com".extraConfig = lanOnly "127.0.0.1:9696";

    # Immich has its own auth, but the library behind it is the family photo
    # archive, so it stays off the WAN like the admin UIs. The phones' backup
    # uploads go through this vhost, so don't cap request bodies here.
    virtualHosts."photos.jukeluke.com".extraConfig   = lanOnly "127.0.0.1:2283";

    # fanctl (fans.nix) rides under the dashboard's origin so homepage can
    # iframe it past X-Frame-Options SAMEORIGIN. `route` keeps written order:
    # left to Caddy's sorting, handle_path would run before the abort.
    virtualHosts."dash.jukeluke.com".extraConfig = ''
      @wan not remote_ip ${lanRanges}
      ${securityHeaders}
      route {
        abort @wan
        redir /fans /fans/
        handle_path /fans/* {
          reverse_proxy 127.0.0.1:8085
        }
        reverse_proxy 127.0.0.1:8082
      }
    '';
  };
}
