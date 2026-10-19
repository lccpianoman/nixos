{ ... }:

# The `storage` pool: the twelve 10 TB SAS disks as a single raidz2 vdev, plus
# the datasets, permissions and maintenance timers that go with it.
#
# The pool and its datasets are NOT declared here. They are created once by
# hand — see README's "Storage pool" section — and that is deliberate:
# hosts/calliope/disko.nix covers only the boot NVMe, so a
# `disko --mode destroy,format,mount` run can never reach these twelve disks.
# Describing them in Nix would trade that standing guarantee for a convenience
# used exactly once.

{
  boot.supportedFilesystems.zfs = true;

  # Becomes the default in 26.11, and warns until set. calliope has no ZFS root
  # pool at all, so forcing one past a hostid mismatch could only ever paper
  # over a pool that another machine still thinks it owns.
  boot.zfs.forceImportRoot = false;

  # Every dataset is mountpoint=legacy and mounted from here rather than by
  # zfs-mount.service. systemd.targets.zfs is only `wantedBy` multi-user.target,
  # never ordered before it, so ZFS-native mounts race the services that read
  # them and a service can start and write into the bare mountpoint. Declaring
  # them makes zfs-import-storage.service a real `before`/`requiredBy` of each
  # generated .mount unit, and lets services add RequiresMountsFor.
  #
  # nofail on all four on purpose: calliope is fibre-only and its recovery path
  # is a physical console, so an unimportable pool must never hold up boot.
  # Services that need the data fail individually instead, which is visible
  # over SSH; a boot that hangs on local-fs.target is not.
  fileSystems =
    let
      dataset = device: {
        inherit device;
        fsType  = "zfs";
        options = [ "nofail" ];
      };
    in {
      "/srv/media"     = dataset "storage/media";
      "/srv/photos"    = dataset "storage/photos";
      "/srv/documents" = dataset "storage/documents";
      "/srv/backups"   = dataset "storage/backups";
    };

  # One group for everything that touches the libraries: luke now, the service
  # users later. The gid is pinned because NFS puts numeric ids on the wire —
  # an auto-allocated gid that differs between hosts silently denies writes.
  users.groups.media.gid = 3000;

  # setgid (2775) so new files inherit the media group whoever wrote them, which
  # is what lets luke and the services share one tree without chowning. Re-run
  # every boot, so a service that chmods something has it corrected.
  #
  # These land on the root filesystem if the pool failed to mount. Harmless —
  # they stay empty, because nothing writes without RequiresMountsFor passing.
  systemd.tmpfiles.rules = [
    "d /srv/media                      2775 luke media -"
    "d /srv/media/library              2775 luke media -"
    "d /srv/media/library/movies       2775 luke media -"
    "d /srv/media/library/shows        2775 luke media -"
    "d /srv/media/library/music        2775 luke media -"
    "d /srv/media/downloads            2775 luke media -"
    "d /srv/media/downloads/incomplete 2775 luke media -"
    "d /srv/media/downloads/complete   2775 luke media -"
    "d /srv/photos                     2775 luke media -"
    "d /srv/documents                  2775 luke media -"
    "d /srv/backups                    0770 luke media -"
  ];

  # Monthly. A scrub reads every allocated block, so on a loaded 91 TiB pool it
  # runs for most of a day — weekly would leave it scrubbing a third of the time.
  services.zfs.autoScrub.enable = true;

  # Defaults to true, which is for SSDs. `zpool trim` errors out on all twelve
  # SAS spindles, so the weekly timer would only ever produce failure mail.
  services.zfs.trim.enable = false;

  services.zfs.zed.settings = {
    ZED_NOTIFY_VERBOSE = true;
    # The R720xd backplane does not present SES through the SAS3008
    # (/sys/class/enclosure is empty), so ZED cannot blink a failed disk.
    # Identify a replacement by serial instead — see README.
    ZED_USE_ENCLOSURE_LEDS = false;
  };

  # Snapshots are the only thing standing between a misconfigured *arr and the
  # library, and on write-once media they cost almost nothing. They are not a
  # backup: a pool-wide failure takes the snapshots with it.
  services.sanoid = {
    enable = true;
    datasets = {
      # downloads/ lives in this dataset so hardlinks work, which means
      # snapshots also pin deleted partial torrents until they age out.
      "storage/media"     = { daily = 7;  monthly = 2;  autosnap = true; autoprune = true; };
      "storage/photos"    = { daily = 14; monthly = 6;  autosnap = true; autoprune = true; };
      "storage/documents" = { hourly = 24; daily = 30; monthly = 12; autosnap = true; autoprune = true; };
      # Restic and borg already version their own contents; these snapshots
      # exist so a compromised client cannot prune the repo it backs up to.
      "storage/backups"   = { daily = 7;  monthly = 3;  autosnap = true; autoprune = true; };
    };
  };
}
