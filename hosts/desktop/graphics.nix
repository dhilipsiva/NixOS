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

  # Generation 10 lost video at the NVIDIA framebuffer takeover: "HDMI FRL
  # link training failed." Blind login still started Hyprland. The Samsung
  # Odyssey G81SF now works at 4K60 in generation 11. Keep the conservative
  # HDMI/TMDS, 8-bit baseline for BOTH the text console and the compositor.
  # These parameters exist in the selected production driver's modeset module.
  # Temporary: retest higher refresh/HDR over a working link before removing.
  # HDMI-A-1 is the NVIDIA connector observed in generation 10, not nouveau's
  # HDMI-A-2 name in recovery. Do not copy these settings onto another host.
  boot.kernelParams = [
    "nvidia-modeset.disable_hdmi_frl=1"
    "nvidia-modeset.hdmi_deepcolor=0"
    "video=HDMI-A-1:3840x2160@60"
  ];

  home-manager.users.dhilipsiva.wayland.windowManager.hyprland.settings.monitor = [
    {
      output = "HDMI-A-1";
      mode = "3840x2160@60";
      position = "auto";
      scale = "auto";
      bitdepth = 8;
      cm = "srgb";
      vrr = 0;
    }
  ];

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
