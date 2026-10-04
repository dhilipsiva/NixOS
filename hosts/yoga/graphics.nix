{ lib, pkgs, ... }:
{
  boot.kernelPackages = pkgs.linuxPackagesFor (import ../../pkgs/kernel.nix { inherit pkgs; });
  boot.kernelModules = [
    "xe"
    "intel_vpu"
  ];
  services.xserver.videoDrivers = [ "modesetting" ];
  # These overrides affect Yoga alone. OS modules remain on the stable release.
  # The media and compute runtimes stay on the release branch: master's
  # intel-media-driver 26.2.4 exports __vaDriverInit_1_24 for a libva 2.24 that
  # 26.05 does not ship (vainfo failed), and master's intel-compute-runtime
  # 26.31 aborted in command_stream_receiver.cpp on clinfo. The release builds
  # (26.1.6 and 26.18.38308.1) were verified on the Arc 140V on 2026-10-04:
  # H.264/HEVC/VP9/AV1 decode, H.264/HEVC/AV1 encode and OpenCL enumeration.
  # level-zero follows nixpkgs-apps because the NPU driver, its compiler and
  # openvino-npu are built against that loader; a newer loader with the older
  # GPU driver is the supported direction. The compute runtime keeps the
  # release level-zero as its build input so it is exactly the binary-cached
  # derivation that was tested, not a local rebuild against newer headers.
  nixpkgs.overlays = [
    (final: prev: {
      inherit (final.nixpkgs-apps) level-zero;
      intel-compute-runtime = prev.intel-compute-runtime.override { inherit (prev) level-zero; };
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
  # 200 PPI (1440x900 logical pixels) and the owner kept it after seeing it.
  # "highrr" selects the panel's 120 Hz mode instead of the 60 Hz preferred
  # mode; VRR 2 uses its 30-120 Hz adaptive-sync range only while a window is
  # fullscreen; fullscreen games may scan out directly, as on the desktop.
  home-manager.users.dhilipsiva.wayland.windowManager.hyprland.settings = {
    monitor = lib.mkForce [
      {
        output = "";
        mode = "highrr";
        position = "auto";
        scale = "auto";
        vrr = 2;
      }
    ];
    config.render.direct_scanout = 2;
  };
}
