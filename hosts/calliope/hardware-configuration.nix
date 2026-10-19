{ config, lib, modulesPath, ... }:

# Dell PowerEdge R720xd — dual Xeon E5-2690 v4 (56 threads), 236 GB RAM,
# UEFI firmware, Samsung 970 EVO Plus 500 GB NVMe for the OS, twelve 10 TB SAS
# disks behind an LSI SAS3008 HBA.
#
# Like nixcraft this file is hand-written rather than generated: filesystems
# are declared in disko.nix, so there is no fileSystems.<path> block here.

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [
    "nvme"        # root lives on the NVMe; without this the initrd cannot find it
    "ahci"
    "xhci_pci"
    "ehci_pci"
    "mpt3sas"     # LSI SAS3008 HBA — not needed to boot, needed to see the pool
    "usb_storage"
    "usbhid"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

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

  hardware.enableRedistributableFirmware = true;
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
