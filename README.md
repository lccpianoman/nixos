# nixos

NixOS flake managing two machines. Pinned to `nixos-26.05` with `home-manager release-26.05`.

## Hosts

| Host | Role | Hardware |
|---|---|---|
| `nixnotdix` | Gaming / dev workstation | x86_64, NVIDIA, Zen kernel |
| `nixvps` | Linode VPS | x86_64, QEMU/KVM |

## Desktop (nixnotdix)

- **WM:** BSPWM + sxhkd
- **Bar:** Polybar (weather, workspaces, clock)
- **Launcher:** Rofi
- **Terminal:** Alacritty
- **Theme:** Tokyo Night throughout

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
hosts/
  nixnotdix/          # workstation — system + home-manager config
    pkgs/             # local package overrides
    assets/           # wallpapers, polybar weather script
  nixvps/             # VPS — system config only
keys/
  luke.pub            # SSH public key, referenced by host configs
```

## Weather widget

Requires an [OpenWeatherMap](https://openweathermap.org/api) API key exported as `OPENWEATHER_API_KEY`.
