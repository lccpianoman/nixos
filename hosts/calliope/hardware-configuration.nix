{ config, lib, ... }:

# Dell PowerEdge R720xd — dual Xeon E5-2690 v4 (56 threads), 236 GB RAM,
# UEFI firmware, Samsung 970 EVO Plus 500 GB NVMe for the OS, twelve 10 TB SAS
# disks behind an LSI SAS3008 HBA.
#
# Like nixcraft this file is hand-written rather than generated: filesystems
# are declared in disko.nix, so there is no fileSystems.<path> block here.

{
  # The SATA/USB/HID modules a generated file would list here are all in
  # nixpkgs' default initrd set already (boot.initrd.includeDefaultModules).
  # Only these two are stated, so the root disk and the HBA do not silently
  # depend on that default staying true.
  boot.initrd.availableKernelModules = [
    "nvme"        # root lives on the NVMe; without this the initrd cannot find it
    "mpt3sas"     # LSI SAS3008 HBA — brings the twelve SAS disks up in stage 1
  ];
  boot.kernelModules = [ "kvm-intel" ];

  boot.loader.systemd-boot = {
    enable = true;
    # The ESP is 2 G and each generation parks a kernel + initrd on it.
    configurationLimit = 10;
  };

  # 12th-gen PowerEdge firmware ships no NVMe driver, so it cannot enumerate
  # the disk this ESP lives on and `bootctl` cannot register an NVRAM entry
  # pointing at it — leaving this true makes activation fail. Boot is reached
  # instead by chainloading \EFI\BOOT\BOOTX64.EFI off this ESP from the
  # chainloader device, which needs no NVRAM entry at all.
  boot.loader.efi.canTouchEfiVariables = false;

  # Also the only thing an installer/scan/not-detected.nix import would set,
  # which is why that import is absent.
  hardware.enableRedistributableFirmware = true;
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
