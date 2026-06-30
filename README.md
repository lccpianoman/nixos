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

## Rebuilding

The `rebuild` script handles diffing, building, committing, and pushing in one step.

```bash
# Switch to a new configuration immediately
./rebuild

# Rebuild a specific host
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

## Weather widget

The weather module uses `hosts/nixnotdix/assets/weather/main.py`, called by Waybar every 30 minutes.

API key sources (either works):
- `OPENWEATHER_API_KEY` environment variable
- `~/.config/openweathermap/api_key` (used by the Waybar wrapper script)
