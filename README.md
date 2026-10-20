# nixos

NixOS flake for four machines, pinned to `nixos-26.05` with `home-manager release-26.05`.

## Hosts

| Host | Role | Hardware |
|---|---|---|
| `nixnotdix` | Gaming/dev workstation | x86_64, NVIDIA, Zen kernel |
| `nixvps` | Linode VPS | x86_64, QEMU/KVM |
| `nixcraft` | Vultr VPS for Minecraft | x86_64, QEMU/KVM, 8 GB / 3 vCPU |
| `calliope` | Home file server | Dell R720xd, 2× Xeon E5-2690 v4, 236 GB, 12× 10 TB SAS |

## Layout

```text
flake.nix
rebuild
AGENTS.md
common/
  default.nix
  server-base.nix
  identity.nix
hosts/
  nixnotdix/
    configuration.nix
    hardware-configuration.nix
    home.nix
    home/
    assets/
    pkgs/
  nixvps/
    configuration.nix
    hardware-configuration.nix
  nixcraft/
    configuration.nix
    hardware-configuration.nix
    disko.nix
    minecraft.nix
    minecraft/
  calliope/
    configuration.nix
    hardware-configuration.nix
    disko.nix
    ixgbe-bidi.nix
    ixgbe-bidi.patch
    zfs.nix
    nfs.nix
keys/
  luke-nixnotdix.pub
  nixvps.host.pub
  nixcraft.host.pub
  calliope.host.pub
secrets/
  nixvps/
  nixcraft/
.sops.yaml
```

## Keys and secrets

`keys/` holds public keys only, and everything in it is safe to publish.

| File | What it is |
|---|---|
| `luke-nixnotdix.pub` | Luke's admin key; installed into `authorized_keys` on every server by `common/server-base.nix` |
| `nixvps.host.pub`, `nixcraft.host.pub`, `calliope.host.pub` | Server host keys, pinned as `programs.ssh.knownHosts` on nixnotdix and used as sops recipients |

Private keys never leave the machine that generated them. Servers pull this
repo over HTTPS (it is public), so they need no key at all.

### Secrets

Secrets are encrypted into `secrets/` with [sops-nix] and decrypted at
activation using each host's SSH host key — no key material has to be placed on
a host by hand. Recipients are declared in `.sops.yaml`: the admin key plus the
one host that needs the secret.

| Secret | Host | Mounted at |
|---|---|---|
| `secrets/nixvps/vaultwarden.env` | nixvps | `/run/secrets/vaultwarden.env` |
| `secrets/nixvps/restic-b2.env` | nixvps | `/run/secrets/restic-b2.env` |
| `secrets/nixvps/restic-password` | nixvps | `/run/secrets/restic-password` |
| `secrets/nixcraft/users.yaml` | nixcraft | `/run/secrets-for-users/luke-hashed-password` |
| `secrets/calliope/cloudflare.env` | calliope | `/run/secrets/cloudflare.env` |
| `secrets/calliope/wg-qb.conf` | calliope | `/run/secrets/wg-qb.conf` |

Both calliope secrets were committed as encrypted `REPLACE_ME` placeholders so
the configuration evaluates before the real values exist — fill them in with
`sops` before expecting certificates or the torrent tunnel to work. See
"Media services" under calliope.

The `.env` secrets use sops' `dotenv` format, so variable *names* stay readable
in git and only values are encrypted. They are mounted whole (`key = ""`) so
systemd can consume them as `EnvironmentFile`.

Edit a secret with:

```bash
nix run nixpkgs#sops -- secrets/nixvps/vaultwarden.env
```

Adding a host means adding its `ssh-to-age` recipient to `.sops.yaml` and
running `sops updatekeys` on the affected files.

`secrets/` cannot be guarded by `.gitignore` — re-including the encrypted files
re-includes everything — so a tracked pre-commit hook rejects any staged file
under `secrets/` that `sops filestatus` does not report as encrypted. Enable it
once per clone:

```bash
just hooks          # git config core.hooksPath .githooks
just check-secrets  # same check over everything already committed
```

[sops-nix]: https://github.com/Mic92/sops-nix

## `nixnotdix`

Desktop stack:
- SwayFX (sway 1.12 fork adding blur, shadows, rounded corners, animations)
- greetd + ReGreet (GTK greeter under cage)
- Waybar
- Fuzzel
- Mako
- swayidle + swaylock-effects (blurred-screenshot lock)
- Alacritty

Theme: saturated custom nebula palette.

Key packages:
- Gaming: Steam, protontricks, gamemode, NoiseTorch, CloneHero, PrismLauncher, Lunar Client
- Dev: Claude Code CLI, GitHub Copilot CLI, VSCodium, Git, Vim
- Apps: Firefox, VLC, Vesktop, Plex Desktop, Spotify, pavucontrol
- Utilities: wl-clipboard, grimshot, btop, fastfetch, nh, tree, eza, file, killall, ttyper

## `nixvps`

Services:
- Vaultwarden on `127.0.0.1:8222`, published at `https://vault.jukeluke.com`
- Caddy reverse proxy with security headers
- Restic backups to Backblaze B2

Security:
- SSH on port `47291`
- root login disabled
- password auth disabled
- fail2ban enabled

Vaultwarden secrets are managed by sops-nix and mounted at
`/run/secrets/vaultwarden.env`. See [Secrets](#secrets).

### Backups

Vaultwarden is backed up nightly at 03:00 to `b2:jukeluke-vaultwarden-backup:`.
Retention is 7 daily, 4 weekly, 6 monthly snapshots.

The backup includes:
- the SQLite database, captured with `sqlite3 .backup`
- attachments
- sends
- RSA keys

`vaultwarden.env` is no longer in the backup set: it moved out of
`/var/lib/vaultwarden` into sops, so the encrypted copy in this repo is the
authoritative one.

Restic's own credentials are sops secrets, mounted at `/run/secrets/restic-b2.env`
and `/run/secrets/restic-password`.

### Restore

```bash
restic-vaultwarden snapshots
restic-vaultwarden restore latest --target /tmp/vw-restore
sqlite3 /tmp/vw-restore/var/backup/vaultwarden/db.sqlite3 "PRAGMA integrity_check;"

systemctl stop vaultwarden
cp -a /tmp/vw-restore/var/lib/vaultwarden/. /var/lib/vaultwarden/
cp /tmp/vw-restore/var/backup/vaultwarden/db.sqlite3 /var/lib/vaultwarden/db.sqlite3
rm -f /var/lib/vaultwarden/db.sqlite3-wal /var/lib/vaultwarden/db.sqlite3-shm
chown -R vaultwarden:vaultwarden /var/lib/vaultwarden
systemctl start vaultwarden
```

## `nixcraft`

Minecraft server for version 26.2, managed by `nix-minecraft`.

- Address: `mc.jukeluke.com:25565`
- Data directory: `/srv/minecraft/survival`
- Heap: 6 GB
- Whitelist: declarative
- Mods: pinned by URL and SHA-512 in `hosts/nixcraft/minecraft/server.nix`

Mods:
- Fabric API
- Carpet
- Carpet Extra
- Carpet TIS Addition
- Servux
- Lithium
- FerriteCore
- Krypton
- spark

### Server console

The server runs in a tmux session:

```bash
tmux -S /run/minecraft/survival.sock attach
```

Use `systemctl stop minecraft-server-survival` to stop it.

### World backups

Local snapshots run nightly at 04:00 into `/var/backup/minecraft`, keeping 14 days.
The backup pauses saves before archiving and restores them afterward.

### Deployment

`nixcraft` was installed with `nixos-anywhere`.

Requirements:
- disk on `/dev/vda`
- UEFI boot
- SSH key attached at provider install time

Install command:

```bash
nix run github:nix-community/nixos-anywhere -- \
  --flake .#nixcraft \
  --extra-files /tmp/nixcraft-files \
  root@<IP>
```

`--extra-files` must seed the host's SSH host key at
`/tmp/nixcraft-files/etc/ssh/ssh_host_ed25519_key` (mode `0600`, plus the
`.pub`). sops decrypts with that key, so without it the first activation cannot
unlock any secret — and a freshly generated key would not match the recipient in
`.sops.yaml`. Seeding it also keeps `keys/nixcraft.host.pub` valid across a
reinstall, so the `knownHosts` pin does not break.

## `calliope`

Home file server on a Dell PowerEdge R720xd. Named hosts are `nixnotdix`'s
knownHosts pin plus an ssh alias, so `ssh calliope` works from the workstation.

- 2× Xeon E5-2690 v4 (56 threads), 236 GB RAM
- Samsung 970 EVO Plus 500 GB NVMe — OS only, wiped and managed by disko
- 12× 10 TB SAS (HUH721010AL4200) behind an LSI SAS3008 HBA
- Static `192.168.0.10` on `eno1`, SSH on port `47291`

The twelve SAS disks carry the `storage` ZFS pool — see "Storage pool" below.
`networking.hostId` was set before the pool was built, so it is stamped with
calliope's own id and imports without `-f`.

Claude Code and the GitHub Copilot CLI are installed here too, so this repo can
be edited on the server. Pushing uses `git@github.com:lccpianoman/nixos.git` over
an `~/.ssh/id_ed25519` keypair generated on calliope — the private key never
leaves the host, and the public half is a write-enabled deploy key on the GitHub
repo, not a file in `keys/` (which is only for admin SSH access to the servers).

### Network

Fibre-only, by design — see the comment block in `configuration.nix`. The copper
i350 ports are deliberately unconfigured, so recovery from a dead link is the
physical console.

The router (CenturyLink) must not hand `192.168.0.10` to anything else. Move the
DHCP pool start to `192.168.0.100` under Advanced Setup → DHCP Settings, or add a
reservation binding `ec:f4:bb:c8:8d:78` to `192.168.0.10`.

### Fibre link

`eno1` runs over a pair of 10Gtek 1000BASE-BX BiDi SFPs (`GLC-BX-U`/`-D`,
1310/1550 nm, single-strand). Stock `ixgbe` refuses them and the port never gets
a netdev at all, which on a fibre-only host means an unreachable machine.

The cause is not missing BiDi support — the driver has it. These modules leave
SFF-8472 byte 6 blank, so the `IXGBE_SFF_BASEBX10_CAPABLE` bit the driver keys on
is simply absent. `hosts/calliope/ixgbe-bidi.nix` carries the full analysis and
the three-line patch that relaxes the check.

`allow_unsupported_sfp` does **not** fix this on its own; it guards a different
check in the same function. It is set anyway as a belt-and-braces measure.

Inspect the optics with:

```bash
ethtool -m eno1        # EEPROM, wavelength, TX/RX optical power, temperature
ethtool eno1           # negotiated speed/duplex
```

Hot-swapping an SFP can trip an upstream `ixgbe` bug: the runtime detection path
reads the EEPROM before the module has powered up, gets a bad identifier byte,
and calls `unregister_netdev()` — the interface vanishes. Worse, the probe-error
path leaks its `mdio_bus` sysfs node, which survives `rmmod` and blocks the port
until reboot. **Reboot after changing optics rather than relying on hot-plug.**

### Storage pool

The twelve SAS disks are one `raidz2` vdev named `storage`: 82.4 TiB usable,
surviving any two failures. A single wide vdev rather than two 6-disk vdevs
because the SFPs negotiate 1 Gbps, so the wire caps at ~113 MB/s and one raidz2
vdev already does 600–900 MB/s sequential — splitting it would buy random IOPS
nothing here can spend and cost 18 TiB. All twelve bays are full and the chassis
has no more, so there is no second-vdev expansion path to preserve either.

The cost of a wide vdev is resilver time: rebuilding one 9 TiB disk reads every
other disk in the vdev and runs for most of a day, at one parity. That is the
right trade for replaceable media, and the wrong one for anything irreplaceable
— for that the answer is `storage/documents` plus an offsite copy, not more
parity. **The pool is not a backup.**

`hosts/calliope/zfs.nix` carries the NixOS side: mounts, permissions, scrub,
ZED and snapshot policy. The pool and datasets themselves are created by hand,
because `hosts/calliope/disko.nix` deliberately describes only the boot NVMe —
that is what makes a `disko --mode destroy,format,mount` run unable to reach
these twelve disks, and it is worth more as a standing guarantee than as a
convenience used once.

| Dataset | Mount | `recordsize` | `compression` | Why |
|---|---|---|---|---|
| `storage/media` | `/srv/media` | 1M | lz4 | Large sequential files. Holds both `library/` and `downloads/` — see below |
| `storage/photos` | `/srv/photos` | 1M | lz4 | Write-once originals; a file below `recordsize` still uses one right-sized record, so thumbnails waste nothing |
| `storage/documents` | `/srv/documents` | 128K | zstd | Small, compressible, rewritten in place |
| `storage/backups` | `/srv/backups` | 1M | off | restic/borg output is already compressed and encrypted; lz4 would only burn CPU |

`downloads/` is a **directory inside** `storage/media`, not its own dataset.
Hardlinks and atomic renames cannot cross a ZFS dataset boundary, so splitting
them would turn every import into a full file copy and make seeding cost double
the space. The price is that snapshots of `storage/media` also pin deleted
partial downloads until they age out.

#### Creating it (one-time, destroys everything on the twelve disks)

Order matters, and the first rebuild **fails on purpose**. ZFS arrives with that
rebuild, so it cannot be present when the config that wants the pool is first
activated. Read step 1 before running it.

```bash
# 1. Rebuild. This installs ZFS, and then exits 4 with
#    "the following units failed: zfs-import-storage.service" — the pool does
#    not exist yet, so the import cannot succeed and the four /srv mounts never
#    start. Expected. Two consequences:
#      - ./rebuild stops before its commit. Nothing is stranded.
#      - the system profile is NOT advanced. DO NOT REBOOT until step 9, or the
#        machine comes back on the pre-ZFS generation.
./rebuild

# 2. Load the ZFS module by hand. modprobe resolves against
#    /run/booted-system/kernel-modules, which predates ZFS; the module built by
#    step 1 is in the *current* system's tree. The kernel binary is the same
#    store path in both, so the module is ABI-correct for the running kernel.
sudo -i
modprobe -d /run/current-system/kernel-modules zfs
cat /sys/module/zfs/version          # expect the version pkgs.zfs reports

# 3. Collect the twelve disks by model, never by /dev/sd*. This cannot catch
#    the NVMe or the USB chainloader stick, and survives a disk swap.
mapfile -t disks < <(
  for d in /dev/disk/by-id/wwn-0x*; do
    case "$d" in *-part*) continue ;; esac
    [ "$(lsblk -ndo MODEL "$d")" = HUH721010AL4200 ] && echo "$d"
  done | sort
)
printf '%s\n' "${disks[@]}"; echo "count: ${#disks[@]}"   # must say 12

# 4. Destroy the old pool. It was built on another machine, so it needs -f, and
#    -N keeps it from mounting anything on the way through.
zpool import                       # note the old pool's name and id
zpool import -f -N <oldname>
zpool destroy <oldname>

# 5. Clear the old labels and the TrueNAS-era 2 G swap partitions.
for d in "${disks[@]}"; do
  for p in "$d"-part*; do
    [ -e "$p" ] && { zpool labelclear -f "$p" || true; wipefs -a "$p"; }
  done
  sgdisk --zap-all "$d"
done
udevadm settle

# 6. Create the pool. ashift=12 is forced anyway (these disks are 4Kn:
#    PHY-SEC and LOG-SEC are both 4096) but is stated so it cannot be guessed
#    wrong on a future replacement disk that reports 512e.
zpool create \
  -o ashift=12 -o autoexpand=on \
  -O compression=lz4 -O atime=off -O xattr=sa -O acltype=posixacl \
  -O dnodesize=auto -O canmount=off -O mountpoint=none \
  storage raidz2 "${disks[@]}"

# 7. Datasets. mountpoint=legacy because they are mounted from zfs.nix, not by
#    zfs-mount.service — see the comment there for why that ordering matters.
zfs create -o mountpoint=legacy -o recordsize=1M                      storage/media
zfs create -o mountpoint=legacy -o recordsize=1M                      storage/photos
zfs create -o mountpoint=legacy -o recordsize=128K -o compression=zstd storage/documents
zfs create -o mountpoint=legacy -o recordsize=1M   -o compression=off  storage/backups

# 8. Mount them and let tmpfiles build the directory tree. Not
#    `systemctl restart systemd-tmpfiles-setup.service` — that unit sets
#    RefuseManualStart and will decline.
systemctl start srv-media.mount srv-photos.mount srv-documents.mount srv-backups.mount
systemd-tmpfiles --create

# 9. Check.
zpool status storage
zpool list -o name,size,alloc,free,cap,health
zfs list -o name,used,avail,recordsize,compression,mountpoint
ls -la /srv/media
exportfs -ra && exportfs -v          # /srv/media appears only once mounted
exit                                  # done as root

# 10. Rebuild again. This is the run that matters: with the pool present
#     zfs-import-storage succeeds, the mounts come up, it exits 0, and the
#     generation finally lands in the profile and the bootloader. Only now is
#     it safe to reboot.
./rebuild
systemctl --failed                    # expect none
```

#### Sharing

`/srv/media` is exported over **NFSv4 only** (`hosts/calliope/nfs.nix`), which
is why the firewall needs a single port: v3 drags in `mountd`, `statd` and
`lockd` on ports that wander unless each one is pinned. nixnotdix is the only
client and mounts it at `/mnt/media` via `x-systemd.automount`, so the
workstation boots fine when calliope is asleep and mounts on first access.

NFS AUTH_SYS trusts whatever uid the client sends, so the export is only as
safe as the LAN — hence the `192.168.0.0/24` restriction and `root_squash`.
It also means **both hosts must agree on numeric ids**: `luke` is pinned to
uid 1000 and the shared `media` group to gid 3000 in both configurations. They
were already those values; pinning them stops a future user from shifting one
host's allocation and silently breaking writes. The library directories are
`2775 luke:media` so that luke and the service users can share one tree.

The export carries `mountpoint`, which is the required companion to the
`nofail` mounts: without it a pool that failed to import would leave nfsd
exporting the bare directory on the root NVMe, and clients would write into the
OS disk believing they were writing to the pool. Keep it on every export added
here.

To export another dataset, add a line to `nfs.server.exports` in
`hosts/calliope/nfs.nix` — no new ports are needed under v4.

#### Identifying a disk without SES

The R720xd backplane does not present SES through the SAS3008 —
`/sys/class/enclosure` is empty — so ZED cannot blink a failed disk and
`ZED_USE_ENCLOSURE_LEDS` is off. **Build the serial-to-bay map now, while every
disk still works**, because doing it after a failure means guessing:

```bash
lsblk -do NAME,SERIAL,MODEL          # serials
ls -l /dev/disk/by-id/wwn-0x*        # wwn -> /dev/sdX
# Then, one disk at a time, watch which bay's light comes on:
dd if=/dev/sdX of=/dev/null bs=1M status=progress
```

Record the result somewhere outside this repo — a label on the chassis is best.
Then replacing a failure is `zpool replace storage <old-wwn> <new-wwn>`.

### Media services

One module per service under `hosts/calliope/`, all localhost-only except Plex,
all reached through Caddy (`caddy.nix`) — the only module that exposes anything:

| Service | Where | Reached at |
|---|---|---|
| Seerr (requests) | `127.0.0.1:5055` | `https://request.jukeluke.com` — **public**, Cloudflare-proxied |
| homepage dashboard | `127.0.0.1:8082` | `https://dash.jukeluke.com` — LAN only |
| qBittorrent | `127.0.0.1:8090` | `https://qb.jukeluke.com` — LAN only |
| Radarr | `127.0.0.1:7878` | `https://radarr.jukeluke.com` — LAN only |
| Sonarr | `127.0.0.1:8989` | `https://sonarr.jukeluke.com` — LAN only |
| Prowlarr | `127.0.0.1:9696` | `https://prowlarr.jukeluke.com` — LAN only |
| Plex | `0.0.0.0:32400` | `http://192.168.0.10:32400/web` on the LAN; remote via plex.tv |

Ports 80/443 are forwarded from the router to calliope so Cloudflare can reach
Seerr. That forwarding is why "LAN only" cannot be left to DNS: anyone can
connect to the home IP with the right SNI, so every non-public vhost carries a
`remote_ip` guard (the socket address — unspoofable, unlike headers) and the
public vhost accepts only Cloudflare's edge ranges
(`common/cloudflare-ranges.nix`, shared with nixvps).

Certificates come from Let's Encrypt over **DNS-01** (`acme_dns cloudflare`),
because names that resolve to `192.168.0.10` can never answer an HTTP-01
challenge. That required rebuilding Caddy with the cloudflare DNS plugin
(`pkgs.caddy.withPlugins` in `caddy.nix` — the pinned `hash` fails loudly with
the replacement value whenever the plugin or Caddy moves).

Manual setup, once:

1. **Cloudflare DNS**: `request` proxied (orange cloud) to the home IP;
   `dash`, `qb`, `radarr`, `sonarr`, `prowlarr` as **unproxied** (grey) A
   records to `192.168.0.10`.
2. **API token**: create a Cloudflare token scoped to Zone → DNS → Edit on
   jukeluke.com, then `sops secrets/calliope/cloudflare.env` and replace the
   placeholder value of `CLOUDFLARE_API_TOKEN`.
3. **WireGuard tunnel**: `sops secrets/calliope/wg-qb.conf` and paste the
   TorGuard config with **two edits to `[Interface]`** — add `Table = off`
   and **delete the `DNS =` line**. Both matter, and the stock config has
   neither:
   - Without `Table = off`, `AllowedIPs = 0.0.0.0/0` makes wg-quick install
     a host-wide default route, dragging every service onto the VPN. It also
     breaks inbound Seerr: Cloudflare connects on `eno1`, and Caddy's reply
     to a public address would egress via `wg-qb` instead, so it never
     arrives. With `Table = off`, `AllowedIPs` becomes a statement about what
     the peer may carry rather than a system route, and `qbittorrent.nix`
     does the routing itself.
   - A `DNS =` line makes wg-quick run `resolvconf -x`, which replaces the
     whole box's resolvers. The provider's resolver is instead pinned for
     that one service via a private `/etc/resolv.conf`. It is *not* gated by
     `Table = off`, so the line has to go.

   Until this is real, `wg-quick-wg-qb` fails and qBittorrent (which
   `bindsTo` it) deliberately stays down.

qBittorrent — and nothing else — is routed through the tunnel by
`qbittorrent.nix`. Because the interface carries `Table = off`, it is inert
until this host puts traffic on it, which it does per-uid: an `ip rule` with
`uidrange` sends everything owned by the `qbittorrent` user to a routing table
whose only route is `wg-qb`. The uid is pinned (996) so that rule cannot
silently stop matching. A private `/etc/resolv.conf`, bound into that unit
alone, points at the VPN's resolver so tracker lookups cannot leak to the LAN
router.

Keying on the uid rather than on an fwmark set in `mangle OUTPUT` is
deliberate, and the difference is not cosmetic. A mark is applied as the
packet is transmitted, long after `connect()` has chosen a route and pinned
the socket's source address to `eno1`'s. The reroute then moves the packet to
`wg-qb` while keeping that stale source, the kernel refuses it, and it falls
back to `eno1` where the kill switch rejects it. That failed silently and
selectively: libtorrent's own sockets are explicitly bound to `wg-qb`
(`Session\Interface`) so they always had the right source and worked, while
everything unbound — DNS lookups above all — was rejected. A uid rule is
consulted during the *original* route lookup, so source selection is right
from the start, with no reroute, marking or address rewriting involved.
`MASQUERADE` on `wg-qb` is kept only as a cheap no-op safety net.

That split routing also needs the tunnel exempted from reverse-path filtering.
`networking.firewall.checkReversePath` defaults to `true`, meaning *strict*,
and packets arriving on `wg-qb` carry no mark — so NixOS's `rpfilter
--validmark` test resolves their source through the main table, finds `eno1`,
and drops them. That would kill every reply to qBittorrent's own connections,
not just inbound peers, leaving the tunnel silently useless. A conventional
full-tunnel setup never hits this because its default route points at the
interface. The exemption is a `RETURN` inserted at the head of
`nixos-fw-rpfilter`; skipping the test there is safe because WireGuard has
already authenticated every packet on that interface against the peer's key,
and strict filtering stays on `eno1` where spoofing could actually originate.

The per-uid kill switch is what makes that safe to get wrong: if the rule or
route is ever missing, those packets fall back to `eno1` and are REJECTed, so
the failure mode is an outage rather than a leak. IPv6 is REJECTed outright
for that uid, since TorGuard issues a v4-only tunnel.

That kill switch needs one exemption, and omitting it strangles the tunnel.
Every packet qBittorrent sends crosses `OUTPUT` **twice**: once as plaintext
routed to `wg-qb`, then again as the encrypted outer UDP packet addressed to
the VPN endpoint and routed out `eno1`. WireGuard does not orphan the skb in
between, so that outer packet still carries uid 996, and the kill switch
rejects the tunnel's own traffic. Nothing reaches the VPN, while root and
other users can use the tunnel perfectly — `wg show` looks entirely healthy
throughout, which makes it a genuinely confusing failure. The giveaway is that
the ACCEPT and REJECT counters stay exactly equal, because each accepted inner
packet produces one rejected outer packet:

```bash
sudo iptables -L OUTPUT -nvx | grep 996
```

The fix is `wg set wg-qb fwmark` (applied by `qbittorrent-vpn-routing`) plus a
matching `-m mark` ACCEPT ahead of the REJECT. Marking beats punching a hole
for UDP to the endpoint: it identifies WireGuard's output precisely and
survives the endpoint or port changing with a new provider config.

`torrentPort` in `qbittorrent.nix` must match the port TorGuard forwards, and
is the single place to change it — the `wg-qb` firewall hole derives from it.
Request that port as **both TCP and UDP**: BitTorrent uses TCP for the peer
wire protocol and UDP for µTP and DHT. The forward must also be issued on the
server you are actually connected to, so it has to be re-requested after
changing endpoints.

The WebUI has **no login**. `WebUI\AuthSubnetWhitelist` is set to
`127.0.0.1/32`, and since Caddy proxies from loopback and the WebUI binds
there only, every request that can reach it is exempt from authentication.
Note this is *not* `LocalHostAuth`, the option usually suggested for it —
that was removed in qBittorrent 5.x and would be silently ignored. All access
control therefore rests on the LAN guard on the `qb.jukeluke.com` vhost, and
that is a bigger grant than it appears: the WebUI can configure a program to
run on torrent completion, so reaching it means code execution as the
`qbittorrent` user, which can write the whole media library. If the LAN ever
stops being a trust boundary, put a `Password_PBKDF2` in `serverConfig` and
drop the whitelist.

Its `qBittorrent.conf` is
**fully declarative** — the module reinstalls it on every service start, so
settings changed in the WebUI options dialog revert on restart; change them in
`serverConfig` instead. Torrent state, categories and RSS live in separate
files and survive.

Radarr, Sonarr and qBittorrent share the `media` group and the one
`storage/media` dataset so imports are hardlinks, not copies — see "Storage
pool" for why `downloads/` must stay inside that dataset. Every service that
touches `/srv/media` carries `RequiresMountsFor`, which is what makes the
`nofail` ZFS mounts safe: if the pool fails to import, the services fail
individually instead of writing into the bare directory on the NVMe.

Service-level configuration (indexers, quality profiles, API keys between the
*arrs, homepage widgets) is done per service after first boot and is not in
this repo — except homepage widget API keys, which must go through
`services.homepage-dashboard.environmentFiles` (a future
`secrets/calliope/homepage.env`), never `settings`, because `settings` lands
in the world-readable store.

### Deployment

Installed by hand from the NixOS 26.05 minimal ISO — not `nixos-anywhere`.

The R720xd's firmware has no NVMe driver and cannot boot the OS disk directly.
A separate chainloader device loads `NvmExpressDxe.efi` and then chainloads
`\EFI\BOOT\BOOTX64.EFI` off the NVMe ESP. That is why
`boot.loader.efi.canTouchEfiVariables` is `false`: `bootctl` cannot register an
NVRAM entry for a disk the firmware cannot see.

Boot the installer in **UEFI** mode, get it online (temporary copper is fine),
then from a clone of this repo:

```bash
# 1. Partition, format and mount under /mnt. Targets the NVMe by-id — the
#    twelve SAS disks are not in disko.nix and cannot be touched.
nix --extra-experimental-features 'nix-command flakes' \
  run github:nix-community/disko -- \
  --mode destroy,format,mount ./hosts/calliope/disko.nix

# 2. Seed the host key that keys/calliope.host.pub came from, so the knownHosts
#    pin on nixnotdix matches from first boot. Skip this and the pin breaks.
install -d -m 0755 /mnt/etc/ssh
install -m 0600 /tmp/calliope_host_ed25519     /mnt/etc/ssh/ssh_host_ed25519_key
install -m 0644 /tmp/calliope_host_ed25519.pub /mnt/etc/ssh/ssh_host_ed25519_key.pub

# 3. Install. Prompts for a root password at the end — set one; it is the
#    console recovery path, and SSH root login is disabled regardless.
nixos-install --flake .#calliope

# 4. Give luke a password so wheel can sudo.
nixos-enter --root /mnt -c 'passwd luke'

# 5. Confirm the chainload target exists before rebooting.
ls -l /mnt/boot/EFI/BOOT/BOOTX64.EFI /mnt/boot/EFI/systemd/systemd-bootx64.efi
```

Then unplug the copper, point the chainloader at the NVMe ESP, and reboot. From
nixnotdix:

```bash
ssh calliope
```

If the host key was regenerated rather than seeded, replace
`keys/calliope.host.pub` with the new `/etc/ssh/ssh_host_ed25519_key.pub` and
rebuild nixnotdix, or the pin will reject the connection.

## Updating

Run `nix flake update` roughly monthly or after security fixes, then rebuild each host.

`calliope` carries a kernel patch pinned to the `ixgbe` source layout, so a
kernel bump can break it. After any flake update, confirm it still applies:

```bash
src=$(nix build --no-link --print-out-paths \
  '.#nixosConfigurations.calliope.pkgs.linuxPackages.kernel.src')
tar -xf "$src" --wildcards '*/drivers/net/ethernet/intel/ixgbe/ixgbe_phy.c' -O \
  >/dev/null && echo "fetched ok"
# then, from an extracted kernel tree:
patch -p1 --dry-run < hosts/calliope/ixgbe-bidi.patch
```

A failure here breaks the build loudly rather than booting calliope with no
network, which is the intended failure mode.

## Rebuild

```bash
./rebuild
./rebuild nixvps
./rebuild --boot
```

With `just`:

```bash
just rebuild
just rebuild nixvps
just boot
```

Minecraft console helper:

```bash
just minecraft
```

## Checks

```bash
nix flake check --no-build --no-write-lock-file
just check-sway   # validates nixnotdix's generated sway config against swayfx
nix run nixpkgs#shellcheck -- ./rebuild
nix run nixpkgs#ruff -- check hosts/nixnotdix/assets/weather/main.py
```

There is deliberately no Nix formatter. `nixfmt` collapses the aligned `=`
blocks in `theme.nix`, `mako.nix`, `fuzzel.nix`, `waybar.nix` and `sway.nix`,
and it cannot be told not to — a whole-tree run rewrites 18 of 30 files for no
change in output. Match the surrounding style by hand instead.

## Weather widget

Waybar runs `hosts/nixnotdix/assets/weather/main.py` every 30 minutes.

API key sources:
- `OPENWEATHER_API_KEY`
- `~/.config/openweathermap/api_key`
