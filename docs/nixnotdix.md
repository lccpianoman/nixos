# nixnotdix

Gaming and development workstation. x86_64, NVIDIA, `linuxPackages_zen`,
systemd-boot. The only host that uses home-manager; its user environment is
`hosts/nixnotdix/home.nix` and the modules under `hosts/nixnotdix/home/`.

## Desktop

| Component | Choice |
|---|---|
| Compositor | [SwayFX](https://github.com/WillPower3309/swayfx) 0.6: sway 1.12 plus blur, shadows, rounded corners and animations |
| Login | greetd + [ReGreet](https://github.com/rharish101/ReGreet), running under sway |
| Bar / launcher / notifications | Waybar, Fuzzel, Mako |
| Lock | swayidle + swaylock-effects (blurred screenshot, 5-minute idle timeout, locks before sleep) |
| Terminal | Alacritty |
| Browser | Firefox, themed to match with a store-built start page |
| Theme | A muted "dusk" palette in `theme.nix`, consumed by every module |

Everything visual (colours, fonts, cursor, corner radius, gaps, wallpaper)
reads from `hosts/nixnotdix/theme.nix`, and `constants.nix` holds monitors
and the weather widget's city. Change a colour once and sway, Waybar, Fuzzel,
Mako, Alacritty, btop, ReGreet, swaylock, Firefox and the wallpaper all
follow.

### Theme

The palette is violet-tinted ink (`base`, `surface`, `overlay`) with muted
pastels for syntax-style roles and exactly one colour allowed to be loud:
`accent`, a peach. Focus borders, the active workspace pill, selections,
links and the terminal cursor all use it; the rest of the UI is deliberately
quiet so that one colour reads as "where you are".

The wallpaper is not a file. `hosts/nixnotdix/wallpaper.nix` renders it at
build time with ImageMagick from `theme.wallpaper` in `theme.nix`: a few
elliptical colour washes over `base`, blurred heavily, with a soft vignette
and a little grain. Move or recolour a wash there and the next rebuild
redraws the desktop and the greeter. ImageMagick is a build input of that
derivation only; it is not installed on the system. The old photo wallpapers
under `assets/wallpapers/` are still there if you want a real image back:
point `wallpaper` in `sway.nix` and `configuration.nix` at one of them.

SwayFX does the eye candy: three-pass blur behind every translucent surface
(terminal at 78% opacity, Waybar islands, Mako cards, Fuzzel), wide soft
shadows, 12px corners, 300ms animations and a light dim on unfocused
windows. Waybar sits at the top as three detached pill "islands" on a
transparent window; `blur_ignore_transparent` in its `layer_effects` keeps
the gaps between islands clear, which is why its shadows and rounding are
done in its own CSS rather than by swayfx.

### Greeter

ReGreet runs under sway rather than the module's default `cage`: cage
hardcodes its cursor theme and ignores `XCURSOR_*`, so the pointer would
change shape between greeter and session. The session itself is launched
from `sway.desktop`, not a greeter `--cmd`.

home-manager's profile `sway` shadows the NixOS wrapper in `PATH`, so
`programs.sway.extraOptions` never reaches the session. The NVIDIA opt-out is
`SWAY_UNSUPPORTED_GPU=true` in `environment.sessionVariables` (and on the
greetd service for the greeter's own sway). If the greeter ever breaks, a TTY
is at Ctrl+Alt+F2.

### Firefox

`hosts/nixnotdix/home/firefox.nix` and `home/firefox/` carry `userChrome.css`,
`userContent.css` and a start page, all templated with at-delimited
placeholders (`@base@`, `@accent@`, …) substituted from `theme.nix`, so colours
are never hard-coded in the CSS.

The start page is a single `file://` document in the store used as both the
homepage and the new tab page. `newtab.cfg` is an autoconfig script that
reads the `nixos.newtab.url` pref and assigns `AboutNewTab.newTabURL`;
Firefox blanks the URL bar for any URL equal to that one, which is the
point. Keep the two prefs identical. `extraPrefsFiles` entries must be
derivations, not bare paths: the wrapper splices them with `toString`,
which strips the string context a path needs to become a build input.

### Weather widget

Waybar runs `hosts/nixnotdix/assets/weather/main.py` every 30 minutes via a
small wrapper script. The OpenWeatherMap API key is read from
`~/.config/openweathermap/api_key` (or `OPENWEATHER_API_KEY`), which is
`.gitignore`d. The script prints `N/A` on any failure so the bar never
breaks.

## Hardware notes

- **NVIDIA**: proprietary driver with modesetting, pinned to `595.99.02`
  because nixpkgs' stable driver fails to build against kernel 7.2. The pin
  self-expires once nixpkgs catches up; see
  [Operations › Pinned overrides](operations.md#pinned-overrides).
- **IPv6 is disabled**: the LAN has link-local only and no default route, but
  DNS still returns AAAA records, so applications would get IPv6-only answers
  and fail instantly. Turning it off makes `getaddrinfo` return IPv4 only.
- **GTA Online**: three BattlEye hostnames are null-routed in
  `networking.hosts`; without them the game kicks on connect under Proton.
- **`DefaultLimitNOFILE`** is raised to 1048576 for Steam/Proton.

## Software

- **Gaming**: Steam with Proton-GE (from the unstable input; see
  [Operations](operations.md#the-unstable-input)), protontricks, gamemode,
  NoiseTorch, CloneHero (local build), PrismLauncher
- **Development**: Claude Code (unstable), GitHub Copilot CLI (unstable),
  VSCodium, Git, Vim, direnv + nix-direnv, `nix-ld`
- **Apps**: Firefox, VLC, Vesktop, Plex Desktop, Spotify, pavucontrol
- **CLI**: eza, tree, btop, fastfetch, glow, ripgrep, jq, `nh`, `just`,
  sops + ssh-to-age, wl-clipboard, grimshot

## Network

- Pinned server host keys in `programs.ssh.knownHosts` for `nixvps`,
  `nixcraft`, `calliope` and `github.com`.
- SSH aliases in `home/ssh.nix` so `ssh calliope` / `ssh nixvps` / `ssh
  nixcraft` work with the right port and key. `calliope` also has a
  `networking.hosts` entry, which is what lets `mount.nfs` resolve it.
- `/mnt/media` is an NFSv4.2 automount of `calliope:/srv/media`. It mounts on
  first access and unmounts after ten idle minutes, so the workstation boots
  fine when the file server is off. `luke` is pinned to uid 1000 and the
  `media` group to gid 3000 to match calliope, because NFS puts numeric ids
  on the wire.

## Checks

```bash
just check-sway    # validate the generated sway config against the real swayfx
nix run nixpkgs#ruff -- check hosts/nixnotdix/assets/weather/main.py
```

`check-sway` exists because SwayFX's GLES2-only renderer needs a DRM device
the Nix sandbox lacks, so `wayland.windowManager.sway.checkConfig` is off.
