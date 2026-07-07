# nixos

NixOS flake managing two machines. Pinned to `nixos-26.05` with `home-manager release-26.05`.

## Hosts

| Host | Role | Hardware |
|---|---|---|
| `nixnotdix` | Gaming / dev workstation | x86_64, NVIDIA, Zen kernel |
| `nixvps` | Linode VPS | x86_64, QEMU/KVM |

## Desktop (nixnotdix)

- **WM:** Sway
- **Display manager:** greetd + tuigreet
- **Bar:** Waybar (weather, workspaces, clock)
- **Launcher:** Fuzzel
- **Notifications:** Mako
- **Terminal:** Alacritty
- **Theme:** Kanagawa Wave throughout

## Services (nixvps)

- **Vaultwarden** — self-hosted Bitwarden, SQLite backend, signups disabled.
- **Caddy** — reverse proxy with automatic HTTPS for `vault.jukeluke.com` → `localhost:8222`.
- **Hardening** — root SSH disabled, password auth off, fail2ban (escalating bans), SSH limited to `luke` on port 47291.

Vaultwarden secrets live in `/var/lib/vaultwarden/vaultwarden.env` on the host and are never committed.

## Backups (nixvps)

Restic backs up Vaultwarden nightly (03:00, `restic-backups-vaultwarden.timer`) to
the Backblaze B2 bucket `jukeluke-vaultwarden-backup`, encrypted client-side.
Retention: 7 daily, 4 weekly, 6 monthly snapshots.

What's included: a consistent SQLite snapshot (taken with `sqlite3 .backup` into
`/var/backup/vaultwarden/`), attachments, sends, RSA keys, and `vaultwarden.env`.
The icon cache is excluded (regenerable).

Secrets on the host (never committed, back these up somewhere safe too — without
the restic password the backups are unrecoverable):

- `/var/lib/restic/b2.env` — `B2_ACCOUNT_ID` and `B2_ACCOUNT_KEY`
- `/var/lib/restic/password` — restic repository encryption password

### Restore procedure

```bash
# On the VPS: use the wrapper the NixOS module generates — it has the repo,
# B2 credentials, and password preloaded (run as root):
restic-vaultwarden snapshots
restic-vaultwarden restore latest --target /tmp/vw-restore

# On any other machine you'd need restic + the two secret files:
#   export $(cat b2.env | xargs)
#   restic -r b2:jukeluke-vaultwarden-backup: --password-file <password-file> ...

# Verify the restored DB is usable before touching production
# (no sqlite on the VPS by default — use nix-shell -p sqlite):
sqlite3 /tmp/vw-restore/var/backup/vaultwarden/db.sqlite3 "PRAGMA integrity_check;"

# Afterwards, clean up — the restore contains the real vault:
rm -rf /tmp/vw-restore

# To actually restore:
systemctl stop vaultwarden
cp -a /tmp/vw-restore/var/lib/vaultwarden/. /var/lib/vaultwarden/
cp /tmp/vw-restore/var/backup/vaultwarden/db.sqlite3 /var/lib/vaultwarden/db.sqlite3
rm -f /var/lib/vaultwarden/db.sqlite3-wal /var/lib/vaultwarden/db.sqlite3-shm
chown -R vaultwarden:vaultwarden /var/lib/vaultwarden
systemctl start vaultwarden
```

### Secret recovery

If `/var/lib/vaultwarden/vaultwarden.env` is lost, restore it from the restic
backup (it's included in every snapshot — see the restore procedure above).
`ADMIN_TOKEN` and `SMTP_PASSWORD` can also be re-issued: generate a new admin
token with `vaultwarden hash`, and rotate the SMTP password in the Migadu
admin panel. The restic secrets themselves (`/var/lib/restic/*`) are the one
thing backups can't recover — keep an offline copy of those.

## Updating

Run `nix flake update` roughly monthly (or when a security fix lands), then
`./rebuild` on each host and verify services still work. Both commands are
run by Luke directly — agents/automation must not run them.

## Rebuilding

The `rebuild` script handles diffing, building, committing, and pushing in one step.

```bash
# Switch to a new configuration immediately
./rebuild

# Rebuild a specific host (must be run on that host — the script
# refuses cross-host targets since nh activates locally)
./rebuild nixvps

# Stage the config without activating (requires reboot)
./rebuild --boot
```

## Structure

```
flake.nix
rebuild
common/               # settings shared by all hosts (nix, locale, git identity)
hosts/
  nixnotdix/          # workstation — system + home-manager config
    pkgs/             # local package overrides
    assets/           # wallpapers, waybar weather script
  nixvps/             # VPS — system config only
keys/
  luke.pub            # SSH public key, referenced by host configs
```

`keys/luke.pub` is an Ed25519 key, fingerprint
`SHA256:I2WnzZlRNdb9hLOEFSI9tnSDzc+fJUa/QILohFJiAp0` (`luke@nixnotdix`).

## Checks

CI (GitHub Actions) runs these on every push; to run them locally:

```bash
nix flake check --no-build --no-write-lock-file   # evaluate both hosts
nix run nixpkgs#shellcheck -- ./rebuild           # lint the rebuild script
nix run nixpkgs#ruff -- check hosts/nixnotdix/assets/weather/main.py
nix fmt                                           # format .nix files (nixfmt/treefmt)
```

## Weather widget

The weather module uses `hosts/nixnotdix/assets/weather/main.py`, called by Waybar every 30 minutes.

API key sources (either works):
- `OPENWEATHER_API_KEY` environment variable
- `~/.config/openweathermap/api_key` (used by the Waybar wrapper script)
