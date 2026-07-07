# Peripheral hardware (drawing tablet).
{ ... }:

{
  hardware.opentabletdriver = {
    enable = true;
    daemon.enable = true;
  };
}
