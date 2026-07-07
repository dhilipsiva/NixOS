# Wayland desktop dotfiles — waybar + hyprland.
#
# These are kept as SOURCE BRIDGES (verbatim copies of the existing .config
# files) rather than translated to native home-manager options, because both
# contain Font Awesome PUA glyphs (waybar module icons) and hand-tuned config
# that is fragile to retype. Native translation (`programs.waybar.settings` /
# `wayland.windowManager.hyprland.settings`) + pruning the laptop-era waybar
# modules (battery / battery#bat2 / backlight) is deferred to a later pass once
# a green VM boot confirms the bridge. See TODO.md Phase 3 / CLEANUP.md.
{ ... }:

{
  xdg.configFile."waybar/config".source = ../../.config/waybar/config;
  xdg.configFile."waybar/style.css".source = ../../.config/waybar/style.css;

  # hyprland session is enabled system-wide (programs.hyprland in
  # modules/nixos/desktop.nix); this just supplies the user config file.
  xdg.configFile."hypr/hyprland.conf".source = ../../.config/hypr/hyprland.conf;
}
