# Immich: photo/video backup for the phones, each account backing up over the
# LAN via the mobile app. localhost-only, reached at photos.jukeluke.com
# through caddy.nix — LAN-only on purpose: the app queues new photos while
# away and uploads when back on home wifi, and keeping it off the WAN keeps
# the whole library's auth surface off it too.
#
# mediaLocation is /srv/photos/immich, NOT /srv/photos. Immich's store is
# private — the module enforces immich:immich 0700 on it via its own tmpfiles
# rule, which would fight zfs.nix's `2775 luke media` if pointed at the
# dataset root. The parent stays luke/media so one-off dumps (iCloud takeout
# for immich-cli import) can sit beside it in /srv/photos/archive; 2775 gives
# the immich user the r-x it needs to traverse.
#
# The module brings its own postgres (with vectorchord) and a redis instance,
# both on unix sockets. Machine learning (face/object recognition, smart
# search) runs CPU-only on the R730xd — the first pass over a big import is
# slow and that is fine.
{ lib, ... }:
#
# This nixpkgs carries immich 2.7.5, marked insecure because the 2.x branch is
# EOL (3.x arrives with nixpkgs 26.11) and carries CVE-2026-59258 and
# CVE-2026-82272. Both need an *authenticated account* abusing shared-album
# roles or share-link visibility — with two trusted accounts on a LAN-only
# service, neither is reachable. Permitted explicitly rather than silenced
# globally, and tracked in AGENTS.md's pins table: drop the permit and let the
# module take stock immich once nixpkgs has >= 3.0.3.
{
  nixpkgs.config.permittedInsecurePackages = [ "immich-2.7.5" ];

  services.immich = {
    enable = true;
    # Explicit even though it's the default: 2283 is caddy.nix's upstream and
    # a silent default bump in the module would otherwise strand the vhost.
    port = 2283;
    mediaLocation = "/srv/photos/immich";
  };

  # The module only *adjusts* mediaLocation (tmpfiles type `e` — never
  # creates); a non-default location is expected to be made by hand. Replace
  # its entry with a creating `d` rule instead — mkForce rather than a second
  # rule for the same path, which tmpfiles would warn about and ignore. Same
  # caveat as the zfs.nix rules: lands on the NVMe if the pool failed to
  # mount, harmless because RequiresMountsFor keeps immich from writing there.
  systemd.tmpfiles.settings.immich."/srv/photos/immich" = lib.mkForce {
    d = {
      user  = "immich";
      group = "immich";
      mode  = "0700";
    };
  };

  # Same guard every /srv service carries: the ZFS mounts are nofail, and the
  # module's own tmpfiles rule would recreate mediaLocation on the bare NVMe
  # if the pool failed to import — then uploads land on the OS disk until it
  # fills. With this, immich just fails visibly instead.
  systemd.services.immich-server.unitConfig.RequiresMountsFor = [ "/srv/photos" ];
}
