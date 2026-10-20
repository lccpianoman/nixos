{ config, pkgs, lib, ... }:

# The only module on this host that exposes anything. One public vhost
# (request.jukeluke.com, Cloudflare-proxied like vault on nixvps) and a set of
# LAN-only vhosts for the admin UIs, all proxying to localhost services.
#
# Certificates come from Let's Encrypt via DNS-01 (`acme_dns cloudflare`),
# because the LAN-only names resolve to 192.168.0.10 and can never answer an
# HTTP-01 challenge from the internet. That needs two things set up by hand,
# both described in README's "Media services":
#   - DNS: request.jukeluke.com proxied (orange) to the home IP; dash/qb/
#     radarr/sonarr/prowlarr.jukeluke.com unproxied (grey) A records to
#     192.168.0.10.
#   - secrets/calliope/cloudflare.env holding a real CLOUDFLARE_API_TOKEN
#     (Zone:DNS:Edit on jukeluke.com). The committed file is an encrypted
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
  # that SNI and Host header. remote_ip is the socket address — not a header,
  # not spoofable — and is what actually keeps these vhosts off the internet.
  lanOnly = upstream: ''
    @wan not remote_ip 192.168.0.0/24 127.0.0.1/8 ::1
    abort @wan
    ${securityHeaders}
    reverse_proxy ${upstream}
  '';
in
{
  sops.secrets."cloudflare.env" = {
    sopsFile = ../../secrets/calliope/cloudflare.env;
    format   = "dotenv";
    key      = "";
  };

  services.caddy = {
    enable = true;

    # Stock caddy has no DNS providers; this rebuilds it with the cloudflare
    # module so acme_dns works. The hash pins the vendored Go dependencies and
    # must be refreshed whenever the plugin version or caddy itself moves —
    # the build fails loudly with the new hash when it does.
    package = pkgs.caddy.withPlugins {
      plugins = [ "github.com/caddy-dns/cloudflare@v0.2.4" ];
      hash = "sha256-xRJ5evsAJ2akg47j3Bt6YDXJOgX88B/rKNP50KSVyNY=";
    };

    environmentFile = config.sops.secrets."cloudflare.env".path;

    globalConfig = ''
      acme_dns cloudflare {env.CLOUDFLARE_API_TOKEN}
      servers {
        client_ip_headers CF-Connecting-IP
        trusted_proxies static ${cloudflareRanges}
      }
    '';

    # Public, via Cloudflare. The matcher drops anything that reaches the
    # forwarded port directly instead of through Cloudflare's edge — same
    # ranges the global trusted_proxies uses.
    virtualHosts."request.jukeluke.com".extraConfig = ''
      @direct not remote_ip ${cloudflareRanges}
      abort @direct
      ${securityHeaders}
      reverse_proxy 127.0.0.1:5055 {
        header_up X-Real-IP {client_ip}
      }
    '';

    # LAN-only. homepage-dashboard has no auth of its own, and the *arr UIs
    # and qBittorrent are admin surfaces — none of these may answer the WAN.
    virtualHosts."dash.jukeluke.com".extraConfig     = lanOnly "127.0.0.1:8082";
    virtualHosts."qb.jukeluke.com".extraConfig       = lanOnly "127.0.0.1:8090";
    virtualHosts."radarr.jukeluke.com".extraConfig   = lanOnly "127.0.0.1:7878";
    virtualHosts."sonarr.jukeluke.com".extraConfig   = lanOnly "127.0.0.1:8989";
    virtualHosts."prowlarr.jukeluke.com".extraConfig = lanOnly "127.0.0.1:9696";
  };
}
