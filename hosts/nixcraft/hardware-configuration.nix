{ lib, modulesPath, ... }:

# Vultr Cloud Compute (QEMU/KVM, UEFI/EDK II firmware).
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

  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    # UEFI boots off the ESP, not a raw disk, so there is no target device.
    device = "nodev";
    # Cloud firmware frequently forgets NVRAM boot entries across a rebuild or
    # a hard power cycle, which leaves the VM dropping to the UEFI shell with
    # no way back in. Installing to the removable-media fallback path
    # (\EFI\BOOT\BOOTX64.EFI) is always tried by firmware and needs no NVRAM.
    efiInstallAsRemovable = true;
  };
  # Mutually exclusive with efiInstallAsRemovable above.
  boot.loader.efi.canTouchEfiVariables = false;

  # Vultr's web console can attach to either the emulated VGA console or the
  # first serial port; log to both so the view isn't blank whichever it lands
  # on. Serial is the one that matters for debugging a failed boot.
  boot.kernelParams = [
    "console=tty1"
    "console=ttyS0,115200n8"
  ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
