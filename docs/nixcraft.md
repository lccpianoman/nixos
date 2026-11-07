# nixcraft

Vultr VPS (x86_64, QEMU/KVM, 8 GB / 3 vCPU) running a Fabric Minecraft
server for version 26.2, managed by [nix-minecraft].

## Server

| | |
|---|---|
| Address | `mc.jukeluke.com:25565` |
| Data | `/srv/minecraft/survival` |
| Heap | fixed 6 GB (`-Xms6G -Xmx6G`, tuned G1GC) |
| Mode | survival, hard, whitelist enforced, online mode |
| Console | tmux session on `/run/minecraft/survival.sock` |

Whitelist, operators and `server.properties` are declarative in
`hosts/nixcraft/minecraft/server.nix`. Mods are pinned by URL and SHA-512 in
the same file; to add or update one:

```bash
nix run github:Infinidoge/nix-minecraft#nix-modrinth-prefetch -- <versionId>
```

Current mods: Fabric API, Carpet, Carpet Extra, Carpet TIS Addition, Servux,
Lithium, FerriteCore, Krypton, spark.

The JVM heap must never be paged out, so `vm.swappiness` is 10; swap exists
only as an OOM backstop.

### Console

```bash
just minecraft                                   # from nixnotdix
tmux -S /run/minecraft/survival.sock attach      # on the host
```

Detach with `Ctrl-b d`. Stop the server with
`systemctl stop minecraft-server-survival`.

`luke` is in the `minecraft` group so the socket and the server files are
usable without sudo.

### World backups

`minecraft-backup-survival.timer` runs nightly at 04:00 (±10 min), pausing
saves (`save-off`, `save-all flush`) before archiving the world to
`/var/backup/minecraft/survival-<stamp>.tar.zst` and resuming them after.
Mods, logs, caches and libraries are excluded. Archives older than 14 days
are deleted.

Backups are local to the VPS; there is no offsite copy.

## Users and secrets

`luke` has a password so `wheel` can `sudo` and the Vultr web console is
usable. SSH is key-only and root login is disabled everywhere, so without it
there would be no recovery path. The hash is a sops secret
(`secrets/nixcraft/users.yaml`) marked `neededForUsers`, which lands it in
`/run/secrets-for-users` before users are created.

## Installation

Installed with [nixos-anywhere] and the disko layout in
`hosts/nixcraft/disko.nix` (GPT, 512 MB ESP, ext4 root on `/dev/vda`).
Vultr boots UEFI; a BIOS/`bios_grub` layout drops to the UEFI shell.

Requirements: UEFI boot, disk at `/dev/vda`, SSH key attached at provider
install time.

```bash
nix run github:nix-community/nixos-anywhere -- \
  --flake .#nixcraft \
  --extra-files /tmp/nixcraft-files \
  root@<IP>
```

`--extra-files` must seed the host's SSH host key at
`/tmp/nixcraft-files/etc/ssh/ssh_host_ed25519_key` (mode `0600`, plus the
`.pub`). sops decrypts with that key, so without it the first activation
cannot unlock any secret, and a freshly generated key would not match the
recipient in `.sops.yaml`. Seeding it also keeps `keys/nixcraft.host.pub`
valid across a reinstall, so the `knownHosts` pin on nixnotdix does not
break.

[nix-minecraft]: https://github.com/Infinidoge/nix-minecraft
[nixos-anywhere]: https://github.com/nix-community/nixos-anywhere
