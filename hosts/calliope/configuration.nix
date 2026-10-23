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
    ./zfs.nix
    ./nfs.nix
    ./fans.nix
    # Media stack — see README's "Media services". caddy.nix is the only
    # module that exposes anything; the rest bind to localhost and are
    # reached through it.
    ./caddy.nix
    ./plex.nix
    ./qbittorrent.nix
    ./prowlarr.nix
    ./radarr.nix
    ./recyclarr.nix
    ./sonarr.nix
    ./seerr.nix
    ./immich.nix
    ./dashboard.nix
  ];

  networking.hostName = "calliope";

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
  # Quad9, primary and secondary. Neither the router nor 1.1.1.1 is used:
  # 1.1.1.1 answers ICMP from here but its port 53 is a black hole
  # (CenturyLink intercepts third-party DNS), so as a *secondary* it was a
  # resolver that could never answer. That mattered more than it sounds — the
  # router's forwarder intermittently loses the A half of a dual-family
  # lookup, glibc then retried the A against 1.1.1.1 and timed out, so the
  # name resolved to its AAAA alone. This host has no IPv6 route, so anything
  # resolving normally would dial IPv6 and fail "network is unreachable",
  # which is what broke Go module fetches during a rebuild. nscd then cached
  # the v6-only answer and made it stick.
  networking.nameservers = [ "9.9.9.9" "149.112.112.112" ];

  networking.firewall.enable = true;
  # 80/443 are Caddy's. They are also forwarded from the router so Cloudflare
  # can reach request.jukeluke.com — which is why every other vhost in
  # caddy.nix carries a LAN-only guard rather than trusting DNS to hide it.
  networking.firewall.allowedTCPPorts = [ sshPort 80 443 ];

  # Set now rather than when the pool is adopted: ZFS stamps the importing
  # host's id into the pool, and changing it later turns a plain `zpool import`
  # into an import -f after a rebuild and reboot. Inert until ZFS is enabled.
  networking.hostId = "ca111098";

  # ===== Users =====

  users.users.luke = {
    isNormalUser = true;
    # Pinned rather than allocated: NFS puts numeric ids on the wire, so this
    # has to keep matching nixnotdix. 1000 is what both hosts already hold.
    uid          = 1000;
    extraGroups  = [ "wheel" "media" ];
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
    gptfdisk       # sgdisk, to zap a replacement disk's old partition table
    pciutils
    nvme-cli
    smartmontools
    lm_sensors
    claude-code
    github-copilot-cli
  ];

  system.stateVersion = "26.05";
}
