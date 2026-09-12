{ config, lib, pkgs, ... }:

let
  theme = import ./theme.nix;
  constants = import ./constants.nix;
  c = theme.colors;
  fontUI = theme.fontUI;
in
{
  imports = [
    ../../common
    ./hardware-configuration.nix
  ];

  # ===== System =====

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

    # SwayFX 0.6 (animations, rebased on sway 1.12) needs scenefx 0.5; nixpkgs
    # 26.05 ships 0.5.3/0.4.1. wlroots_0_20 is already in 26.05, so both need
    # only a src bump. Delete once nixpkgs reaches these versions.
    (final: prev: {
      scenefx =
        let custom = (prev.scenefx.override { wlroots_0_19 = final.wlroots_0_20; })
          .overrideAttrs (old: rec {
            version = "0.5";
            src = final.fetchFromGitHub {
              owner = "wlrfx";
              repo = "scenefx";
              tag = version;
              hash = "sha256-vUjLG6eubEhJJVa9LPygIcVmNoHwYbSUTJcWEcbxnU4=";
            };
            buildInputs = old.buildInputs ++ [ final.lcms2 ];
          });
        in if final.lib.versionOlder prev.scenefx.version custom.version
           then custom
           else prev.scenefx;

      swayfx-unwrapped =
        let custom = (prev.swayfx-unwrapped.override { wlroots_0_19 = final.wlroots_0_20; })
          .overrideAttrs (_: rec {
            version = "0.6";
            src = final.fetchFromGitHub {
              owner = "wlrfx";
              repo = "swayfx";
              tag = version;
              hash = "sha256-yvVqwgKEZt/JbT4cxyRA95oK1t/KcZ2AvI5/o7gYa0M=";
            };
          });
        in if final.lib.versionOlder prev.swayfx-unwrapped.version custom.version
           then custom
           else prev.swayfx-unwrapped;
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
    # No IPv6 on this LAN (link-local only, no default route), but DNS still
    # returns AAAA records. Apps then get IPv6-only answers and fail instantly
    # with "network unreachable". Off means getaddrinfo only hands out IPv4.
    enableIPv6 = false;
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

  # ===== SSH =====

  # Pin server host keys so a reinstall fails loudly instead of prompting.
  programs.ssh.knownHosts = {
    nixvps = {
      hostNames = [ "nixvps" "[66.228.49.38]:47291" ];
      publicKeyFile = ../../keys/nixvps.host.pub;
    };
    nixcraft = {
      hostNames = [ "nixcraft" "[96.30.206.210]:47291" ];
      publicKeyFile = ../../keys/nixcraft.host.pub;
    };
    # Needed for `git push` over SSH, including the push at the end of ./rebuild.
    "github.com" = {
      hostNames = [ "github.com" ];
      publicKeyFile = ../../keys/github.com.pub;
    };
  };

  # ===== Desktop Environment =====

  programs.sway = {
    enable = true;
    # SwayFX — sway plus blur/shadows/rounded corners/animations.
    package = pkgs.swayfx;
    wrapperFeatures.gtk = true;
  };

  # programs.regreet sets greetd's default_session command itself; it is
  # overridden below, so only the user is set here.
  services.greetd.settings.default_session.user = "greeter";

  # Run the greeter under sway rather than the module's default cage: cage
  # hardcodes its cursor (`wlr_xcursor_manager_create(NULL, XCURSOR_SIZE)`) and
  # ignores XCURSOR_*, and wlroots' xcursor honours neither XCURSOR_THEME nor
  # theme inheritance. sway sets the seat cursor explicitly, and it is already
  # known to work on this GPU.
  services.greetd.settings.default_session.command =
    let
      greeterConfig = pkgs.writeText "greeter-sway.conf" ''
        seat * xcursor_theme ${theme.cursor.name} ${toString theme.cursor.size}
        output * bg ${constants.wallpaper} fill
        default_border none
        exec "${pkgs.regreet}/bin/regreet; ${pkgs.swayfx}/bin/swaymsg exit"
      '';
    in
    "${pkgs.dbus}/bin/dbus-run-session ${pkgs.swayfx}/bin/sway --config ${greeterConfig}";

  # sway is the greeter compositor now, so it needs the NVIDIA opt-out here too;
  # environment.sessionVariables only covers the logged-in user session.
  systemd.services.greetd.environment.SWAY_UNSUPPORTED_GPU = "true";

  programs.regreet = {
    enable = true;
    font = { name = fontUI.name; package = pkgs.inter; size = 14; };
    # Matches sway's seat cursor and home.pointerCursor so the pointer doesn't
    # change shape between greeter and session.
    cursorTheme = { name = theme.cursor.name; package = pkgs.bibata-cursors; };
    theme = { name = "Adwaita-dark"; package = pkgs.gnome-themes-extra; };

    settings = {
      background = { path = constants.wallpaper; fit = "Cover"; };
      GTK.application_prefer_dark_theme = true;
      appearance.greeting_msg = "Welcome back, Luke";
      widget.clock.format = "%A, %B %d   %H:%M";
    };

    # Nebula palette over the wallpaper: a translucent card, themed entry and
    # buttons, blue focus ring.
    extraCss = ''
      window {
        background: transparent;
      }

      .background {
        background-color: alpha(${c.base}, 0.55);
      }

      box.horizontal > frame,
      frame > box,
      .login-box {
        background-color: alpha(${c.surface}, 0.92);
        border: 1px solid ${c.overlay};
        border-radius: ${toString theme.cornerRadius}px;
        padding: 24px;
      }

      label {
        color: ${c.text};
      }

      entry {
        background-color: ${c.base};
        color: ${c.text};
        border: 1px solid ${c.overlay};
        border-radius: ${toString theme.cornerRadius}px;
        padding: 8px 12px;
      }

      entry:focus, entry:focus-within {
        border-color: ${c.blue};
        box-shadow: 0 0 0 2px alpha(${c.blue}, 0.35);
      }

      button {
        background-image: none;
        background-color: ${c.overlay};
        color: ${c.text};
        border: 1px solid ${c.overlay};
        border-radius: ${toString theme.cornerRadius}px;
        padding: 8px 16px;
      }

      button:hover {
        background-color: ${c.blue};
        color: ${c.base};
      }

      #clock_label {
        color: ${c.blueLight};
        font-size: 20pt;
      }

      #greeting_label {
        color: ${c.text};
        font-size: 16pt;
      }
    '';
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
    # home-manager's profile sway shadows the NixOS wrapper in PATH, so
    # programs.sway.extraOptions never reaches the session. swayfx 0.6 reads
    # this instead, whichever wrapper launches it.
    SWAY_UNSUPPORTED_GPU      = "true";
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
      # nixpkgs' stable driver (595.71.05) fails to build against kernel 7.2
      # (implicit strncpy in os-interface.c); 595.99.02 has the fix. Self-expires
      # once nixpkgs reaches it — delete this block then.
      package = let
        nv = config.boot.kernelPackages.nvidiaPackages;
        fixed = nv.mkDriver {
          version = "595.99.02";
          sha256_64bit       = "sha256-6HR3lYv3YwcFSTJL1a1slI66btIQ5EAFs+/4SUD24ew=";
          sha256_aarch64     = "sha256-CCqHZTN2KNOZ4yZp2rDcuRJp9pHfRw47k4m4dWnS/2w=";
          openSha256         = "sha256-T36x/jx8yQ8l3LFp1rZIrTfcSwbGy8YSAvXOUSptpb4=";
          settingsSha256     = "sha256-GYCcnxfKPrTCrsmd25sMyzfC5cqJQJx0c31haooyTYM=";
          persistencedSha256 = "sha256-VyKtF/HdHPQrHHK6opSO69M72LmnGZtauuchj9uuje8=";
        };
      in if lib.versionOlder nv.stable.version fixed.version then fixed else nv.stable;
    };
  };

  # ===== Fonts =====

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
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
