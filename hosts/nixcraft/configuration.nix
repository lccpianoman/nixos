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
    ./minecraft.nix
  ];

  networking.hostName = "nixcraft";
  networking.domain = "";

  # Vultr hands out addressing over DHCP on the single virtio NIC.
  networking.useDHCP = lib.mkDefault true;

  networking.firewall.enable = true;
  # The Minecraft port is opened by the server module itself
  # (services.minecraft-servers.servers.<name>.openFirewall).
  networking.firewall.allowedTCPPorts = [ sshPort ];

  users.users.luke = {
    isNormalUser = true;
    # "minecraft" lets Luke read/write the server files and attach to the
    # server console tmux socket without sudo.
    extraGroups = [ "wheel" "minecraft" ];
    # Without a password luke could not sudo (wheel needs one) and the Vultr
    # web console would be unusable, since root login is disabled everywhere —
    # a key-only box with no recovery path.
    hashedPasswordFile = config.sops.secrets."luke-hashed-password".path;
  };

  # neededForUsers lands the hash in /run/secrets-for-users, which is populated
  # before users are created; a plain secret would be too late.
  sops.secrets."luke-hashed-password" = {
    sopsFile = ../../secrets/nixcraft/users.yaml;
    key = "luke_hashed_password";
    neededForUsers = true;
  };

  # The JVM heap must never be swapped — a paged-out heap turns a GC pause
  # into a multi-second freeze for everyone online. Swap exists only as an
  # OOM backstop, so make the kernel reach for it as late as possible.
  boot.kernel.sysctl."vm.swappiness" = 10;

  boot.tmp.cleanOnBoot = true;

  environment.systemPackages = with pkgs; [
    zstd
  ];

  system.stateVersion = "26.05";
}
