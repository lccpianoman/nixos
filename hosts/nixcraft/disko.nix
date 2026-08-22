{ lib, ... }:

# Declarative disk layout, consumed by nixos-anywhere at install time.
#
# Vultr Cloud Compute boots legacy BIOS, so this is a GPT table with a 1 MiB
# EF02 "BIOS boot" partition to hold GRUB's core image, plus a single ext4
# root filling the rest of the disk. Nothing here is read at runtime — it
# exists so the disk can be recreated from scratch with no manual fdisk work.

{
  disko.devices.disk.main = {
    type = "disk";
    # Vultr exposes the system disk over virtio.
    device = "/dev/vda";
    content = {
      type = "gpt";
      partitions = {
        boot = {
          priority = 1;
          size = "1M";
          type = "EF02";
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
