# Steam, Proton and GameMode for the laptops. A host opts in by importing this
# module (the ThinkPad and the Yoga); the desktop does not have Steam. GPU
# selection stays in the host: the ThinkPad overrides programs.steam.package
# for PRIME offload, the Yoga's single Intel GPU needs nothing.
{ pkgs, ... }:
{
  programs.steam = {
    enable = true;
    # GE-Proton alongside Valve's Proton, for titles that need its extra media
    # codecs and fixes; select it per game under Properties > Compatibility.
    extraCompatPackages = [ pkgs.proton-ge-bin ];
    # gamemoderun inside Steam's FHS environment for `gamemoderun %command%`.
    extraPackages = [ pkgs.gamemode ];
    protontricks.enable = true;
    # Steam Input on Wayland: X11 input events become uinput events.
    extest.enable = true;
  };
  programs.gamescope.enable = true;
  programs.gamemode = {
    enable = true;
    settings.general.renice = 10;
  };
  users.users.dhilipsiva.extraGroups = [ "gamemode" ];
  # Wine's NT synchronization driver, which Proton 10+ and GE-Proton use when
  # /dev/ntsync exists; the active seat's user gets access.
  boot.kernelModules = [ "ntsync" ];
  services.udev.extraRules = ''
    KERNEL=="ntsync", TAG+="uaccess"
  '';
}
