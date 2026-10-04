# Captured from the installed desktop's /etc/nixos/hardware-configuration.nix
# and checked against the live hardware and mounted filesystems on 2026-10-03.
# MSI MAG X870E TOMAHAWK WIFI (MS-7E59), AMD Ryzen 9 9950X3D, RTX 5090.
# Linux SSD: XPG MARS 980 BLADE, serial 2P10291S7BAY (4 TB).
# Windows SSD: serial 2P102LAC7BA1; windows.nix mounts its data partition read-only.
# Microcode updates come from nixos-hardware's common-cpu-amd module.
{ lib, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "ahci"
    "thunderbolt"
    "usbhid"
    "usb_storage"
    "sd_mod"
    "sr_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  # Existing unencrypted ext4 root and 1 GiB FAT32 ESP. UUIDs remain stable if
  # the kernel changes NVMe enumeration order. This configuration does not format.
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/664a9ddf-4ff2-47f8-90b5-65d449dfbca7";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/85B9-1188";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
