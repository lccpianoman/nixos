# Operations

## Rebuilding

`./rebuild` builds the configuration for the machine it runs on, switches to
it with `nh os switch`, and on success commits and pushes with the message
`Rebuild <host> to generation <n>`. It stages all changes first so Nix sees
uncommitted files, shows the diff, and asks for confirmation.

```bash
./rebuild            # switch now
./rebuild --boot     # activate on next boot
```

It refuses to build a configuration for any other host, because `nh` would
activate it on the local machine. To rebuild a server, SSH in and run it there.

With `just`:

```bash
just rebuild
just boot
just minecraft       # attach to the Minecraft console on nixcraft
just garbage         # nix-collect-garbage -d, user and root
just optimize        # nix store optimise, user and root
```

## Updating

Run `nix flake update` roughly monthly or after security fixes, then rebuild
each host. Two things need checking after every update.

### The ixgbe kernel patch

`calliope`'s only network link depends on
[`hosts/calliope/ixgbe-bidi.patch`](../hosts/calliope/ixgbe-bidi.patch),
which is pinned to the `ixgbe` source layout. A kernel bump can stop it
applying, which fails the build loudly rather than booting the host with no
network, and that is the intended failure mode. Confirm it still applies:

```bash
src=$(nix build --no-link --print-out-paths \
  '.#nixosConfigurations.calliope.pkgs.linuxPackages.kernel.src')
tar -xf "$src" --wildcards '*/drivers/net/ethernet/intel/ixgbe/ixgbe_phy.c' -O \
  >/dev/null && echo "fetched ok"
# then, from an extracted kernel tree:
patch -p1 --dry-run < hosts/calliope/ixgbe-bidi.patch
```

Because `calliope` builds a patched kernel, ZFS builds its module from source
against it. An update that moves the LTS kernel past what the packaged ZFS
supports also fails the build; compare `boot.kernelPackages.kernel.version`
against `pkgs.zfs` before assuming a kernel bump is safe.

### Pinned overrides

Several packages are overridden locally until nixpkgs catches up. Each is
written to self-expire (the overlay compares versions and falls back to
nixpkgs once it is newer), but the dead code should be removed once that
happens.

| Pin | Where | Remove when |
|---|---|---|
| NVIDIA `595.99.02` | `hosts/nixnotdix/configuration.nix` (`hardware.nvidia.package`) | nixpkgs `nvidiaPackages.stable >= 595.99.02` |
| CloneHero `1.1.0.6142` | `hosts/nixnotdix/configuration.nix` overlay + `hosts/nixnotdix/pkgs/clonehero.nix` | nixpkgs `clonehero >= 1.1.0.6142` |
| SwayFX `0.6` + scenefx `0.5` | `hosts/nixnotdix/configuration.nix` overlay | nixpkgs `swayfx-unwrapped >= 0.6` and `scenefx >= 0.5` |
| Minecraft Java 25 override | `hosts/nixcraft/minecraft/server.nix` (`jre_headless = pkgs.jdk25_headless`) | nix-minecraft's `mkTextileServer` picks its JRE from `java_versions` (it still takes nixpkgs' default `jre_headless`, Java 21, and MC 26.2 needs 25) |
| ixgbe BiDi SFP patch | `hosts/calliope/ixgbe-bidi.{nix,patch}` | upstream `ixgbe` accepts 1000BASE-BX modules whose SFF-8472 byte 6 is blank (currently it requires the `BASEBX10` bit *and* `bitrate_nominal == 0xD`) |
| Immich `2.7.5` insecure permit | `hosts/calliope/immich.nix` (`permittedInsecurePackages`) | nixpkgs `immich >= 3.0.3` (expected with 26.11). 2.x is EOL with CVE-2026-59258 / CVE-2026-82272; both need an authenticated account, so it is tolerable LAN-only with two trusted users |
| Caddy `withPlugins` hash | `hosts/calliope/caddy.nix` | Never; it is a vendor hash, not a version pin. A flake update that moves Caddy or the cloudflare plugin fails the build with the replacement hash in the error |

Check what nixpkgs currently ships:

```bash
nix eval --impure --expr 'let f = builtins.getFlake (toString ./.); p = f.inputs.nixpkgs.legacyPackages.x86_64-linux; in { nvidia = p.linuxPackages_zen.nvidiaPackages.stable.version; clonehero = p.clonehero.version; immich = p.immich.version; swayfx = p.swayfx-unwrapped.version; scenefx = p.scenefx.version; }'
```

### The unstable input

`flake.nix` carries a second nixpkgs, `nixpkgs-unstable`, feeding exactly one
overlay on `nixnotdix`: `claude-code`, `github-copilot-cli` and
`proton-ge-bin`. All three release far faster than the stable channel
backports them, and all three are safe to take from another channel
(`claude-code` is a leaf package, `github-copilot-cli` is GitHub's prebuilt
release tarball, and `proton-ge-bin` is a prebuilt binary that runs inside
Steam's own runtime), so none mixes unstable libraries into the rest of the
closure.

Keep it to those three. Anything else pulled from unstable mixes two
channels' glibc and stdenv into one system. The overlay `import`s unstable
with the host's `nixpkgs.config` rather than reading `legacyPackages`,
because `claude-code` and `github-copilot-cli` are unfree and
`legacyPackages` carries its own config. Check what the overlay is actually
serving:

```bash
nix eval .#nixosConfigurations.nixnotdix.config.home-manager.users.luke.home.packages \
  --apply 'ps: map (p: p.name) (builtins.filter (p: builtins.elem (p.pname or "") [ "claude-code" "github-copilot-cli" ]) ps)'
```

The other three hosts use stable `claude-code`.

## Checks

CI ([`.github/workflows/check.yml`](../.github/workflows/check.yml)) runs the
first three on every push and pull request.

```bash
nix flake check --no-build --no-write-lock-file          # just check
nix run nixpkgs#shellcheck -- ./rebuild                  # just shellcheck
nix run nixpkgs#ruff -- check hosts/nixnotdix/assets/weather/main.py
just check-sway        # validate nixnotdix's generated sway config against swayfx
just check-secrets     # confirm every file under secrets/ is encrypted
```

`check-sway` exists because SwayFX's GLES2-only renderer cannot start inside
the Nix sandbox, so home-manager's `checkConfig` is off for it.

## Code style

There is deliberately no Nix formatter and no `formatter` flake output.
`nixfmt` collapses the aligned `=` blocks in `theme.nix`, `mako.nix`,
`fuzzel.nix`, `waybar.nix` and `sway.nix`, cannot be told not to, and a
whole-tree run rewrites 18 of 30 files for no change in output. Match the
surrounding style by hand.

Comments explain *why*, not *what*, especially for anything that was
learned the hard way. If a setting exists because something broke, the
comment says what broke.
