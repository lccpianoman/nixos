{ ... }:

# Declarative disk layout for calliope's boot/root NVMe, consumed by disko at
# install time. Nothing here is read at runtime — it exists so the disk can be
# recreated from scratch with no manual fdisk work.
#
# Only the NVMe is declared. The twelve 10 TB SAS disks behind the LSI SAS3008
# carry the `storage` ZFS pool and are deliberately absent from this file, so a
# `disko --mode destroy,format,mount` run cannot reach them.
#
# This replaces an old Proxmox install (an LVM PV with pve-root/pve-swap plus a
# 1 M BIOS boot partition). Nothing from it is preserved.

{
  disko.devices.disk.main = {
    type = "disk";
    # by-id rather than /dev/nvme0n1: thirteen disks share this machine and
    # kernel enumeration order is not guaranteed across boots. Pointing disko
    # at a name that could drift is how you wipe the wrong disk.
    device = "/dev/disk/by-id/nvme-Samsung_SSD_970_EVO_Plus_500GB_S58SNM0T417224E";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          priority = 1;
          # 2 G, not the usual 512 M: systemd-boot parks a kernel + initrd per
          # generation here, and configurationLimit is 10. A patched kernel is
          # rebuilt on every nixpkgs bump, so generations turn over quickly.
          size = "2G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            # FAT carries no permission bits, so without this the whole ESP is
            # world-readable and systemd-boot warns about it.
            mountOptions = [ "umask=0077" ];
          };
        };
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };

  # No swap. The machine has 236 GB of RAM for a file server, and once the
  # `storage` pool is adopted the ARC is the thing that should be free to grow
  # into spare memory — a swapfile on root would only give the kernel somewhere
  # to push ARC-adjacent pages it should have evicted instead.
}
