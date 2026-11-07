# calliope — media services

One module per service under `hosts/calliope/`. Everything binds to
localhost and is reached through Caddy (`caddy.nix`), the only module that
exposes anything — except Plex, which clients talk to directly.

| Service | Module | Listens | Reached at |
|---|---|---|---|
| Seerr (requests) | `seerr.nix` | `127.0.0.1:5055` | `https://request.jukeluke.com` — **public**, Cloudflare-proxied |
| homepage dashboard | `dashboard.nix` | `127.0.0.1:8082` | `https://dash.jukeluke.com` — LAN only |
| fanctl | `fans.nix` | `127.0.0.1:8085` | `https://dash.jukeluke.com/fans/` — LAN only |
| qBittorrent | `qbittorrent.nix` | `127.0.0.1:8090` | `https://qb.jukeluke.com` — LAN only |
| Radarr | `radarr.nix` | `127.0.0.1:7878` | `https://radarr.jukeluke.com` — LAN only |
| Sonarr | `sonarr.nix` | `127.0.0.1:8989` | `https://sonarr.jukeluke.com` — LAN only |
| Prowlarr | `prowlarr.nix` | `127.0.0.1:9696` | `https://prowlarr.jukeluke.com` — LAN only |
| Immich | `immich.nix` | `127.0.0.1:2283` | `https://photos.jukeluke.com` — LAN only |
| Plex | `plex.nix` | `0.0.0.0:32400` | `http://192.168.0.10:32400/web` on the LAN; remote via plex.tv |
| Recyclarr | `recyclarr.nix` | — | daily timer syncing TRaSH Guides into Radarr and Sonarr |

Every service that touches `/srv/media` or `/srv/photos` carries
`RequiresMountsFor`, which is what makes the `nofail` ZFS mounts safe: if the
pool fails to import, the services fail individually instead of writing into
the bare directory on the NVMe. Radarr, Sonarr and qBittorrent share the
`media` group and the one `storage/media` dataset so imports are hardlinks,
and all run with `UMask=0002` (forced on the servarr modules, which hard-set
`0022` and would leave each file writable only by its creator).

Service-level configuration — indexers, root folders, download clients, API
keys between the \*arrs, dashboard widgets — is done in each UI after first
boot and is not in this repo, except where noted below. Dashboard widget API
keys must go through `services.homepage-dashboard.environmentFiles`, never
`settings`, because `settings` lands in the world-readable store.

## Caddy

Ports 80/443 are forwarded from the router to calliope so Cloudflare can
reach Seerr. That forwarding is why "LAN only" cannot be left to DNS: anyone
can connect to the home IP with the right SNI, so every non-public vhost
carries a `remote_ip` guard (the socket address — unspoofable, unlike
headers) and the public vhost accepts only Cloudflare's edge ranges
(`common/cloudflare-ranges.nix`, shared with nixvps). **Never remove those
guards.**

Certificates come from Let's Encrypt over **DNS-01** (`acme_dns cloudflare`)
because names that resolve to `192.168.0.10` can never answer an HTTP-01
challenge. That required rebuilding Caddy with the Cloudflare DNS plugin
(`pkgs.caddy.withPlugins`), whose vendor `hash` fails loudly with the
replacement value whenever Caddy or the plugin moves.

## One-time setup

Two secrets were committed as encrypted `REPLACE_ME` placeholders so the
configuration evaluates before they exist. Until they are real, certificate
issuance fails and `wg-quick-wg-qb` fails, so qBittorrent (which `bindsTo`
it) stays down by design.

1. **Cloudflare DNS**: `request` proxied (orange cloud) to the home IP;
   `dash`, `qb`, `radarr`, `sonarr`, `prowlarr`, `photos` as **unproxied**
   (grey) A records to `192.168.0.10`.
2. **API token**: create a Cloudflare token scoped to Zone → DNS → Edit on
   jukeluke.com, then `sops secrets/calliope/cloudflare.env` and replace the
   placeholder value of `CLOUDFLARE_API_TOKEN`.
3. **WireGuard tunnel**: `sops secrets/calliope/wg-qb.conf` and paste the
   TorGuard config with **two edits to `[Interface]`**:
   - **Add `Table = off`.** Without it, `AllowedIPs = 0.0.0.0/0` makes
     wg-quick install a host-wide default route, dragging every service onto
     the VPN. It also breaks inbound Seerr: Cloudflare connects on `eno1`,
     and Caddy's reply would egress via `wg-qb` and never arrive. With it,
     `AllowedIPs` is a statement about what the peer may carry, and
     `qbittorrent.nix` does the routing itself.
   - **Delete the `DNS =` line.** It makes wg-quick run `resolvconf -x` and
     replace the whole host's resolvers. The VPN resolver is instead pinned
     for the one service via a private `/etc/resolv.conf`. This is *not*
     gated by `Table = off`, so the line has to go.

   See [Keys and secrets](secrets.md#editing-a-secret) for how to edit them.

## qBittorrent over WireGuard

qBittorrent — and nothing else — is routed through the `wg-qb` tunnel.
Because the interface carries `Table = off`, it is inert until this host
puts traffic on it, which `qbittorrent.nix` does per uid:

1. An `ip rule` with `uidrange` sends everything owned by the `qbittorrent`
   user (uid pinned to 996 so the rule cannot silently stop matching) to a
   routing table whose only route is `wg-qb`.
2. A private `/etc/resolv.conf`, bound into that unit alone, points at the
   VPN's resolver so tracker lookups cannot leak to the LAN router.
3. An iptables kill switch REJECTs anything from that uid that tries to
   leave by any other interface, and REJECTs IPv6 outright (the tunnel is
   v4-only).

(3) is what makes (1) safe to get wrong: if the rule or route is ever
missing, the packets fall back to `eno1` and are rejected — an outage, never
a leak.

### Why uid, not fwmark

Keying on the uid rather than on an fwmark set in `mangle OUTPUT` is
deliberate. A mark is applied as the packet is transmitted, long after
`connect()` has chosen a route and pinned the socket's source address to
`eno1`'s. The reroute then moves the packet to `wg-qb` with that stale
source, the kernel refuses it, and it falls back to `eno1` where the kill
switch rejects it. That failed silently and selectively: libtorrent's own
sockets are explicitly bound to `wg-qb` (`Session\Interface`) so they always
worked, while everything unbound — DNS above all — was rejected. A uid rule
is consulted during the *original* route lookup, so source selection is
right from the start. `MASQUERADE` on `wg-qb` is kept only as a cheap no-op
safety net.

### Reverse-path filtering

Split routing needs the tunnel exempted from rpfilter.
`networking.firewall.checkReversePath` defaults to strict, and packets
arriving on `wg-qb` carry no mark, so NixOS's `rpfilter --validmark` test
resolves their source through the main table, finds `eno1`, and drops them —
killing every reply to qBittorrent's own connections. The exemption is a
`RETURN` at the head of `nixos-fw-rpfilter` for `wg-qb`; safe because
WireGuard has already authenticated every packet on that interface, and
strict filtering stays on `eno1` where spoofing could actually originate.

### The kill-switch exemption

The kill switch needs one exemption, and omitting it strangles the tunnel.
Every packet qBittorrent sends crosses `OUTPUT` **twice**: once as plaintext
routed to `wg-qb`, then again as the encrypted outer UDP packet to the VPN
endpoint, routed out `eno1`. WireGuard does not orphan the skb in between, so
the outer packet still carries uid 996 and the kill switch rejects the
tunnel's own traffic. `wg show` looks perfectly healthy throughout. The
giveaway is ACCEPT and REJECT counters that stay exactly equal:

```bash
sudo iptables -L OUTPUT -nvx | grep 996
```

The fix is `wg set wg-qb fwmark` (applied by `qbittorrent-vpn-routing`) plus
a matching `-m mark` ACCEPT ahead of the REJECT. Marking identifies
WireGuard's output precisely and survives the endpoint or port changing.

### Port forwarding

`torrentPort` in `qbittorrent.nix` must match the port TorGuard forwards and
is the single place to change it — the `wg-qb` firewall hole derives from it.
Request the port as **both TCP and UDP** (TCP for the peer wire protocol, UDP
for µTP and DHT), and re-request it after changing endpoints, since the
forward is issued per server.

### Configuration and access

`qBittorrent.conf` is **fully declarative** — the module reinstalls it on
every service start, so settings changed in the WebUI revert on restart.
Change them in `serverConfig` instead. Torrent state, categories and RSS live
in separate files and survive.

The WebUI has **no login**: `WebUI\AuthSubnetWhitelist` is `127.0.0.1/32`,
and since Caddy proxies from loopback, every request that can reach it is
exempt. (This is not `LocalHostAuth`, which was removed in qBittorrent 5.x
and would be silently ignored.) All access control therefore rests on the LAN
guard on the `qb.jukeluke.com` vhost — a bigger grant than it appears, since
the WebUI can run a program on torrent completion, so reaching it means code
execution as `qbittorrent` with write access to the whole library. If the
LAN ever stops being a trust boundary, set `Password_PBKDF2` in
`serverConfig` and drop the whitelist.

## Radarr, Sonarr, Prowlarr

All three use `settings.auth.method = "External"`, which turns off their own
login (and the first-start "create a user" screen) and leaves the vhost LAN
guard as the only gate. API keys still apply to every API call; only the web
UI is unauthenticated.

Each API key is pinned by `secrets/calliope/{radarr,sonarr}.yaml`
(`api_key`), templated into the service's `*__AUTH__APIKEY` environment, so
the key Recyclarr uses can never drift from the one the service serves.

### Recyclarr

Quality profiles, custom formats, file-size limits, naming and the
propers/repacks setting come from [TRaSH Guides] via Recyclarr
(`recyclarr.nix`), which re-syncs daily and overwrites anything it manages —
change those there, not in the UIs. Two profiles each, chosen per movie or
show:

| | Profile | |
|---|---|---|
| Radarr | `HD Bluray + WEB` | 1080p, with the guide's Bluray-720p fallback disabled |
| Radarr | `Remux + WEB 2160p` | 4K remuxes with HD audio passthrough |
| Sonarr | `WEB-1080p` | 1080p WEB-DLs, season packs preferred |
| Sonarr | `WEB-2160p` | 4K WEB-DLs, for HDR |

Opt-ins (no Dolby Vision on any TV, HDR10+ yes, HD audio passthrough,
private trackers only) are commented in the module. `trash_ids` come from
the TRaSH-Guides repo's `docs/json/{radarr,sonarr}/`. Instance names must be
unique across both services or the sync silently does nothing.

```bash
sudo systemctl start recyclarr      # sync now
journalctl -u recyclarr             # read the result
```

## Plex

The one service clients reach directly: `openFirewall` exposes 32400 plus
the GDM/DLNA discovery ports to the LAN, and remote streaming goes through
plex.tv relay / NAT traversal rather than port 443. Runs in the `media`
group for read access to the library tree.

## Seerr

Media requests for Plex users, and the one deliberately public service.
Runs as a `DynamicUser` sandbox and talks to Plex, Radarr and Sonarr over
localhost HTTP, so it needs no media group and no mounts.

## Immich

Photo and video backup for the phones, deliberately **LAN-only**: the mobile
apps queue new photos while away and upload automatically on home wifi, and
exposing it would put the family archive's auth surface on the WAN (a
Cloudflare proxy would also cap uploads at 100 MB, breaking video backup).
Never give it a public vhost.

- The store is `/srv/photos/immich`, **not** the dataset root: the module
  tmpfiles-enforces `immich:immich 0700` on `mediaLocation`, which would
  fight zfs.nix's `2775 luke media` rule at `/srv/photos`. Keep its
  `RequiresMountsFor = /srv/photos` — without it the module recreates the
  store on the bare NVMe when the pool fails to import.
- Don't hand-arrange files in the store; Immich owns the layout. Uploads are
  checksummed so re-imports dedupe. One-off dumps (iCloud takeout) go in
  `/srv/photos/archive` for import with `immich-cli`.
- The module runs its own postgres (vectorchord) and redis on unix sockets.
  Machine learning runs CPU-only.
- Accounts (one per person; the admin is created on first visit) live in its
  UI, not this repo.
- It binds `127.0.0.1` explicitly: the module default `localhost` resolves
  to `::1` under node, and Caddy proxies to v4 loopback.
- This nixpkgs ships Immich 2.7.5, EOL and marked insecure, so `immich.nix`
  carries a `permittedInsecurePackages` permit. See
  [Operations › Pinned overrides](operations.md#pinned-overrides) for when
  to drop it.

[TRaSH Guides]: https://trash-guides.info
