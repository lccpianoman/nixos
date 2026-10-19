{ config, pkgs, lib, ... }:

let
  sshPort = 47291;
in

{
  imports = [
    ../../common
    ../../common/server-base.nix
    ./hardware-configuration.nix
    ./disko.nix
    ./ixgbe-bidi.nix
  ];

  networking.hostName = "calliope";
  networking.domain   = "";

  # ===== Network =====
  #
  # calliope is fibre-only. eno1 is PCI 01:00.0, the SFP+ cage holding the
  # 1310 nm 1000BASE-BX module; eno2 is the empty cage and eno3/eno4 are the
  # i350 copper ports, all left unconfigured on purpose. A second configured
  # interface on this subnet would mean two default routes and replies landing
  # on the wrong NIC, which reverse-path filtering then drops.
  #
  # Recovery if the link ever fails is the physical console, not another NIC.
  # The most likely way to lose it is ./ixgbe-bidi.nix failing to apply after a
  # kernel bump — which breaks the build loudly rather than booting unreachable.
  networking.useDHCP = false;
  networking.interfaces.eno1.ipv4.addresses = [{
    address      = "192.168.0.10";
    prefixLength = 24;
  }];
  networking.defaultGateway = {
    address   = "192.168.0.1";
    interface = "eno1";
  };
  networking.nameservers = [ "192.168.0.1" "1.1.1.1" ];

  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ sshPort ];

  # Set now rather than when the pool is adopted: ZFS stamps the importing
  # host's id into the pool, and changing it later turns a plain `zpool import`
  # into an import -f after a rebuild and reboot. Inert until ZFS is enabled.
  networking.hostId = "ca111098";

  # ===== Users =====

  users.users.luke = {
    isNormalUser = true;
    extraGroups  = [ "wheel" ];
    # No password is declared here. This repo is public, and calliope has no
    # sops recipient yet (see README). users.mutableUsers keeps its default of
    # true, so set one once from the installer:
    #     nixos-enter --root /mnt -c 'passwd luke'
    # SSH stays key-only either way (common/server-base.nix); the password
    # exists so wheel can sudo and so the console is usable.
  };

  boot.tmp.cleanOnBoot = true;

  environment.systemPackages = with pkgs; [
    ethtool        # `ethtool -m eno1` dumps the SFP EEPROM and optical power
    pciutils
    nvme-cli
    smartmontools
    lm_sensors
  ];

  system.stateVersion = "26.05";
}
