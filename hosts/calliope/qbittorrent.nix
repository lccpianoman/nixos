{ config, pkgs, lib, ... }:

# qBittorrent, and only qBittorrent, routed through a TorGuard WireGuard
# tunnel (wg-qb).
#
# The tunnel is deliberately inert: secrets/calliope/wg-qb.conf carries
# `Table = off`, so wg-quick brings the interface up without installing any
# route or rule. Left to itself, nothing on this host would use it. That is
# the point — the provider's stock config has `AllowedIPs = 0.0.0.0/0` and no
# Table line, which makes wg-quick install a host-wide default route and drag
# every service onto the VPN. It also breaks inbound Seerr outright: Cloudflare
# connects on eno1, and Caddy's reply to a public address would egress via
# wg-qb instead, so the reply never arrives. The config must likewise carry no
# `DNS =` line, because wg-quick's set_dns runs `resolvconf -x` and would make
# the provider's resolver the whole box's only resolver.
#
# So this module does the routing itself, scoped to one uid:
#   1. A `uidrange` policy rule sends everything owned by the qbittorrent uid
#      to a table whose only route is the tunnel.
#   2. A private /etc/resolv.conf gives the service the VPN's resolver, so its
#      tracker lookups travel the tunnel instead of leaking to the LAN router.
#   3. The filter kill switch REJECTs anything from that uid that still tries
#      to leave by another interface.
#
# (3) is what makes (1) safe to get wrong. If the rule or route is ever
# missing, qBittorrent's packets fall back to eno1 and are rejected — the
# failure mode is an outage, never a leak.
#
# This deliberately keys on the uid rather than on an fwmark set in mangle
# OUTPUT, which is the obvious approach and is subtly broken. A mark is only
# applied as the packet is transmitted, long after connect() has already
# chosen a route and pinned the socket's source address to eno1's. The
# subsequent reroute moves the packet to wg-qb but keeps that stale source,
# which the kernel then refuses, so the packet falls back to eno1 and is
# rejected. It worked for libtorrent's own sockets only because those are
# explicitly bound to wg-qb (Session\Interface below) and so had the right
# source all along — while everything unbound, DNS lookups most importantly,
# was silently rejected. A uid rule is consulted during the *original* route
# lookup, so source selection is correct from the start and no reroute,
# marking or address rewriting is involved.

let
  # The port TorGuard forwards for this account, TCP and UDP. If that
  # assignment ever changes, this is the one place to change it: the firewall
  # hole on wg-qb below is derived from it. Outbound torrenting works
  # regardless; a mismatch only costs inbound peers.
  torrentPort = 47278;

  # Routing table holding the tunnel's default route, selected by the uid rule.
  routeTable = 51820;

  # Pinned so the routing rule can name it. The module leaves this to dynamic
  # allocation, which would silently stop matching if it ever shifted — and a
  # rule that no longer matches means qBittorrent is cut off by the kill
  # switch. 996 is what it already holds, so pinning changes nothing on disk.
  qbtUid = 996;

  # WireGuard sends its own encrypted packets from the kernel, not from this
  # uid, so they never match the rule below and route normally out eno1 —
  # which is what stops the tunnel from trying to carry itself.

  # From TorGuard's config, where it arrived as the `DNS =` line removed
  # above. A public resolver rather than a tunnel-internal one, so it is
  # reachable over the tunnel like any other destination.
  vpnDns = "8.8.8.8";

  uidRule = "uidrange ${toString qbtUid}-${toString qbtUid} lookup ${toString routeTable}";

  vpnRouting = pkgs.writeShellScript "qbittorrent-vpn-routing" ''
    set -eu
    ip="${pkgs.iproute2}/bin/ip"
    # `replace` and the del/add pair keep this idempotent across restarts.
    $ip route replace default dev wg-qb table ${toString routeTable}
    $ip rule del ${uidRule} 2>/dev/null || true
    $ip rule add ${uidRule}
  '';

  vpnRoutingStop = pkgs.writeShellScript "qbittorrent-vpn-routing-stop" ''
    ip="${pkgs.iproute2}/bin/ip"
    $ip rule del ${uidRule} 2>/dev/null || true
    $ip route del default dev wg-qb table ${toString routeTable} 2>/dev/null || true
  '';
in
{
  # The provider-issued tunnel, kept whole as one secret because the key,
  # address and endpoint arrive together. Committed as a REPLACE_ME
  # placeholder (see README's "Media services"), so until it is real wg-qb
  # fails to start and qBittorrent, which bindsTo it, stays down.
  sops.secrets."wg-qb.conf" = {
    sopsFile = ../../secrets/calliope/wg-qb.conf;
    format   = "binary";
  };

  networking.wg-quick.interfaces.wg-qb = {
    configFile = config.sops.secrets."wg-qb.conf".path;
  };

  # Only this service resolves through the VPN; the host keeps its own
  # resolv.conf. /etc/resolv.conf is a regular file here, not a symlink, so the
  # bind below lands on the file itself and stays inside the unit's private
  # mount namespace.
  environment.etc."qbittorrent/resolv.conf".text = ''
    nameserver ${vpnDns}
  '';

  users.users.qbittorrent.uid = qbtUid;

  services.qbittorrent = {
    enable = true;
    group = "media";
    webuiPort = 8090;
    torrentingPort = torrentPort;

    # The module reinstalls this file over qBittorrent.conf on EVERY start:
    # the config is fully declarative, and anything changed in the WebUI
    # options dialog is silently reverted at the next restart. Make settings
    # changes here, not there. (Torrents, categories and RSS state live in
    # separate files and are unaffected.)
    serverConfig = {
      LegalNotice.Accepted = true;
      BitTorrent.Session = {
        # Binds libtorrent's sockets to the tunnel, which also gives them the
        # right source address. These are the qBittorrent 5.x keys — the old
        # Preferences\Connection\InterfaceName location is dead.
        Interface       = "wg-qb";
        InterfaceName   = "wg-qb";
        DefaultSavePath = "/srv/media/downloads/complete";
        TempPath        = "/srv/media/downloads/incomplete";
        TempPathEnabled = true;
      };
      Preferences.WebUI = {
        # Localhost-only; Caddy is the only client, and reaches it over lo.
        Address       = "127.0.0.1";
        ServerDomains = "qb.jukeluke.com";
      };
    };
  };

  # MASQUERADE is kept as a safety net rather than a necessity: the uid rule
  # already gets source selection right, so this is a no-op in the normal
  # case and only rewrites an address that somehow arrived wrong. Cheap
  # insurance against the exact failure the fwmark approach had.
  #
  # No IPv6 equivalent on purpose — TorGuard issues a v4-only tunnel
  # (AllowedIPs is 0.0.0.0/0, with no ::/0), so there is nowhere for v6 to go
  # and the ip6tables REJECT below is the whole v6 policy.
  networking.firewall.extraCommands = lib.mkAfter ''
    iptables -t nat    -C POSTROUTING -o wg-qb -j MASQUERADE 2>/dev/null || iptables -t nat    -A POSTROUTING -o wg-qb -j MASQUERADE

    # Exempt the tunnel from reverse-path filtering, which is strict here
    # (networking.firewall.checkReversePath defaults to true == "strict").
    # Packets arriving on wg-qb are unmarked, so NixOS's `rpfilter --validmark`
    # test resolves their source through the main table, finds eno1, sees a
    # different interface and drops them. That would kill not just inbound
    # peers but every reply to qBittorrent's own connections, making the
    # tunnel silently useless. A full-tunnel setup never hits this because its
    # default route points at the interface; ours deliberately does not.
    #
    # Safe to skip the test here: WireGuard has already authenticated every
    # packet on this interface against the peer's key, and AllowedIPs lets
    # that peer carry any source. Strict filtering stays on eno1, which is
    # where spoofing could actually come from. Inserted at the head because
    # the chain ends in -j DROP, and re-inserted on every firewall reload
    # because the chain is rebuilt each time.
    iptables -t mangle -C nixos-fw-rpfilter -i wg-qb -j RETURN 2>/dev/null || iptables -t mangle -I nixos-fw-rpfilter -i wg-qb -j RETURN 2>/dev/null || true

    iptables  -C OUTPUT -m owner --uid-owner qbittorrent -o lo    -j ACCEPT 2>/dev/null || iptables  -A OUTPUT -m owner --uid-owner qbittorrent -o lo    -j ACCEPT
    iptables  -C OUTPUT -m owner --uid-owner qbittorrent -o wg-qb -j ACCEPT 2>/dev/null || iptables  -A OUTPUT -m owner --uid-owner qbittorrent -o wg-qb -j ACCEPT
    iptables  -C OUTPUT -m owner --uid-owner qbittorrent          -j REJECT 2>/dev/null || iptables  -A OUTPUT -m owner --uid-owner qbittorrent          -j REJECT
    ip6tables -C OUTPUT -m owner --uid-owner qbittorrent -o lo    -j ACCEPT 2>/dev/null || ip6tables -A OUTPUT -m owner --uid-owner qbittorrent -o lo    -j ACCEPT
    ip6tables -C OUTPUT -m owner --uid-owner qbittorrent          -j REJECT 2>/dev/null || ip6tables -A OUTPUT -m owner --uid-owner qbittorrent          -j REJECT
  '';

  networking.firewall.extraStopCommands = lib.mkAfter ''
    iptables -t nat    -D POSTROUTING -o wg-qb -j MASQUERADE 2>/dev/null || true
    iptables -t mangle -D nixos-fw-rpfilter -i wg-qb -j RETURN 2>/dev/null || true

    iptables  -D OUTPUT -m owner --uid-owner qbittorrent -o lo    -j ACCEPT 2>/dev/null || true
    iptables  -D OUTPUT -m owner --uid-owner qbittorrent -o wg-qb -j ACCEPT 2>/dev/null || true
    iptables  -D OUTPUT -m owner --uid-owner qbittorrent          -j REJECT 2>/dev/null || true
    ip6tables -D OUTPUT -m owner --uid-owner qbittorrent -o lo    -j ACCEPT 2>/dev/null || true
    ip6tables -D OUTPUT -m owner --uid-owner qbittorrent          -j REJECT 2>/dev/null || true
  '';

  # Incoming peers arrive through the tunnel, never on eno1, so the hole is
  # scoped to wg-qb.
  networking.firewall.interfaces."wg-qb" = {
    allowedTCPPorts = [ torrentPort ];
    allowedUDPPorts = [ torrentPort ];
  };

  # Separate unit rather than an ExecStartPost on wg-quick: the rule and route
  # need the interface to exist, and keeping them here makes a failure visible
  # as its own failed unit instead of a cascade.
  systemd.services.qbittorrent-vpn-routing = {
    description = "Policy route qBittorrent's marked traffic into wg-qb";
    after      = [ "wg-quick-wg-qb.service" ];
    bindsTo    = [ "wg-quick-wg-qb.service" ];
    requiredBy = [ "qbittorrent.service" ];
    before     = [ "qbittorrent.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = vpnRouting;
      ExecStop  = vpnRoutingStop;
    };
  };

  systemd.services.qbittorrent = {
    wants   = [ "wg-quick-wg-qb.service" ];
    after   = [ "wg-quick-wg-qb.service" ];
    bindsTo = [ "wg-quick-wg-qb.service" ];
    unitConfig.RequiresMountsFor = [ "/srv/media/downloads" ];
    serviceConfig.BindReadOnlyPaths = [ "/etc/qbittorrent/resolv.conf:/etc/resolv.conf" ];
  };
}
