# Documentation

Operational documentation for the hosts in this flake. The top-level
[README](../README.md) is the overview; these pages hold the detail.

## General

- [Operations](operations.md) — rebuilding, updating, pinned overrides,
  checks, code style
- [Keys and secrets](secrets.md) — SSH key layout, sops workflow, the
  pre-commit hook

## Hosts

- [nixnotdix](nixnotdix.md) — gaming / dev workstation
- [nixvps](nixvps.md) — Linode VPS running Vaultwarden
- [nixcraft](nixcraft.md) — Vultr VPS running a Minecraft server
- [calliope](calliope.md) — Dell R730xd home server
  - [Storage](calliope-storage.md) — ZFS pool, NFS export, disk replacement
  - [Media services](calliope-media.md) — Caddy, qBittorrent over WireGuard,
    the \*arr stack, Plex, Seerr, Immich

Agent-facing notes (hard rules, pins to re-check, things that have broken
before) live in [`AGENTS.md`](../AGENTS.md) at the repo root.
