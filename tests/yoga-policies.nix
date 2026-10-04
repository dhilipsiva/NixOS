{
  pkgs,
  lib,
  yoga,
}:
let
  c = yoga.config;
  h = c.home-manager.users.dhilipsiva;
  channels = builtins.fromJSON (builtins.readFile ../pkgs/stable-channels.json);
in
assert lib.assertMsg (
  c.boot.lanzaboote.enable
  && c.boot.kernelPackages.kernel.version == channels.linux.version
  && c.boot.initrd.systemd.enable
  && !c.boot.lanzaboote.autoEnrollKeys.enable
  && !c.boot.lanzaboote.autoGenerateKeys.enable
  && !c.boot.loader.systemd-boot.editor
  && c.boot.initrd.luks.devices ? root
  && !c.boot.initrd.luks.devices.root.allowDiscards
  && c.boot.initrd.luks.devices.root.keyFile == null
  && c.swapDevices == [ ]
  && c.zramSwap.enable
  && c.zramSwap.swapDevices == 1
  && c.zramSwap.memoryPercent == 25
  && c.zramSwap.algorithm == "zstd"
  && c.zramSwap.writebackDevice == null
  && c.services.logind.settings.Login.HandleLidSwitch == "suspend"
  && c.services.logind.settings.Login.HandleLidSwitchDocked == "ignore"
  && c.systemd.sleep.settings.Sleep.AllowSuspend
  && !c.systemd.sleep.settings.Sleep.AllowHibernation
  && builtins.all (listener: listener.timeout == 300) h.services.hypridle.settings.listener
  && h.repo.waybar.battery.enable
  &&
    h.wayland.windowManager.hyprland.settings.monitor == [
      {
        output = "";
        mode = "preferred";
        position = "auto";
        scale = "auto";
      }
    ]
  && builtins.elem "xe" c.boot.kernelModules
  && !builtins.elem "nvidia" c.services.xserver.videoDrivers
  && !c.hardware.nvidia.prime.offload.enable
  && !c.hardware.nvidia.dynamicBoost.enable
  && c.hardware.graphics.enable
  && c.hardware.graphics.enable32Bit
  && c.hardware.cpu.intel.npu.enable
  && yoga.pkgs.intel-npu-driver.version == yoga.pkgs.intel-npu-compiler.version
  && builtins.elem yoga.pkgs.intel-npu-driver c.hardware.graphics.extraPackages
  && builtins.elem yoga.pkgs.intel-media-driver c.hardware.graphics.extraPackages
  && builtins.elem yoga.pkgs.intel-compute-runtime c.hardware.graphics.extraPackages
  && builtins.elem "render" c.users.users.dhilipsiva.extraGroups
  && c.services.ollama.package == yoga.pkgs.ollama-vulkan
  && c.services.ollama.environmentVariables.OLLAMA_KEEP_ALIVE == "0"
  && c.systemd.services.ollama.wantedBy == [ ]
  && c.systemd.services.ollama.unitConfig.StopWhenUnneeded
  && c.services.flatpak.enable
  && c.programs.obs-studio.enable
  && c.programs.obs-studio.package.version == channels.obs-studio.version
  && c.repo.maintenance.flatpakApps == [ "org.vinegarhq.Sober" ]
  && !(h.home.activation ? migrateLegacyApplications)
  && h.xdg.desktopEntries.roblox-sober.name == "Roblox (Sober)"
  && c.repo.maintenance.role == "subscriber"
  &&
    c.systemd.services.nixos-update.unitConfig.ConditionPathExists
    == "/var/lib/nixos-deployment/accepted.json"
  && builtins.attrNames c.sops.secrets == [ "dhilipsiva/hashedPassword" ]
  && c.time.timeZone == "Asia/Kolkata"
) "Yoga storage, graphics, applications, power or acceptance policy changed.";
pkgs.runCommand "yoga-policies-check" { } "touch $out"
