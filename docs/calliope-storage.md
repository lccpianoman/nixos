# calliope: storage

The twelve SAS disks form one ZFS pool, `storage`, exported to the LAN over
NFSv4. The NixOS side (mounts, permissions, scrub, ZED, snapshots) is
`hosts/calliope/zfs.nix` and `nfs.nix`. The pool itself is created by hand.

## Design

One `raidz2` vdev of twelve disks: 82.4 TiB usable, surviving any two
failures.

- **One wide vdev, not two 6-disk vdevs.** The SFPs negotiate 1 Gbps, so the
  wire caps at ~113 MB/s, and a single raidz2 vdev already does 600–900 MB/s
  sequential. Splitting would buy random IOPS nothing here can spend and cost
  18 TiB. All twelve bays are full, so there is no second-vdev expansion path
  to preserve either.
- **The cost is resilver time.** Rebuilding one disk reads every other disk
  in the vdev and runs for most of a day at one parity. That is the right
  trade for replaceable media and the wrong one for anything irreplaceable;
  for that the answer is `storage/documents` plus an offsite copy, not more
  parity. **The pool is not a backup.**
- **Not declared in Nix.** `hosts/calliope/disko.nix` describes only the
  boot NVMe, which is what makes a `disko --mode destroy,format,mount` run
  unable to reach these disks. That standing guarantee is worth more than a
  convenience used once.

### Datasets

| Dataset | Mount | `recordsize` | `compression` | Why |
|---|---|---|---|---|
| `storage/media` | `/srv/media` | 1M | lz4 | Large sequential files. Holds both `library/` and `downloads/` |
| `storage/photos` | `/srv/photos` | 1M | lz4 | Write-once originals; a file below `recordsize` still uses one right-sized record |
| `storage/documents` | `/srv/documents` | 128K | zstd | Small, compressible, rewritten in place |
| `storage/backups` | `/srv/backups` | 1M | off | restic/borg output is already compressed and encrypted |

`downloads/` is a **directory inside** `storage/media`, not its own dataset.
Hardlinks and atomic renames cannot cross a dataset boundary, so splitting
them would turn every \*arr import into a full copy and make seeding cost
double the space. The price is that snapshots of `storage/media` pin deleted
partial downloads until they age out.

### Mounting

Every dataset is `mountpoint=legacy` and mounted from `fileSystems` in
`zfs.nix`, not by `zfs-mount.service`. `systemd.targets.zfs` is only
`wantedBy` multi-user.target, never ordered before it, so ZFS-native mounts
race the services that read them and a service can start and write into the
bare mountpoint. Declaring them makes `zfs-import-storage.service` a real
dependency of each `.mount` unit and lets services use `RequiresMountsFor`.

All four carry `nofail`: calliope is fibre-only and its recovery path is a
physical console, so an unimportable pool must never hold up boot. Services
that need the data fail individually instead, which is visible over SSH.

Permissions are tmpfiles rules re-applied every boot: the library tree is
`2775 luke:media` so luke and the service users share one setgid tree. `luke`
is uid 1000 and `media` is gid 3000 on both calliope and nixnotdix, pinned
because NFS puts numeric ids on the wire.

### Maintenance

- **Scrub** monthly (`services.zfs.autoScrub`). A scrub reads every allocated
  block and runs most of a day; weekly would leave the pool scrubbing a third
  of the time.
- **TRIM** disabled, because `zpool trim` errors out on spinning SAS disks.
- **Snapshots** via sanoid: `media` 7 daily / 2 monthly; `photos` 14 daily /
  6 monthly; `documents` 24 hourly / 30 daily / 12 monthly; `backups`
  7 daily / 3 monthly. They stand between a misconfigured \*arr and the
  library, and let a compromised backup client not prune its own repo. They
  are not a backup: a pool-wide failure takes them too.
- **ZED** with verbose notifications. Enclosure LEDs are off because the
  backplane presents no SES; see [Replacing a disk](#replacing-a-disk).

## Creating the pool

One-time, and it destroys everything on the twelve disks. Order matters, and
the first rebuild **fails on purpose**: ZFS arrives with that rebuild, so it
cannot be present when the configuration that wants the pool first
activates.

```bash
# 1. Rebuild. This installs ZFS, then exits 4 with
#    "the following units failed: zfs-import-storage.service". The pool does
#    not exist yet, so the import cannot succeed and the four /srv mounts never
#    start. Expected. Two consequences:
#      - ./rebuild stops before its commit. Nothing is stranded.
#      - the system profile is NOT advanced. DO NOT REBOOT until step 10, or
#        the machine comes back on the pre-ZFS generation.
./rebuild

# 2. Load the ZFS module by hand. modprobe resolves against
#    /run/booted-system/kernel-modules, which predates ZFS; the module built by
#    step 1 is in the *current* system's tree. The kernel binary is the same
#    store path in both, so the module is ABI-correct for the running kernel.
sudo -i
modprobe -d /run/current-system/kernel-modules zfs
cat /sys/module/zfs/version          # expect the version pkgs.zfs reports

# 3. Collect the twelve disks by model, never by /dev/sd*. This cannot catch
#    the NVMe or the USB chainloader stick, and survives a disk swap.
mapfile -t disks < <(
  for d in /dev/disk/by-id/wwn-0x*; do
    case "$d" in *-part*) continue ;; esac
    [ "$(lsblk -ndo MODEL "$d")" = HUH721010AL4200 ] && echo "$d"
  done | sort
)
printf '%s\n' "${disks[@]}"; echo "count: ${#disks[@]}"   # must say 12

# 4. Destroy the old pool. It was built on another machine, so it needs -f, and
#    -N keeps it from mounting anything on the way through.
zpool import                       # note the old pool's name and id
zpool import -f -N <oldname>
zpool destroy <oldname>

# 5. Clear the old labels and the TrueNAS-era 2 G swap partitions.
for d in "${disks[@]}"; do
  for p in "$d"-part*; do
    [ -e "$p" ] && { zpool labelclear -f "$p" || true; wipefs -a "$p"; }
  done
  sgdisk --zap-all "$d"
done
udevadm settle

# 6. Create the pool. ashift=12 is forced anyway (these disks are 4Kn:
#    PHY-SEC and LOG-SEC are both 4096) but is stated so it cannot be guessed
#    wrong on a future replacement disk that reports 512e.
zpool create \
  -o ashift=12 -o autoexpand=on \
  -O compression=lz4 -O atime=off -O xattr=sa -O acltype=posixacl \
  -O dnodesize=auto -O canmount=off -O mountpoint=none \
  storage raidz2 "${disks[@]}"

# 7. Datasets. mountpoint=legacy because they are mounted from zfs.nix, not by
#    zfs-mount.service; see "Mounting" above.
zfs create -o mountpoint=legacy -o recordsize=1M                      storage/media
zfs create -o mountpoint=legacy -o recordsize=1M                      storage/photos
zfs create -o mountpoint=legacy -o recordsize=128K -o compression=zstd storage/documents
zfs create -o mountpoint=legacy -o recordsize=1M   -o compression=off  storage/backups

# 8. Mount them and let tmpfiles build the directory tree. Not
#    `systemctl restart systemd-tmpfiles-setup.service`; that unit sets
#    RefuseManualStart and will decline.
systemctl start srv-media.mount srv-photos.mount srv-documents.mount srv-backups.mount
systemd-tmpfiles --create

# 9. Check.
zpool status storage
zpool list -o name,size,alloc,free,cap,health
zfs list -o name,used,avail,recordsize,compression,mountpoint
ls -la /srv/media
exportfs -ra && exportfs -v          # /srv/media appears only once mounted
exit                                  # done as root

# 10. Rebuild again. This is the run that matters: with the pool present
#     zfs-import-storage succeeds, the mounts come up, it exits 0, and the
#     generation finally lands in the profile and the bootloader. Only now is
#     it safe to reboot.
./rebuild
systemctl --failed                    # expect none
```

`networking.hostId` was set before the pool was built, so the pool is
stamped with calliope's own id and imports without `-f`.

## NFS

`/srv/media` is exported over **NFSv4 only** (`hosts/calliope/nfs.nix`), which
is why the firewall needs a single port: v3 drags in `mountd`, `statd` and
`lockd` on ports that wander unless each is pinned. nixnotdix is the only
client and automounts it at `/mnt/media`.

AUTH_SYS trusts whatever uid the client sends, so the export is only as safe
as the LAN, hence the `192.168.0.0/24` restriction and `root_squash`.
Anything beyond the LAN should go through a tunnel, not a wider CIDR.

The export carries the `mountpoint` option, the required companion to the
`nofail` mounts: without it a pool that failed to import would leave nfsd
exporting the bare directory on the root NVMe, and clients would write into
the OS disk believing they were writing to the pool. Keep it on every export
added here.

To export another dataset, add a line to `services.nfs.server.exports`; no
new ports are needed under v4.

## Replacing a disk

The R730xd backplane does not present SES through the SAS3008
(`/sys/class/enclosure` is empty), so ZED cannot blink a failed disk.
**Build the serial-to-bay map while every disk still works**, because doing
it after a failure means guessing:

```bash
lsblk -do NAME,SERIAL,MODEL          # serials
ls -l /dev/disk/by-id/wwn-0x*        # wwn -> /dev/sdX
# Then, one disk at a time, watch which bay's light comes on:
dd if=/dev/sdX of=/dev/null bs=1M status=progress
```

Record the result outside this repo; a label on the chassis is best. Then
replacing a failure is:

```bash
zpool replace storage <old-wwn> <new-wwn>
```
