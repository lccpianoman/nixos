{ pkgs, ... }:

# fanctl: temperatures, fan speeds and an auto/manual fan switch for the
# dashboard, talking to the iDRAC8 over in-band IPMI (/dev/ipmi0) — the iDRAC
# needs no network for this. Served on localhost and reached at
# https://dash.jukeluke.com/fans/ (caddy.nix), iframed into the dashboard.
#
# Manual mode switches the iDRAC's thermal control off entirely, so fanctl
# watches every sensor and hands back to auto the moment any reaches "hot",
# or a CPU or drive reading goes missing. Bands (°C, upper bounds of cool /
# normal / warm / hot; above is danger) live in fans/fanctl.py:
#   inlet    18 27 32 38   ASHRAE recommends 18–27; the iDRAC warns at 42
#   exhaust  35 45 55 65   normally inlet + 10–20; the iDRAC warns at 70
#   cpu      50 70 80 90   E5-2690 v4 throttles at 93 (coretemp "high")
#   hdd      30 40 45 50   HUH721010AL4200 is rated to 60; wear climbs past ~45
#   nvme     40 55 65 70   970 EVO Plus is rated to 70 and throttles there
#
# Also toggles the iDRAC's extra cooling for non-Dell PCIe cards — the NVMe
# adapter is one, and it holds Auto near 8,500 RPM. That setting lives in the
# iDRAC and outlasts fanctl; while it is off, "hot" turns it back on.

let
  port = 8085;
in
{
  boot.kernelModules = [ "ipmi_si" "ipmi_devintf" ];

  environment.systemPackages = [ pkgs.ipmitool ];

  systemd.services.fanctl = {
    description = "Fan control and temperatures over IPMI";
    wantedBy    = [ "multi-user.target" ];
    after       = [ "systemd-modules-load.service" ];

    environment = {
      FANCTL_IPMITOOL = "${pkgs.ipmitool}/bin/ipmitool";
      FANCTL_SMARTCTL = "${pkgs.smartmontools}/bin/smartctl";
      FANCTL_PAGE     = "${./fans/index.html}";
      FANCTL_PORT     = toString port;
    };

    serviceConfig = {
      ExecStart = "${pkgs.python3}/bin/python3 ${./fans/fanctl.py}";
      # Never leave the fans pinned at a manual speed with nothing watching.
      ExecStopPost = "${pkgs.ipmitool}/bin/ipmitool raw 0x30 0x30 0x01 0x01";
      Restart      = "always";
      RestartSec   = 5;
      StateDirectory = "fanctl";

      # Root for /dev/ipmi0 (0600 root) and SCSI log pages over SG_IO.
      CapabilityBoundingSet = [ "CAP_SYS_RAWIO" ];
      DevicePolicy = "closed";
      DeviceAllow  = [ "char-ipmidev rw" "block-sd r" ];
      NoNewPrivileges  = true;
      ProtectSystem    = "strict";
      ProtectHome      = true;
      PrivateTmp       = true;
      ProtectKernelTunables = true;
      ProtectControlGroups  = true;
      RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
      SystemCallArchitectures = "native";
    };
  };
}
