# Current stable kernel and NVIDIA production driver for the RTX 5090.
{ config, inputs, pkgs, ... }:

let
  driverPackages = import inputs.nixpkgs-apps {
    inherit (pkgs.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };
in
{
  boot.kernelPackages = pkgs.linuxPackagesFor (import ../../pkgs/kernel.nix { inherit pkgs; });
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.graphics.extraPackages = [ pkgs.nvidia-vaapi-driver ];
  environment.sessionVariables = {
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    LIBVA_DRIVER_NAME = "nvidia";
    NVD_BACKEND = "direct";
  };

  hardware.nvidia = {
    modesetting.enable = true;
    open = true; # Blackwell requires NVIDIA's open kernel modules.
    nvidiaSettings = true;
    powerManagement.enable = false; # Suspend is disabled on this desktop.

    # 26.05's older production driver fails to build against Linux 7.2. Use the
    # current production release from the separately locked package input, built
    # against EXACTLY this host's kernel (not that input's default kernel).
    # Production excludes NVIDIA's beta and New Feature branches.
    package = (driverPackages.linuxPackagesFor config.boot.kernelPackages.kernel).nvidiaPackages.production;
  };
}
