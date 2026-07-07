# This is a generic nixos-generate-config scan and does NOT yet reflect the real
# desktop hardware — regenerate it on the actual machine before a real install
# (`nixos-generate-config --show-hardware-config`), keeping the fileSystems/swap
# removal below.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "thunderbolt" "usbhid" "usb_storage" "sd_mod" "sr_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  # fileSystems."/" , fileSystems."/boot" and swapDevices are now owned by
  # hosts/desktop/disko.nix (declarative partitioning). They were removed here on
  # purpose — keeping the old by-uuid entries alongside disko's generated
  # definitions causes a hard "conflicting definition values" evaluation error.
  # (No swap partition is declared in disko.nix; swap is intentionally omitted.)

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
