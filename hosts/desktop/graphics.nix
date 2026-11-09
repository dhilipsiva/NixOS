# Current stable kernel, NVIDIA production driver and 4K display policy for the
# RTX 5090 driving a Samsung Odyssey G81SF over DisplayPort.
{ config, pkgs, ... }:

{
  boot.kernelPackages = pkgs.linuxPackagesFor (import ../../pkgs/kernel.nix { inherit pkgs; });

  # The panel moved from HDMI to DisplayPort on 2026-10-04. Over HDMI the
  # NVIDIA driver failed FRL link training in generation 10 and the display was
  # pinned to 4K60 8-bit by kernel parameters; DisplayPort 1.4 with DSC reaches
  # the panel's full 3840x2160 at 240 Hz with 10-bit colour, so that workaround
  # is gone. HDR (the panel advertises HDR10/HLG) stays a separate future test.
  #
  # The 700 mm wide 4K panel needs 150 % scaling for legible UI: 2560x1440
  # logical pixels. Wayland clients scale themselves; Xwayland clients render at
  # native pixels (sharp but smaller) because of xwayland.force_zero_scaling.
  # VRR 2 = adaptive sync only while a fullscreen window is shown.
  #
  # The rule matches the panel's EDID description, not its connector: the NVIDIA
  # driver names the same port DP-1 on some boots and DP-4 on others, and a
  # missed DP-1 rule fell back to the shared "auto" rule (scale 1 at about
  # 138 PPI, 60 Hz, 8-bit), which made the UI look randomly shrunken.
  home-manager.users.dhilipsiva.wayland.windowManager.hyprland.settings = {
    monitor = [
      {
        output = "desc:Samsung Electric Company Odyssey G81SF";
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
  # The compositor uses only the GPU wired to the panel, so Hyprland can use
  # hardware cursors instead of software ones. AQ_DRM_DEVICES is a colon-separated
  # list, which rules out the by-path names (they contain colons; generation 16
  # aborted on that), so udev publishes a colon-free alias for the NVIDIA card
  # by PCI address.
  services.udev.extraRules = ''
    KERNEL=="card*", KERNELS=="0000:01:00.0", SUBSYSTEM=="drm", SUBSYSTEMS=="pci", SYMLINK+="dri/desktop-nvidia"
  '';
  environment.sessionVariables.AQ_DRM_DEVICES = "/dev/dri/desktop-nvidia";
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
