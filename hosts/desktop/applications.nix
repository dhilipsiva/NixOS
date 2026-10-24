# Roblox through Sober (Flathub, user scope) with a launcher entry, as on the
# ThinkPad and the Yoga. Flatpak installs the NVIDIA runtime that matches the
# running driver; `nixosctl stage` requires both before the next boot.
{ pkgs, ... }:
{
  services.flatpak.enable = true;
  home-manager.users.dhilipsiva = {
    xdg.desktopEntries.roblox-sober = {
      name = "Roblox (Sober)";
      comment = "Play Roblox using Sober";
      exec = "${pkgs.flatpak}/bin/flatpak run org.vinegarhq.Sober %u";
      icon = "org.vinegarhq.Sober";
      terminal = false;
      categories = [ "Game" ];
      settings.Keywords = "Roblox;Sober;";
    };
  };
}
