# nixos config

## Overview
Multi-host NixOS flake. Pinned to `nixos-26.05` with `home-manager release-26.05`.

## Hosts
| Host | Role |
|---|---|
| `nixnotdix` | Gaming/dev workstation (Sway, Kanagawa Wave, NVIDIA, Zen kernel) |
| `nixvps` | Linode VPS (headless, SSH-only) |

## File Layout
```
flake.nix                        # entry point, nixosConfigurations for each host
flake.lock
rebuild                          # custom rebuild script (see below)
keys/
  luke.pub                       # SSH public key, referenced by host configs
hosts/nixnotdix/
  configuration.nix              # system config
  hardware-configuration.nix     # auto-generated, don't edit
  home.nix                       # home-manager root
  bash.nix                       # bash prompt (Kanagawa Wave, Nerd Font, git branch, exit code)
  fuzzel.nix                     # app launcher config
  mako.nix                       # notification daemon config
  sway.nix                       # sway WM config (outputs, keybinds, idle/lock)
  theme.nix                      # shared colors/font values
  waybar.nix                     # status bar (workspaces, weather, clock, tray)
  pkgs/
    clonehero.nix                # custom package override (v1.1.0.6142, until nixpkgs catches up)
  assets/
    wallpapers/
      purple-simple.png          # active wallpaper
      tokyo_night_1080.jpg       # alternate wallpaper
      galaxy-space.jpg           # alternate wallpaper
    weather/
      main.py                    # Waybar weather script (OpenWeatherMap + IP geolocation)
hosts/nixvps/
  configuration.nix              # system config (no home-manager)
  hardware-configuration.nix     # Linode QEMU/KVM hardware, serial console, grub
```

## Hardware — nixnotdix
- **GPU:** NVIDIA (proprietary drivers, libvdpau, 32-bit support)
- **Kernel:** Zen (low-latency)
- **Monitors:**
  - DP-3: 1920x1080 @ 144Hz — workspaces 1–3
  - HDMI-A-1: 1920x1080 @ 60Hz — workspaces 4–6

## Desktop Stack (nixnotdix)
| Component | Choice |
|---|---|
| Window manager | Sway |
| Display manager | greetd + tuigreet |
| Status bar | Waybar |
| App launcher | Fuzzel |
| Notifications | Mako |
| Idle/lock | swayidle + swaylock |
| Terminal | alacritty |
| Wallpaper | Sway output background |

**Theme:** Kanagawa Wave throughout — alacritty, fuzzel, mako, sway borders, waybar, bash prompt, cursor (Bibata Modern Ice 22px).

## Key Packages — nixnotdix
- **Gaming:** Steam + protontricks, gamemode, NoiseTorch, CloneHero, PrismLauncher
- **Dev:** Claude Code CLI, VSCodium, Git, Vim (`$EDITOR`)
- **Apps:** Firefox, VLC, Vesktop (Discord), Plex Desktop, Spotify, pavucontrol
- **Wayland utils:** wl-clipboard, grimblast, swayidle, swaylock
- **Utils:** btop, fastfetch, nh (Nix helper), tree, eza, killall

## Rules for Claude
- **Never run `./rebuild` or `nix flake update`** — tell Luke when these should be done and let him run them.

## Rebuild Workflow
The `rebuild` script at the repo root handles everything:
1. Detects changes (staged or unstaged), prompts to continue if none
2. Shows diff and prompts for confirmation
3. Stages all changes, then runs `nh os switch . -H <host>`
4. Commits the new generation
5. Git pushes

Supports `--boot` flag to stage the config without activating (requires reboot).

```bash
./rebuild            # rebuild current host
./rebuild nixvps     # rebuild a specific host
./rebuild --boot     # stage without activating
```

Note: the rebuild script only works locally. To deploy nixvps, SSH in and run nixos-rebuild directly.

## Nix Configuration
- Flakes enabled on both hosts
- Unfree packages allowed on nixnotdix (NVIDIA, Steam)
- Weekly GC, keeps 14 days of generations on both hosts
- `useGlobalPkgs` + `useUserPackages` enabled in home-manager (nixnotdix only)

## Git Config (home-manager managed, nixnotdix)
- Name: Luke
- Email: luke@collins.rocks

## Weather Widget
`hosts/nixnotdix/assets/weather/main.py` — Python script called by Waybar every 30 minutes.
- Uses OpenWeatherMap API — requires `OPENWEATHER_API_KEY` env var
- Also supports API key from `~/.config/openweathermap/api_key` via the Waybar wrapper script
- Falls back to IP geolocation if no `-c` location flag passed
- Location set to Aurora, US (Imperial units)

## Security Notes
- BattlEye domains blocked in `/etc/hosts` on nixnotdix
- nixvps: root SSH disabled, password auth disabled, fail2ban enabled, SSH restricted to user `luke`
