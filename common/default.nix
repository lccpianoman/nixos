{ ... }:

# Settings shared by every host. Host-specific configuration lives in
# hosts/<name>/configuration.nix.

{
  nixpkgs.config.allowUnfree = true;

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
