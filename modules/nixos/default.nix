# Aggregator: imports every concern-split system module so a host can include
# the whole shared system config with one `./modules/nixos` entry. lucy.nix is
# opt-in: the desktop and the Yoga import it beside their host modules.
{ ... }:

{
  imports = [
    ./nix.nix
    ./maintenance.nix
    ./locale.nix
    ./sops.nix
    ./users.nix
    ./audio.nix
    ./desktop.nix
    ./networking.nix
    ./virtualisation.nix
    ./ollama.nix
    ./hardware.nix
    ./packages.nix
    ./fonts.nix
  ];
}
