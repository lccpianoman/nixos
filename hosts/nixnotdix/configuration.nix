{ pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  # ===== System =====

  nixpkgs.config.allowUnfree = true;
  nixpkgs.overlays = [
    (final: prev: {
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
    kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];
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
    extraGroups = [ "wheel" "networkmanager" "video" "input" ];
  };

  # ===== Desktop Environment =====

  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
  };

  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = let
          theme = import ./theme.nix;
          c = theme.colors;
        in ''
          ${pkgs.tuigreet}/bin/tuigreet \
            --time \
            --remember \
            --cmd "sway --unsupported-gpu" \
            --theme "border=${c.blue};text=${c.text};prompt=${c.gold};time=${c.blueLight};action=${c.purple};button=${c.blue};container=${c.surface};input=${c.text}"
        '';
        user = "greeter";
      };
    };
  };

  security.pam.services.swaylock = {};
  security.rtkit.enable = true;
  security.polkit.enable = true;

  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };

  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # ===== Wayland / NVIDIA =====

  environment.sessionVariables = {
    NIXOS_OZONE_WL    = "1";
    GBM_BACKEND       = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    WLR_NO_HARDWARE_CURSORS   = "1";
    MOZ_ENABLE_WAYLAND        = "1";
  };

  services.xserver.videoDrivers = [ "nvidia" ];

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
    nerd-fonts.caskaydia-cove
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
