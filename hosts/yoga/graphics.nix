{ lib, pkgs, ... }:
{
  boot.kernelPackages = pkgs.linuxPackagesFor (import ../../pkgs/kernel.nix { inherit pkgs; });
  boot.kernelModules = [
    "xe"
    "intel_vpu"
  ];
  services.xserver.videoDrivers = [ "modesetting" ];
  # These overrides affect Yoga alone. OS modules remain on the stable release.
  nixpkgs.overlays = [
    (final: _: {
      inherit (final.nixpkgs-apps) intel-media-driver intel-compute-runtime level-zero;
      intel-npu-compiler = final.callPackage ../../pkgs/intel-npu-compiler.nix { };
      intel-npu-driver = final.nixpkgs-apps.intel-npu-driver.overrideAttrs (old: {
        postFixup = (old.postFixup or "") + ''
          # vcl_symbols.hpp uses an absolute path beside the driver, not the
          # dynamic loader search path. Both compiler libraries must live here.
          ln -s ${final.intel-npu-compiler}/lib/libopenvino_intel_npu_compiler_loader.so $out/lib/
          ln -s ${final.intel-npu-compiler}/lib/libopenvino_intel_npu_compiler.so $out/lib/
        '';
      });
      openvino-npu = final.callPackage ../../pkgs/openvino-npu.nix { };
      npu-smoke = final.callPackage ../../pkgs/npu-smoke.nix { };
      ollama-vulkan = final.callPackage ../../pkgs/ollama-vulkan.nix { };
    })
  ];
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      intel-media-driver
      intel-compute-runtime
      intel-npu-compiler
    ];
    extraPackages32 = [ pkgs.pkgsi686Linux.intel-media-driver ];
  };
  hardware.cpu.intel.npu.enable = true;
  # Prefer the driver release's matching firmware over linux-firmware copies.
  hardware.firmware = lib.mkBefore [ pkgs.intel-npu-driver.firmware ];
  services.udev.extraRules = ''
    SUBSYSTEM=="accel", KERNEL=="accel*", GROUP="render", MODE="0660"
  '';
  # 2880x1800 on a 330 mm wide panel: the default 16-pixel console font is
  # under 2 mm tall. Terminus 12x24 keeps the text console and tuigreet legible.
  console = {
    font = "${pkgs.terminus_font}/share/consolefonts/ter-124n.psf.gz";
    earlySetup = true;
  };
  # The panel is 2880x1800 at about 222 PPI; Hyprland 0.56 picks scale 2 above
  # 200 PPI, so the automatic rule yields 1440x900 logical pixels. Override the
  # scale here (1.5 gives 1920x1200) only after seeing it on the hardware.
  home-manager.users.dhilipsiva.wayland.windowManager.hyprland.settings.monitor = lib.mkForce [
    {
      output = "";
      mode = "preferred";
      position = "auto";
      scale = "auto";
    }
  ];
}
