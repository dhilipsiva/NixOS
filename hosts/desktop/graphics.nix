# Current stable kernel, NVIDIA production driver and 4K display policy for the
# RTX 5090 driving a Samsung Odyssey G81SF over DisplayPort.
{ config, pkgs, ... }:

{
  boot.kernelPackages = pkgs.linuxPackagesFor (import ../../pkgs/kernel.nix { inherit pkgs; });

  # The panel moved from HDMI to DisplayPort (DP-1) on 2026-10-04. Over HDMI the
  # NVIDIA driver failed FRL link training in generation 10 and the display was
  # pinned to 4K60 8-bit by kernel parameters; DisplayPort 1.4 with DSC reaches
  # the panel's full 3840x2160 at 240 Hz with 10-bit colour, so that workaround
  # is gone. HDR (the panel advertises HDR10/HLG) stays a separate future test.
  #
  # The 700 mm wide 4K panel needs 150 % scaling for legible UI: 2560x1440
  # logical pixels. Wayland clients scale themselves; Xwayland clients render at
  # native pixels (sharp but smaller) because of xwayland.force_zero_scaling.
  # VRR 2 = adaptive sync only while a fullscreen window is shown.
  home-manager.users.dhilipsiva.wayland.windowManager.hyprland.settings = {
    monitor = [
      {
        output = "DP-1";
        mode = "3840x2160@240";
        position = "auto";
        scale = 1.5;
        bitdepth = 10;
        cm = "srgb";
        vrr = 2;
      }
    ];
    # Fullscreen games may scan out directly, skipping the compositor pass.
    config.render.direct_scanout = 2;
  };
  # The compositor uses only the GPU wired to the panel. Addressing it by PCI
  # path keeps the choice stable across card numbering, and a single DRM device
  # lets Hyprland use hardware cursors instead of software ones.
  environment.sessionVariables.AQ_DRM_DEVICES = "/dev/dri/by-path/pci-0000:01:00.0-card";
  # Legible text console and tuigreet login screen at 3840x2160.
  console = {
    font = "${pkgs.terminus_font}/share/consolefonts/ter-132n.psf.gz";
    earlySetup = true;
  };

  hardware.graphics.extraPackages = [ pkgs.nvidia-vaapi-driver ];
  environment.sessionVariables = {
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    LIBVA_DRIVER_NAME = "nvidia";
    NVD_BACKEND = "direct";
  };

  # nixos-hardware's common-gpu-nvidia-nonprime selects the "nvidia" video driver.
  hardware.nvidia = {
    modesetting.enable = true;
    open = true; # Blackwell requires NVIDIA's open kernel modules.
    nvidiaSettings = true;
    powerManagement.enable = false; # Suspend is disabled on this desktop.

    # 26.05's older production driver fails to build against Linux 7.2. Use the
    # current production release from the separately locked package tree that
    # flake.nix instantiates once as pkgs.nixpkgs-apps, built against EXACTLY
    # this host's kernel (not that tree's default kernel).
    # Production excludes NVIDIA's beta and New Feature branches.
    package =
      (pkgs.nixpkgs-apps.linuxPackagesFor config.boot.kernelPackages.kernel).nvidiaPackages.production;
  };
}
