{ ... }:

# Makes the onboard X520 (82599ES) accept the 10Gtek 1000BASE-BX BiDi modules
# that carry calliope's only network link. Without this the port never gets a
# netdev at all and the machine is unreachable.
#
# The driver is not actually missing BiDi support: ixgbe_sfp_type_1g_bx_core0/1
# exist, ixgbe_82599.c sets the 1 G link capability for them, and ethtool knows
# the types. Everything works. The problem is purely the gate in
# ixgbe_identify_sfp_module_generic():
#
#   (comp_codes_1g & IXGBE_SFF_BASEBX10_CAPABLE) && (bitrate_nominal == 0xD)
#
# These modules are coded for Cisco and report, read off the real EEPROM:
#
#   ident=0x03  comp_1g=0x00  comp_10g=0x00  cable_tech=0x00  bitrate=0x0d
#
# The nominal bitrate is exactly the 0x0D the check wants, but SFF-8472 byte 6
# is left entirely blank — no BX10 bit, no SX/LX/T, no Ethernet compliance
# codes of any kind. So the bit test fails, the module falls through to
# ixgbe_sfp_type_unknown, probe aborts with -EOPNOTSUPP, and no interface is
# created. One unset bit in the vendor's EEPROM coding.
#
# The patch relaxes that branch to accept either a module that claims BX, or
# any non-10G optic running at roughly 1-1.6 GBd. It sits after every standard
# SX/LX/T/DAC/SR/LR test, so it only ever catches modules nothing else claimed.
#
# Verified on the hardware: classified as sfp_type 16 (1g_bx_core1), link up at
# 1 Gbps full duplex, DHCP completed over the fibre, zero rx/tx errors.
#
# NOTE: `allow_unsupported_sfp` does NOT substitute for this. That flag guards
# the Intel vendor-OUI check further down the same function, not the module
# type classification above it.

{
  boot.kernelPatches = [{
    name  = "ixgbe-accept-uncoded-bidi-sfp";
    patch = ./ixgbe-bidi.patch;
  }];

  # Strictly redundant once the module classifies as one of the bx types — the
  # OUI enforcement block explicitly exempts them. Kept because this link is
  # the machine's only route in, and the cost of being wrong is a drive to the
  # console. It also covers swapping in some other third-party optic later.
  boot.kernelParams = [ "ixgbe.allow_unsupported_sfp=1" ];
}
