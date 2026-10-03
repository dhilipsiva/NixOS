{ lib, pkgs, inputs, ... }:
{
  imports = [ inputs.lanzaboote.nixosModules.lanzaboote ];
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
    configurationLimit = 5;
    autoGenerateKeys.enable = false;
    autoEnrollKeys.enable = false;
    autoEnrollKeys.autoReboot = false;
  };
  environment.systemPackages = [ pkgs.sbctl pkgs.sbsigntool pkgs.efitools ];
  # VM checks use their own boot chain, never this host's signing identity.
  virtualisation.vmVariant.boot.lanzaboote.enable = lib.mkForce false;
}
