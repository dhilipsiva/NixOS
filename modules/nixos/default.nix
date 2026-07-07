# Aggregator: imports every concern-split system module so a host can include
# the whole shared system config with one `./modules/nixos` entry.
{ ... }:

{
  imports = [
    ./nix.nix
    ./locale.nix
    ./sops.nix
    ./users.nix
    ./audio.nix
    ./desktop.nix
    ./networking.nix
    ./virtualisation.nix
    ./hardware.nix
    ./packages.nix
    ./environment.nix
    ./fonts.nix
  ];
}
