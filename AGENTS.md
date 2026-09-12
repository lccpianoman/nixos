# nixos config (agent notes)

## Source of truth
- `README.md` is the human/operational source of truth.
- This file is for agent instructions and quick repo context.
- If they drift, trust `README.md` and update this file.

## Hosts
| Host | Role |
|---|---|
| `nixnotdix` | Gaming/dev workstation (Sway, NVIDIA, Zen kernel) |
| `nixvps` | Linode VPS (Vaultwarden behind Caddy) |
| `nixcraft` | Vultr VPS (Minecraft server) |

## Repo layout (high-level)
```text
flake.nix
flake.lock
rebuild
common/
  default.nix
  server-base.nix
  identity.nix
hosts/
  nixnotdix/
  nixvps/
  nixcraft/
keys/
  luke-nixnotdix.pub
  nixvps.host.pub
  nixcraft.host.pub
secrets/
.sops.yaml
```

## Keys and secrets
- `keys/` is public keys only — safe to commit, safe to publish.
- Private keys never leave the machine that generated them; servers pull this
  repo over HTTPS, so they hold no key.
- Secrets are sops-nix encrypted under `secrets/`, decrypted at activation with
  each host's SSH host key. Recipients live in `.sops.yaml`.
- Never write a plaintext secret into the repo, and never `cat` one into a
  transcript. Pipe host → `sops` directly.

## Hard rules
- Never run `./rebuild` or `nix flake update` in automation; Luke runs those manually.
- After any Luke-run `nix flake update`, re-check pin removal conditions and report.

## Active pins to re-check after flake updates
| Pin | Where | Remove when |
|---|---|---|
| NVIDIA `595.99.02` | `hosts/nixnotdix/configuration.nix` (`hardware.nvidia.package`) | nixpkgs `nvidiaPackages.stable >= 595.99.02` |
| CloneHero `1.1.0.6142` | `hosts/nixnotdix/configuration.nix` overlay + `hosts/nixnotdix/pkgs/clonehero.nix` | nixpkgs `clonehero >= 1.1.0.6142` |

Check with:
```bash
nix eval --impure --expr 'let f = builtins.getFlake (toString ./.); p = f.inputs.nixpkgs.legacyPackages.x86_64-linux; in { nvidia = p.linuxPackages_zen.nvidiaPackages.stable.version; clonehero = p.clonehero.version; }'
```

## Notes
- `rebuild` only applies to the local host where it runs.
- `nixnotdix` uses home-manager; `nixvps` and `nixcraft` are NixOS-only.
