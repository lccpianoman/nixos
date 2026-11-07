# nixos

[![checks](https://github.com/lccpianoman/nixos/actions/workflows/check.yml/badge.svg)](https://github.com/lccpianoman/nixos/actions/workflows/check.yml)
[![NixOS 26.05](https://img.shields.io/badge/NixOS-26.05-5277C3?logo=nixos&logoColor=white)](https://nixos.org)

Declarative [NixOS](https://nixos.org) configuration for four machines (a
desktop, two VPSes and a home file server), managed from a single flake.
Secrets are encrypted into the repo with [sops-nix], so the whole thing is
public and still rebuilds every host from a clean clone.

## Hosts

| Host | Role | Notes |
|---|---|---|
| [`nixnotdix`](docs/nixnotdix.md) | Gaming / dev workstation | SwayFX on NVIDIA, Zen kernel, home-manager |
| [`nixvps`](docs/nixvps.md) | Linode VPS | Vaultwarden behind Caddy, nightly restic backups to B2 |
| [`nixcraft`](docs/nixcraft.md) | Vultr VPS | Fabric Minecraft server with nightly world snapshots |
| [`calliope`](docs/calliope.md) | Dell R730xd home server | 82 TiB raidz2 pool, NFS, Plex, \*arr stack, Immich |

All hosts track `nixos-26.05`; `nixnotdix` adds `home-manager` `release-26.05`.

## Layout

```text
flake.nix            inputs and the four nixosConfigurations
rebuild              build, switch, commit and push the local host
justfile             task runner: rebuild, checks, hooks, console helpers
common/              settings shared by every host (and every server)
hosts/<name>/        one directory per machine
keys/                public SSH keys only: admin key and server host keys
secrets/             sops-encrypted secrets, one directory per host
.sops.yaml           sops recipients
.githooks/           pre-commit guard against plaintext in secrets/
docs/                operational documentation
```

## Usage

```bash
./rebuild            # rebuild the machine you are on, then commit and push
./rebuild --boot     # build for next boot without switching
just check           # evaluate the flake
just hooks           # enable the secrets pre-commit hook (once per clone)
```

`rebuild` only ever applies to the host it runs on; to rebuild a server, SSH in
and run it there. See [Operations](docs/operations.md) for updating, checks
and the pinned overrides to re-check after a flake update.

## Documentation

| Topic | |
|---|---|
| [Operations](docs/operations.md) | Rebuilding, updating, pins, checks, code style |
| [Keys and secrets](docs/secrets.md) | SSH key layout, sops workflow, the pre-commit hook |
| [nixnotdix](docs/nixnotdix.md) | Desktop stack, NVIDIA, theming |
| [nixvps](docs/nixvps.md) | Vaultwarden, backups and restore |
| [nixcraft](docs/nixcraft.md) | Minecraft server, console, backups, install |
| [calliope](docs/calliope.md) | Hardware, fibre link, fans, install |
| [calliope: storage](docs/calliope-storage.md) | ZFS pool design and creation, NFS, replacing a disk |
| [calliope: media services](docs/calliope-media.md) | Caddy, VPN-routed qBittorrent, Radarr/Sonarr/Prowlarr, Plex, Seerr, Immich |

## Conventions

- **Secrets never touch the repo in plaintext.** Everything under `secrets/`
  is sops-encrypted to the admin key plus the one host that needs it, and a
  tracked pre-commit hook refuses anything else.
- **No formatter.** `nixfmt` destroys the aligned attribute blocks used
  throughout; match the surrounding style by hand.
- **Fail loudly.** Kernel patches, pinned hashes and host-key pins are all set
  up so that drift breaks the build rather than a running machine.

[sops-nix]: https://github.com/Mic92/sops-nix
