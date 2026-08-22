{ lib, ... }:

# Declarative disk layout, consumed by nixos-anywhere at install time.
#
# Vultr Cloud Compute boots via UEFI (EDK II), so this is a GPT table with an
# EF00 EFI System Partition plus an ext4 root. Nothing here is read at runtime
# — it exists so the disk can be recreated from scratch with no manual fdisk
# work.
#
# Do not "simplify" this to a BIOS/EF02 bios_grub layout: the firmware ignores
# the MBR gap entirely, finds nothing bootable, and drops to the UEFI shell.

{
  disko.devices.disk.main = {
    type = "disk";
    # Vultr exposes the system disk over virtio.
    device = "/dev/vda";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          priority = 1;
          size = "512M";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            # The ESP is FAT, which has no permission bits — without this the
            # whole thing is world-readable and systemd-boot/GRUB complain.
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

  # 8 GB is plenty for the JVM heap, but a swapfile gives the kernel somewhere
  # to push cold pages instead of OOM-killing the server during a chunk-gen
  # spike. Kept small and low-priority — swapping the heap would be worse than
  # the problem it solves (see vm.swappiness in configuration.nix).
  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 4 * 1024;
    }
  ];
}
