{ pkgs, ... }:

# Settings shared by every host. Host-specific configuration lives in
# hosts/<name>/configuration.nix.

{
  nixpkgs.config.allowUnfree = true;

  # NixOS ships only /bin/sh, but some tools hardcode an absolute /bin/bash
  # instead of resolving bash from PATH, and fail outright without it.
  # Notably github-copilot-cli: its shell tool spawns "/bin/bash" directly and
  # dies with "Failed to start bash process" on every command.
  #   Upstream bug: https://github.com/github/copilot-cli/issues/3392
  #   (open, still broken as of 1.0.61 — recheck on upgrades and drop this)
  # The usual suggested workaround is services.envfs.enable, but that
  # FUSE-mounts all of /bin and /usr/bin; a single symlink is far less invasive.
  systemd.tmpfiles.rules = [
    "L+ /bin/bash - - - - ${pkgs.bashInteractive}/bin/bash"
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.warn-dirty = false;

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  nix.optimise = {
    automatic = true;
    dates = "weekly";
  };

  time.timeZone = "America/Denver";
  i18n.defaultLocale = "en_US.UTF-8";
}
