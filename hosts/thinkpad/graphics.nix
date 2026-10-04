{ config, inputs, pkgs, ... }:

let
  driverPackages = import inputs.nixpkgs-apps {
    inherit (pkgs.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };
in {
  boot.kernelPackages = pkgs.linuxPackagesFor (import ../../pkgs/kernel.nix { inherit pkgs; });
  services.xserver.videoDrivers = [ "nvidia" ];
  services.udev.extraRules = ''
    KERNEL=="card*", KERNELS=="0000:00:02.0", SUBSYSTEM=="drm", SUBSYSTEMS=="pci", SYMLINK+="dri/thinkpad-intel"
    KERNEL=="card*", KERNELS=="0000:01:00.0", SUBSYSTEM=="drm", SUBSYSTEMS=="pci", SYMLINK+="dri/thinkpad-nvidia"
  '';
  environment.sessionVariables.AQ_DRM_DEVICES = "/dev/dri/thinkpad-intel:/dev/dri/thinkpad-nvidia";
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = [ pkgs.intel-media-driver ];
  };
  hardware.nvidia = {
    open = true;
    modesetting.enable = true;
    powerManagement.enable = true;
    nvidiaSettings = true;
    package = (driverPackages.linuxPackagesFor config.boot.kernelPackages.kernel).nvidiaPackages.production;
    prime = {
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
      offload = { enable = true; enableOffloadCmd = true; };
    };
  };
}
