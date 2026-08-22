{ lib, modulesPath, ... }:

# Vultr Cloud Compute (QEMU/KVM, legacy BIOS boot).
# Unlike the other hosts this file is hand-written rather than generated:
# filesystems and swap are declared in disko.nix, so there is no
# fileSystems.<path> block here.

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  boot.initrd.availableKernelModules = [
    "virtio_pci"
    "virtio_blk"
    "virtio_scsi"
    "ahci"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  # The GRUB target device is set by disko, derived from the EF02 partition in
  # disko.nix — setting boot.loader.grub.device here too would duplicate it and
  # trip the "duplicated devices in mirroredBoots" assertion.
  boot.loader.grub = {
    enable = true;
    efiSupport = false;
  };

  # Vultr's web console can attach to either the emulated VGA console or the
  # first serial port; log to both so the view isn't blank whichever it lands
  # on. Serial is the one that matters for debugging a failed boot.
  boot.kernelParams = [
    "console=tty1"
    "console=ttyS0,115200n8"
  ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
