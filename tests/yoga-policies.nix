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
assert lib.assertMsg
  (
    # Storage, boot and anchors exactly as captured on the installed laptop.
    c.repo.maintenance.boardName == "LNVNB161216"
    && c.fileSystems."/".device == "/dev/disk/by-uuid/5054780a-381e-4518-8493-df4929682c36"
    && c.fileSystems."/".fsType == "ext4"
    && c.fileSystems."/boot".device == "/dev/disk/by-uuid/73D4-F5E3"
    && c.boot.initrd.luks.devices == { }
    && c.boot.loader.systemd-boot.enable
    && c.boot.loader.systemd-boot.configurationLimit == 5
    && !c.boot.loader.systemd-boot.editor
    && !(c.boot.lanzaboote.enable or false)
    && c.boot.initrd.systemd.enable
    && c.boot.kernelPackages.kernel.version == channels.linux.version
    && c.system.stateVersion == "26.05"
    && h.home.stateVersion == "26.05"
    # zram is the only swap; the installer's swap partition stays unused.
    && c.swapDevices == [ ]
    && builtins.elem "systemd.swap=0" c.boot.kernelParams
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
    # The panel's 120 Hz mode, adaptive sync only in fullscreen, direct scanout.
    &&
      h.wayland.windowManager.hyprland.settings.monitor == [
        {
          output = "";
          mode = "highrr";
          position = "auto";
          scale = "auto";
          vrr = 2;
        }
      ]
    && h.wayland.windowManager.hyprland.settings.config.render.direct_scanout == 2
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
    && builtins.elem yoga.pkgs.pkgsi686Linux.intel-media-driver c.hardware.graphics.extraPackages32
    # Release-branch media/compute runtimes verified on the Arc 140V (libva 2.23
    # ABI); only Level Zero follows nixpkgs-apps for the NPU stack.
    && yoga.pkgs.intel-media-driver == pkgs.intel-media-driver
    && yoga.pkgs.intel-compute-runtime == pkgs.intel-compute-runtime
    && yoga.pkgs.level-zero == yoga.pkgs.nixpkgs-apps.level-zero
    && builtins.elem "render" c.users.users.dhilipsiva.extraGroups
    && c.services.ollama.package == yoga.pkgs.ollama-vulkan
    && c.services.ollama.environmentVariables.OLLAMA_KEEP_ALIVE == "0"
    && c.services.ollama.environmentVariables.OLLAMA_VULKAN == "1"
    && c.services.ollama.environmentVariables.OLLAMA_IGPU_ENABLE == "1"
    && c.systemd.services.ollama.wantedBy == [ ]
    && c.systemd.services.ollama.unitConfig.StopWhenUnneeded
    && c.services.hardware.bolt.enable
    && c.nix.settings.max-jobs == 1
    && c.nix.settings.cores == 0
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
  )
  "Yoga storage, boot, graphics runtimes, display, Ollama, Nix cores, bolt, applications, power or acceptance policy changed.";
pkgs.runCommand "yoga-policies-check" { } "touch $out"
