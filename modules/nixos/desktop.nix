# Wayland desktop session: Hyprland, dconf, polkit, and the keyring.
{ ... }:

{
  programs.hyprland.enable = true;
  programs.dconf.enable = true;

  security.polkit.enable = true;
  services.gnome.gnome-keyring.enable = true;
}
