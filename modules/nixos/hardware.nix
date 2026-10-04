# Shared peripheral and firmware services. GPU, display and power policy belong
# to each host.
{ ... }:

{
  hardware.opentabletdriver = {
    enable = true;
    daemon.enable = true;
  };

  # Firmware updates from LVFS: `fwupdmgr get-updates` lists them; nothing is
  # applied without an explicit `fwupdmgr update`.
  services.fwupd.enable = true;

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  # Tray applet and pairing UI; UWSM starts its XDG autostart entry.
  services.blueman.enable = true;
}
