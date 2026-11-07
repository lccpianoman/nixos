# calliope

Home file and media server on a Dell PowerEdge R730xd.

| | |
|---|---|
| CPU / RAM | 2× Xeon E5-2690 v4 (56 threads), 236 GB |
| OS disk | Samsung 970 EVO Plus 500 GB NVMe, wiped and managed by disko |
| Data | 12× 10 TB SAS (HUH721010AL4200) behind an LSI SAS3008 HBA, one raidz2 pool |
| Network | Fibre only: 1000BASE-BX BiDi SFP in the onboard X520, static `192.168.0.10` |
| Management | iDRAC8 over in-band IPMI (no network cable needed) |
| SSH | port `47291`, key-only; `ssh calliope` from nixnotdix |

The host is split into one module per concern under `hosts/calliope/`:

| Module | |
|---|---|
| `disko.nix` | Boot NVMe layout; **only** the NVMe, on purpose |
| `ixgbe-bidi.nix` + `.patch` | Kernel patch that makes the fibre link work |
| `zfs.nix`, `nfs.nix` | The `storage` pool and its export; see [Storage](calliope-storage.md) |
| `fans.nix` + `fans/` | iDRAC fan control and temperatures |
| `caddy.nix`, `plex.nix`, `qbittorrent.nix`, `prowlarr.nix`, `radarr.nix`, `sonarr.nix`, `recyclarr.nix`, `seerr.nix`, `immich.nix`, `dashboard.nix` | The media stack; see [Media services](calliope-media.md) |

Claude Code and the GitHub Copilot CLI are installed so this repo can be
edited on the server. Pushes use `git@github.com:lccpianoman/nixos.git` over
an `~/.ssh/id_ed25519` keypair generated on calliope; the public half is a
write-enabled deploy key on the GitHub repo, not a file in `keys/`.

## Network

Fibre-only, by design. `eno1` is the SFP+ cage holding the 1310 nm module;
`eno2` is the empty cage and `eno3`/`eno4` are the i350 copper ports, all
left unconfigured. A second configured interface on the same subnet means
two default routes and replies leaving the wrong NIC, which reverse-path
filtering then drops. Recovery from a dead link is the physical console.

The router must never hand `192.168.0.10` to anything else: either move the
DHCP pool to start at `192.168.0.100` or reserve the address for
`ec:f4:bb:c8:8d:78`.

DNS is Quad9 (`9.9.9.9`, `149.112.112.112`), not the router and not
`1.1.1.1`. The ISP intercepts third-party port 53 so `1.1.1.1` is a black
hole from here, and the router's forwarder intermittently drops the A half of
a dual-family lookup; together they produced AAAA-only answers on a host with
no IPv6 route, which broke Go module fetches mid-rebuild.

Never hand-edit `/etc/resolv.conf` or other resolvconf-managed files while
debugging: openresolv signs them, and an unsigned file makes
`network-local-commands.service` fail, which fails the whole rebuild.

### The fibre link

`eno1` runs over a pair of 10Gtek 1000BASE-BX BiDi SFPs (`GLC-BX-U`/`-D`,
1310/1550 nm, single strand). Stock `ixgbe` refuses them and the port never
gets a netdev, which on a fibre-only host means an unreachable machine.

The driver does support BiDi. The problem is that these modules leave
SFF-8472 byte 6 blank, so the `IXGBE_SFF_BASEBX10_CAPABLE` bit the driver
gates on is absent. `hosts/calliope/ixgbe-bidi.nix` carries the full analysis
and a three-line patch relaxing that check. `allow_unsupported_sfp` does
**not** fix this on its own (it guards a different check in the same
function) but is set anyway.

Because the patch is pinned to the `ixgbe` source layout, a kernel bump can
stop it applying. That fails the build, which is the intended failure mode. Check it
after every flake update ([Operations](operations.md#the-ixgbe-kernel-patch)).

```bash
ethtool -m eno1        # EEPROM, wavelength, TX/RX optical power, temperature
ethtool eno1           # negotiated speed/duplex
```

**Reboot after changing optics rather than relying on hot-plug.** Hot-swap
can trip an upstream `ixgbe` bug where the runtime detection path reads the
EEPROM before the module has powered up, gets a bad identifier and calls
`unregister_netdev()`; the probe-error path then leaks its `mdio_bus` sysfs
node, which survives `rmmod` and blocks the port until reboot.

## Fans

`hosts/calliope/fans.nix` runs `fanctl`, a small Python service talking to
the iDRAC8 over `/dev/ipmi0`. It reports inlet, exhaust, CPU and per-drive
temperatures plus fan RPM, and switches between the iDRAC's automatic
control and one fixed speed for all fans. It is served at
`https://dash.jukeluke.com/fans/` and embedded in the dashboard.

Manual mode turns the iDRAC's thermal management off entirely, so `fanctl`
hands control back to auto the moment any sensor reaches its "hot" band, a
CPU or drive reading goes missing, or the service stops. The bands and their
reasoning are in `fans.nix`.

The page also toggles the iDRAC's extra cooling response for non-Dell PCIe
cards. Dell enables it by default, and the NVMe adapter alone is enough to
hold Auto near 8,500 RPM; with it off, Auto idles far lower. The setting is
stored in the iDRAC, survives reboots, and `fanctl` turns it back on at
"hot". By hand:

```bash
sudo ipmitool sdr type temperature; sudo ipmitool sdr type fan
sudo ipmitool raw 0x30 0x30 0x01 0x00          # manual
sudo ipmitool raw 0x30 0x30 0x02 0xff 0x14     # all fans 20% (hex percent)
sudo ipmitool raw 0x30 0x30 0x01 0x01          # back to auto
sudo ipmitool raw 0x30 0xce 0x01 0x16 0x05 0x00 0x00 0x00   # read PCIe response: ... 00 on, ... 01 off
sudo ipmitool raw 0x30 0xce 0x00 0x16 0x05 0x00 0x00 0x00 0x05 0x00 0x01 0x00 0x00   # off (0x00 = on)
```

## Installation

Installed by hand from the NixOS 26.05 minimal ISO, not `nixos-anywhere`.

The R730xd's firmware has no NVMe driver and cannot boot the OS disk
directly. A separate chainloader device loads `NvmExpressDxe.efi` and then
chainloads `\EFI\BOOT\BOOTX64.EFI` off the NVMe ESP. That is why
`boot.loader.efi.canTouchEfiVariables` is `false`: `bootctl` cannot register
an NVRAM entry for a disk the firmware cannot see. The ESP is 2 GB rather
than 512 MB because a patched kernel is rebuilt on every nixpkgs bump and
ten generations are kept.

Boot the installer in **UEFI** mode, get it online (temporary copper is
fine), then from a clone of this repo:

```bash
# 1. Partition, format and mount under /mnt. Targets the NVMe by-id; the
#    twelve SAS disks are not in disko.nix and cannot be touched.
nix --extra-experimental-features 'nix-command flakes' \
  run github:nix-community/disko -- \
  --mode destroy,format,mount ./hosts/calliope/disko.nix

# 2. Seed the host key that keys/calliope.host.pub came from, so the knownHosts
#    pin on nixnotdix matches from first boot and sops can decrypt.
install -d -m 0755 /mnt/etc/ssh
install -m 0600 /tmp/calliope_host_ed25519     /mnt/etc/ssh/ssh_host_ed25519_key
install -m 0644 /tmp/calliope_host_ed25519.pub /mnt/etc/ssh/ssh_host_ed25519_key.pub

# 3. Install. Prompts for a root password at the end. Set one; it is the
#    console recovery path, and SSH root login is disabled regardless.
nixos-install --flake .#calliope

# 4. Give luke a password so wheel can sudo.
nixos-enter --root /mnt -c 'passwd luke'

# 5. Confirm the chainload target exists before rebooting.
ls -l /mnt/boot/EFI/BOOT/BOOTX64.EFI /mnt/boot/EFI/systemd/systemd-bootx64.efi
```

Unplug the copper, point the chainloader at the NVMe ESP, reboot, and
`ssh calliope` from nixnotdix.

If the host key was regenerated rather than seeded, replace
`keys/calliope.host.pub` with the new `/etc/ssh/ssh_host_ed25519_key.pub`,
update `.sops.yaml` and `sops updatekeys` the calliope secrets, and rebuild
nixnotdix. Otherwise the pin rejects the connection and sops cannot decrypt.

After the OS is installed, the pool is created by hand; see
[Storage › Creating the pool](calliope-storage.md#creating-the-pool).
