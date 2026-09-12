# nixos

NixOS flake for three machines, pinned to `nixos-26.05` with `home-manager release-26.05`.

## Hosts

| Host | Role | Hardware |
|---|---|---|
| `nixnotdix` | Gaming/dev workstation | x86_64, NVIDIA, Zen kernel |
| `nixvps` | Linode VPS | x86_64, QEMU/KVM |
| `nixcraft` | Vultr VPS for Minecraft | x86_64, QEMU/KVM, 8 GB / 3 vCPU |

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
keys/
  luke.pub
```

## `nixnotdix`

Desktop stack:
- Sway
- greetd + tuigreet
- Waybar
- Fuzzel
- Mako
- swayidle + swaylock
- Alacritty

Theme: Kanagawa Wave.

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

Vaultwarden secrets live in `/var/lib/vaultwarden/vaultwarden.env`.

### Backups

Vaultwarden is backed up nightly at 03:00 to `b2:jukeluke-vaultwarden-backup:`.
Retention is 7 daily, 4 weekly, 6 monthly snapshots.

The backup includes:
- the SQLite database, captured with `sqlite3 .backup`
- attachments
- sends
- RSA keys
- `vaultwarden.env`

Restic secrets are stored on the host:
- `/var/lib/restic/b2.env`
- `/var/lib/restic/password`

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

## Updating

Run `nix flake update` roughly monthly or after security fixes, then rebuild each host.

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
nix run nixpkgs#shellcheck -- ./rebuild
nix run nixpkgs#ruff -- check hosts/nixnotdix/assets/weather/main.py
nix fmt
```

## Weather widget

Waybar runs `hosts/nixnotdix/assets/weather/main.py` every 30 minutes.

API key sources:
- `OPENWEATHER_API_KEY`
- `~/.config/openweathermap/api_key`
