{
  lib,
  pkgs,
  inputs,
  ...
}:
{
  imports = [ inputs.lanzaboote.nixosModules.lanzaboote ];
  boot.loader.systemd-boot.enable = lib.mkForce false;
  # Entry retention, editor and console mode follow boot.loader.systemd-boot.
  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
    autoGenerateKeys.enable = false;
    autoEnrollKeys.enable = false;
    autoEnrollKeys.autoReboot = false;
  };
  environment.systemPackages = [
    pkgs.sbctl
    pkgs.sbsigntool
    pkgs.efitools
  ];
  # VM checks use their own boot chain, never this host's signing identity.
  virtualisation.vmVariant.boot.lanzaboote.enable = lib.mkForce false;
}
