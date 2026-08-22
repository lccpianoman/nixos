# nixos

NixOS flake managing three machines. Pinned to `nixos-26.05` with `home-manager release-26.05`.

## Hosts

| Host | Role | Hardware |
|---|---|---|
| `nixnotdix` | Gaming / dev workstation | x86_64, NVIDIA, Zen kernel |
| `nixvps` | Linode VPS | x86_64, QEMU/KVM |
| `nixcraft` | Vultr VPS — Minecraft server | x86_64, QEMU/KVM, 8 GB / 3 vCPU |

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

## Minecraft (nixcraft)

Fabric server for Minecraft **26.2**, managed by the
[`nix-minecraft`](https://github.com/Infinidoge/nix-minecraft) flake as
`services.minecraft-servers.servers.survival`.

- **Address:** `mc.jukeluke.com:25565` (A record must be **DNS-only** — Cloudflare's
  free proxy does not forward the Minecraft TCP protocol).
- **Data:** `/srv/minecraft/survival`
- **Heap:** 6 GB of the 8 GB box, Aikar's G1GC flags. The remainder is deliberately
  left to the OS page cache and the JVM's off-heap use.
- **Whitelist:** on and declarative — edit `whitelist` in
  `hosts/nixcraft/minecraft.nix`, then rebuild. Changes made in-game with
  `/whitelist add` are overwritten on the next rebuild.
- **Mods:** pinned by URL + SHA-512 in `hosts/nixcraft/minecraft.nix`
  (Fabric API, Lithium, FerriteCore, Krypton, ServerCore, spark).

Every mod must match the Minecraft version — a stale jar is the usual reason the
server refuses to start after a version bump. To add or update one, copy the
version ID from its Modrinth page and run:

```bash
nix run github:Infinidoge/nix-minecraft#nix-modrinth-prefetch -- <versionId>
```

That prints a ready-to-paste `fetchurl` block.

### Server console

The server runs inside a tmux session; `luke` is in the `minecraft` group and can
attach without sudo:

```bash
tmux -S /run/minecraft/survival.sock attach   # Ctrl+b then d to detach
```

Do **not** stop the server with `/stop` from the console — `Restart=always` will
just bring it straight back up. Use `systemctl stop minecraft-server-survival`.

### World backups

Local snapshots only, nightly at 04:00 (`minecraft-backup-survival.timer`) into
`/var/backup/minecraft`, keeping 14 days. The job issues `save-off` +
`save-all flush` before reading the world so the archive can't catch a
half-written region file, and restores saving via an `EXIT` trap even if the
backup fails.

> These snapshots live on the same disk as the world. They cover griefing, a bad
> command, or a corrupt chunk — **not** loss of the VPS itself. If the world
> becomes worth keeping, add an offsite restic target mirroring the Vaultwarden
> setup above.

To restore:

```bash
systemctl stop minecraft-server-survival
cd /srv/minecraft/survival
tar --use-compress-program=unzstd -xf /var/backup/minecraft/survival-<stamp>.tar.zst
chown -R minecraft:minecraft /srv/minecraft/survival
systemctl start minecraft-server-survival
```

## Deploying a new VPS (nixos-anywhere)

`nixcraft` was installed with [`nixos-anywhere`](https://github.com/nix-community/nixos-anywhere),
which kexecs a NixOS installer over whatever OS the provider gave us, partitions
the disk per `hosts/<host>/disko.nix`, and installs the flake config — no manual
ISO or installer session. The provider's initial distro is scratch and gets
wiped, so any Linux image with SSH will do.

1. **Create the instance.** Vultr → Deploy, pick the plan, choose **Debian 12**,
   and attach your SSH key at creation time. Note the public IP.
2. **Check the disk and networking** before wiping anything — `disko.nix` assumes
   the disk is `/dev/vda`, and the NixOS config expects DHCP:

   ```bash
   ssh root@<IP> 'lsblk; ip -4 addr show; ip route; [ -d /sys/firmware/efi ] && echo BOOT=UEFI || echo BOOT=BIOS'
   ```

   The system disk must show as `vda` (if it is `sda`, change `device` in
   `hosts/nixcraft/disko.nix`), and the boot mode must be **UEFI** —
   `disko.nix` creates an EFI System Partition and GRUB is configured with
   `efiSupport`. A BIOS-only host would need an EF02 `bios_grub` layout instead.
3. **Stage the password hash.** This repo is public, so `luke`'s password hash is
   never committed — it is copied in at install time instead. Without it there is
   no sudo and no console login, i.e. no way back in if SSH breaks.

   ```bash
   mkdir -p /tmp/nixcraft-files/etc/nixos-secrets
   mkpasswd -m yescrypt > /tmp/nixcraft-files/etc/nixos-secrets/luke.hashedPassword
   chmod 600 /tmp/nixcraft-files/etc/nixos-secrets/luke.hashedPassword
   ```

   (`mkpasswd` comes from `nix shell nixpkgs#mkpasswd` if it isn't on PATH.)
4. **Point DNS** at the IP. For Minecraft the record must be grey-cloud / DNS-only.
5. **Install.** This wipes the disk; the host reboots into NixOS when it finishes:

   ```bash
   nix run github:nix-community/nixos-anywhere -- \
     --flake .#nixcraft \
     --extra-files /tmp/nixcraft-files \
     root@<IP>
   ```

6. **Verify**, noting SSH has moved to port 47291 and root login is disabled. The
   host key changed, so clear the old entry first:

   ```bash
   ssh-keygen -R '[<IP>]:47291'
   ssh -p 47291 luke@<IP>

   # on the host
   sudo -v                                     # password from step 3
   systemctl status minecraft-server-survival
   tmux -S /run/minecraft/survival.sock attach # Ctrl+b then d to detach
   ```

7. **Clean up** the staged hash on your workstation: `rm -rf /tmp/nixcraft-files`.

Afterwards the `rebuild` script does not apply — it activates locally only. Deploy
changes by SSHing in, pulling the repo, and running `nixos-rebuild switch --flake .#nixcraft`.

### If the VM boots to a UEFI shell

`UEFI Interactive Shell v2.2` with a `Mapping table` means the firmware found no
bootable EFI application. Check the partition sizes it lists: a 1 MiB partition 1
is an EF02 `bios_grub` layout, which UEFI firmware ignores completely. The disk
needs an EF00 ESP instead — see `hosts/nixcraft/disko.nix`.

There is no way to boot the installed system from that shell (it cannot read
ext4), so recovery is: reinstall the provider's stock distro from the panel — on
Vultr this keeps the same instance and IP — then re-run `nixos-anywhere` with the
corrected layout.

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
  nixcraft/           # Minecraft VPS — system config + disko layout
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
