{ ... }:

# Exports /srv/media to the LAN. nixnotdix is the only client; everything else
# is expected to reach the libraries over HTTP through the services.

{
  services.nfs.server = {
    enable = true;
    # root_squash and a subnet restriction do the real work here — AUTH_SYS
    # trusts whatever uid the client sends, so this export is only as safe as
    # the LAN. Anything beyond it should go through a tunnel, not a wider CIDR.
    #
    # `mountpoint` is the required companion to the `nofail` mounts in zfs.nix:
    # without it, a pool that failed to import leaves nfsd exporting the bare
    # tmpfiles-created directory on the root NVMe, and clients write into the
    # OS disk thinking they are writing to 91 TiB of raidz2. With it, the export
    # simply does not happen unless the dataset is really mounted there.
    exports = ''
      /srv/media 192.168.0.0/24(rw,sync,no_subtree_check,root_squash,mountpoint)
    '';
  };

  # v4 only, which is the whole reason the firewall below needs one port: v3
  # drags in mountd, statd and lockd on ports that move unless each is pinned.
  # rpcbind still runs (the NixOS module forces it on) but nothing reaches it.
  services.nfs.settings.nfsd = {
    vers3 = false;
    udp   = false;
  };

  networking.firewall.allowedTCPPorts = [ 2049 ];
}
