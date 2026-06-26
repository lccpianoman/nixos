{ pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  # ===== System =====

  nixpkgs.config.allowUnfree = true;
  nixpkgs.overlays = [
    (final: prev: {
      # Use locally-packaged clonehero until nixpkgs reaches 1.1.0.6142.
      # Remove ./pkgs/clonehero.nix once this condition is no longer true.
      clonehero =
        if final.lib.versionOlder prev.clonehero.version "1.1.0.6142"
        then final.callPackage ./pkgs/clonehero.nix {}
        else prev.clonehero;
    })
  ];
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.warn-dirty = false;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  system.stateVersion = "25.11";

  # ===== Boot =====

  boot = {
    loader.systemd-boot.enable = true;
    loader.systemd-boot.configurationLimit = 5;
    loader.efi.canTouchEfiVariables = true;
    kernelPackages = pkgs.linuxPackages_zen;
  };

  # ===== Networking =====

  networking = {
    hostName = "nixnotdix";
    networkmanager.enable = true;
    hosts."0.0.0.0" = [
      "paradise-s1.battleye.com"
      "test-s1.battleye.com"
      "paradiseenhanced-s1.battleye.com"
    ];
  };

  # ===== Localization =====

  time.timeZone = "America/Denver";
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };

  # ===== Users =====

  users.users.luke = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
  };

  # ===== Desktop Environment =====

  services = {
    xserver = {
      enable = true;
      videoDrivers = [ "nvidia" ];
      windowManager.bspwm.enable = true;
      displayManager.lightdm.enable = true;
    };
    displayManager.defaultSession = "none+bspwm";
    pipewire = {
      enable = true;
      pulse.enable = true;
    };
  };

  security.rtkit.enable = true;

  # ===== Graphics =====

  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;
    };
    nvidia = {
      modesetting.enable = true;
      open = false;
      nvidiaSettings = true;
    };
  };

  # ===== Fonts =====

  fonts.packages = with pkgs; [
    nerd-fonts.hack
    dejavu_fonts
  ];

  # ===== Gaming =====

  programs.steam.enable = true;
  programs.steam.protontricks.enable = true;
  programs.gamemode.enable = true;
  programs.noisetorch.enable = true;

  systemd.settings.Manager.DefaultLimitNOFILE = 1048576;

  # ===== System Packages =====

  programs.nix-ld.enable = true;

  environment.systemPackages = with pkgs; [
    vim
    wget
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-plugins-ugly
    libvdpau
  ];
}
