{ pkgs, ... }:

{
  imports = [
    ../../common
    ./hardware-configuration.nix
  ];

  # ===== System =====

  nixpkgs.config.permittedInsecurePackages = [
    "pnpm-10.29.2" # build-time dep of claude-code; CVEs don't apply in Nix sandbox
  ];
  # Local Clone Hero build until nixpkgs catches up (still 1.1.0.6085 as of
  # 2026-07). Version lives only in pkgs/clonehero.nix; once nixpkgs reaches
  # it this overlay is a no-op — delete it and pkgs/clonehero.nix then.
  nixpkgs.overlays = [
    (final: prev: {
      clonehero =
        let custom = final.callPackage ./pkgs/clonehero.nix { };
        in if final.lib.versionOlder prev.clonehero.version custom.version
           then custom
           else prev.clonehero;
    })
  ];

  # Release this host was first installed with — pins on-disk data formats.
  # Intentionally NOT bumped when nixpkgs moves (currently 26.05); only
  # change after reading that release's stateVersion migration notes.
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
    # GTA V Online under Proton: blocking these BattlEye endpoints is what
    # lets the game connect to Online without being kicked. Removing them
    # breaks GTA Online on this box.
    hosts."0.0.0.0" = [
      "paradise-s1.battleye.com"
      "test-s1.battleye.com"
      "paradiseenhanced-s1.battleye.com"
    ];
  };

  # ===== Localization =====

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
    wireplumber.enable = true;
  };

  xdg.portal = {
    enable = true;
    wlr.enable = true;
    # xdpw runs as a user service and does not see Home Manager's PATH.
    wlr.settings.screencast = {
      max_fps = 60;
      chooser_type = "dmenu";
      chooser_cmd = "${pkgs.fuzzel}/bin/fuzzel -d -l 10 --minimal-lines --no-exit-on-keyboard-focus-loss -p 'Select a source to share:'";
    };
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common = {
      default = [ "gtk" ];
      "org.freedesktop.impl.portal.ScreenCast" = [ "wlr" ];
      "org.freedesktop.impl.portal.Screenshot" = [ "wlr" ];
    };
  };

  # ===== Wayland / NVIDIA =====

  environment.sessionVariables = {
    NIXOS_OZONE_WL    = "1";
    GBM_BACKEND       = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    WLR_NO_HARDWARE_CURSORS   = "1";
    MOZ_ENABLE_WAYLAND        = "1";
    QT_QPA_PLATFORM                  = "wayland";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    GDK_BACKEND                      = "wayland,x11";
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
    nerd-fonts.roboto-mono
    inter
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
