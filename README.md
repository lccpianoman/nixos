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
| `nixvps.host.pub`, `nixcraft.host.pub` | Server host keys, pinned as `programs.ssh.knownHosts` on nixnotdix and used as sops recipients |
| `calliope.host.pub` | calliope's host key, pinned as `knownHosts` on nixnotdix. Not yet a sops recipient — calliope holds no secrets |

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

## `calliope`

Home file server on a Dell PowerEdge R720xd. Named hosts are `nixnotdix`'s
knownHosts pin plus an ssh alias, so `ssh calliope` works from the workstation.

- 2× Xeon E5-2690 v4 (56 threads), 236 GB RAM
- Samsung 970 EVO Plus 500 GB NVMe — OS only, wiped and managed by disko
- 12× 10 TB SAS (HUH721010AL4200) behind an LSI SAS3008 HBA
- Static `192.168.0.10` on `eno1`, SSH on port `47291`

The twelve SAS disks carry an existing ZFS pool named `storage`, left over from
the Proxmox install that the NVMe replaced. It is **not** imported or referenced
anywhere in this config yet. `networking.hostId` is already set so adopting it
later is a single change rather than a rebuild-and-reboot; the first import will
still need `-f`, because the pool was last touched under a different hostId.

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
