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
  luke-nixnotdix.pub
  nixvps.host.pub
  nixcraft.host.pub
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
| `nixvps.host.pub`, `nixcraft.host.pub` | Server host keys, pinned as `programs.ssh.knownHosts` on nixnotdix and used as sops recipients |

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
just check-sway   # validates nixnotdix's generated sway config against swayfx
nix run nixpkgs#shellcheck -- ./rebuild
nix run nixpkgs#ruff -- check hosts/nixnotdix/assets/weather/main.py
nix fmt
```

## Weather widget

Waybar runs `hosts/nixnotdix/assets/weather/main.py` every 30 minutes.

API key sources:
- `OPENWEATHER_API_KEY`
- `~/.config/openweathermap/api_key`
