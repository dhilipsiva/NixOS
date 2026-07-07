# Nix daemon settings, garbage collection, and nixpkgs config.
{ ... }:

{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.gc = {
    automatic = true;
    dates = "daily";
    options = "--delete-older-than 7d";
  };
  nixpkgs.config = {
    allowUnfree = true;
    android_sdk.accept_license = true;
  };
}
