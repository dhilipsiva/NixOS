# Fonts required by the migrated dotfiles (alacritty = Fira Code; waybar = Font
# Awesome + Nerd Font glyphs). The pre-migration active config shipped no fonts;
# these are added so the ported configs actually render.
{ pkgs, ... }:

{
  fonts.packages = with pkgs; [
    fira-code
    nerd-fonts.fira-code # Nerd Font glyphs (waybar / terminal icons)
    font-awesome # waybar module icons
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
  ];
}
