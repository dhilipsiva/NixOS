# Fonts. QUINE, the site's design system, sets the desktop's type (lib/quine.nix): IBM Plex
# Mono is its voice, Plex Sans is for reading, Space Grotesk for display. Waybar's icons
# are Nerd Font glyphs from the symbols-only font. Fira Code stays installed for app
# settings kept outside this repository; nothing here uses it.
{ pkgs, ... }:

let
  quine = import ../../lib/quine.nix;
in
{
  fonts.packages = with pkgs; [
    ibm-plex
    space-grotesk
    nerd-fonts.symbols-only
    fira-code
    nerd-fonts.fira-code
    font-awesome # waybar module icons
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
  ];

  fonts.fontconfig.defaultFonts = {
    sansSerif = [ quine.font.sans ];
    serif = [ quine.font.serif ];
    monospace = [ quine.font.mono ];
    emoji = [ "Noto Color Emoji" ];
  };
}
