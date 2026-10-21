# nixos config (agent notes)

## Source of truth
- `README.md` is the human/operational source of truth.
- This file is for agent instructions and quick repo context.
- If they drift, trust `README.md` and update this file.

## Hosts
| Host | Role |
|---|---|
| `nixnotdix` | Gaming/dev workstation (Sway, NVIDIA, Zen kernel) |
| `nixvps` | Linode VPS (Vaultwarden behind Caddy) |
| `nixcraft` | Vultr VPS (Minecraft server) |
| `calliope` | Dell R730xd home file server (fibre-only, patched ixgbe, 12-disk raidz2 `storage` pool, media stack behind Caddy — see README "Media services") |

## Repo layout (high-level)
```text
flake.nix
flake.lock
rebuild
common/
  default.nix
  server-base.nix
  identity.nix
hosts/
  nixnotdix/
  nixvps/
  nixcraft/
  calliope/
keys/
  luke-nixnotdix.pub
  nixvps.host.pub
  nixcraft.host.pub
  calliope.host.pub
secrets/
.sops.yaml
```

## Keys and secrets
- `keys/` is public keys only — safe to commit, safe to publish.
- Private keys never leave the machine that generated them; servers pull this
  repo over HTTPS, so they hold no key.
- Secrets are sops-nix encrypted under `secrets/`, decrypted at activation with
  each host's SSH host key. Recipients live in `.sops.yaml`.
- Never write a plaintext secret into the repo, and never `cat` one into a
  transcript. Pipe host → `sops` directly.
- `.githooks/pre-commit` blocks unencrypted files under `secrets/`. Enable with
  `just hooks`. Never bypass it with `--no-verify`.

## Hard rules
- Never run `./rebuild` or `nix flake update` in automation; Luke runs those manually.
- After any Luke-run `nix flake update`, re-check pin removal conditions and report.
- No Nix formatter, on purpose — don't run `nix fmt` and don't re-add a
  `formatter` output. `nixfmt` collapses the aligned `=` blocks this repo uses
  and rewrites 18 of 30 files for zero change in output. Match local style by
  hand; see README's Checks section.
- Never add calliope's twelve SAS disks to `hosts/calliope/disko.nix`, and never
  describe the `storage` pool declaratively. That file covering only the boot
  NVMe is what makes `disko --mode destroy,format,mount` unable to wipe 82 TiB
  of data. The pool is created by hand — see README's "Storage pool".

## Active pins to re-check after flake updates
| Pin | Where | Remove when |
|---|---|---|
| NVIDIA `595.99.02` | `hosts/nixnotdix/configuration.nix` (`hardware.nvidia.package`) | nixpkgs `nvidiaPackages.stable >= 595.99.02` |
| CloneHero `1.1.0.6142` | `hosts/nixnotdix/configuration.nix` overlay + `hosts/nixnotdix/pkgs/clonehero.nix` | nixpkgs `clonehero >= 1.1.0.6142` |
| ixgbe BiDi SFP patch | `hosts/calliope/ixgbe-bidi.{nix,patch}` | upstream `ixgbe` accepts 1000BASE-BX modules whose SFF-8472 byte 6 is blank (currently it requires the `BASEBX10` bit *and* `bitrate_nominal == 0xD`) |

Check with:
```bash
nix eval --impure --expr 'let f = builtins.getFlake (toString ./.); p = f.inputs.nixpkgs.legacyPackages.x86_64-linux; in { nvidia = p.linuxPackages_zen.nvidiaPackages.stable.version; clonehero = p.clonehero.version; }'
```

## Notes
- `rebuild` only applies to the local host where it runs.
- `flake.nix` has a second nixpkgs input, `nixpkgs-unstable`, feeding exactly
  one overlay: `claude-code` on `nixnotdix`. Keep it to that one package —
  pulling anything else from unstable mixes two channels' stdenv into one
  closure. It is `import`ed with `prev.config` rather than read from
  `legacyPackages` because `claude-code` is unfree and `legacyPackages` carries
  its own config. See README's "The unstable input".
- `nixnotdix` uses home-manager; `nixvps`, `nixcraft` and `calliope` are
  NixOS-only.
- `calliope`'s media services (`hosts/calliope/{caddy,plex,qbittorrent,
  prowlarr,radarr,sonarr,seerr,dashboard}.nix`) are localhost-only behind
  Caddy except Plex; the Caddy vhosts other than request.jukeluke.com carry a
  `remote_ip` LAN guard that must never be removed, because 80/443 are
  forwarded from the router. qBittorrent's `qBittorrent.conf` is fully
  declarative (rewritten every start) and only that service is routed through
  the `wg-qb` tunnel, by a `uidrange` policy rule plus a per-uid kill switch —
  details in README's "Media services". Do not "simplify" that to an fwmark
  set in `mangle OUTPUT`: a mark lands after `connect()` has already pinned
  the socket's source address, so the reroute is refused and everything not
  explicitly bound to `wg-qb` (DNS especially) silently falls back to `eno1`
  and gets rejected. That bug was shipped once already.
- The kill switch MUST keep its `-m mark --mark` ACCEPT for WireGuard's own
  encrypted output. qBittorrent's packets cross OUTPUT twice (plaintext to
  wg-qb, then the encrypted outer packet out eno1), and WireGuard does not
  orphan the skb, so the outer packet still carries uid 996. Without the
  exemption the kill switch strangles the tunnel: nothing reaches the VPN
  while `wg show` looks perfectly healthy. Diagnose with
  `sudo iptables -L OUTPUT -nvx | grep 996` — exactly equal ACCEPT and REJECT
  counters mean the outer packets are being killed.
- `secrets/calliope/wg-qb.conf` MUST carry `Table = off` and MUST NOT carry a
  `DNS =` line. Without the first, `AllowedIPs = 0.0.0.0/0` gives wg-quick a
  host-wide default route that moves every service onto the VPN and breaks
  inbound Seerr via asymmetric routing; the second makes wg-quick run
  `resolvconf -x` and replace the whole host's resolvers. Never "fix" a
  qBittorrent connectivity problem by restoring either one.
- `caddy.nix` on calliope pins a `withPlugins` vendor hash; a flake update
  that moves Caddy or the cloudflare plugin fails the build with the
  replacement hash in the error. The two `secrets/calliope/*` files were
  committed as encrypted REPLACE_ME placeholders; Luke fills them with `sops`.
- `calliope` is fibre-only and its link depends on the `ixgbe` kernel patch.
  If that patch stops applying the host boots with no network and needs a
  physical console, so never "fix" a patch conflict by dropping the patch.
  The copper i350 ports are left unconfigured on purpose: a second interface on
  the same subnet gives two default routes and reverse-path-filtered replies.
- `calliope`'s `storage` datasets are `mountpoint=legacy` and mounted from
  `hosts/calliope/zfs.nix`, not by `zfs-mount.service`: `systemd.targets.zfs` is
  only `wantedBy` multi-user.target, never ordered before it, so ZFS-native
  mounts race the services reading them. Keep new datasets in `fileSystems`, and
  keep `nofail` on them — an unimportable pool must never hold up this host's
  boot. Services that read the pool get `RequiresMountsFor` instead.
- `calliope` builds a patched kernel, so ZFS builds its module against it from
  source — a `nix flake update` that moves the LTS kernel past what the packaged
  ZFS supports fails the build. Check `boot.kernelPackages.kernel.version`
  against `pkgs.zfs` before assuming a kernel bump is safe.
- Firefox theming lives in `hosts/nixnotdix/home/firefox.nix` + `home/firefox/`.
  The CSS files carry at-delimited placeholders substituted from `theme.nix` —
  never hard-code a colour in them. One store-written `file://` document is both
  the homepage and the new tab page: `home/firefox/newtab.cfg` is an autoconfig
  script (appended to the wrapper's `mozilla.cfg` via `extraPrefsFiles`) that
  reads the `nixos.newtab.url` pref and assigns `AboutNewTab.newTabURL`. Firefox
  blanks the URL bar for any URL equal to that one (`isInitialPage` in
  `browser.js`), which is the whole point — keep the two prefs identical.
  `extraPrefsFiles` entries must be derivations, not bare paths: the wrapper
  splices them with `toString`, which strips the string context a path needs to
  become a build input.
