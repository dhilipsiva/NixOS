{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    # Offload microcode / GPU / SSD quirks to nixos-hardware.
    inputs.nixos-hardware.nixosModules.common-cpu-amd
    # -nonprime: single discrete RTX 5090 with the monitor wired directly to it
    # (no hybrid/PRIME offload). Plain common-gpu-nvidia assumes PRIME and would
    # demand bus IDs we don't have on this desktop.
    inputs.nixos-hardware.nixosModules.common-gpu-nvidia-nonprime
    inputs.nixos-hardware.nixosModules.common-pc-ssd
  ];

  networking.hostName = "dhilipsiva-desktop";

  # --- VM-TEST-ONLY OVERRIDES (build-vm variant; ZERO effect on real hardware) ---
  # Everything under virtualisation.vmVariant applies only when building
  # `nixos-rebuild build-vm --flake .#desktop`, never to the installed system.
  # This makes the desktop config bootable headless for the VM-first workflow
  # (GATE 1 boot check and every later phase's VM rehearsal).
  virtualisation.vmVariant = {
    virtualisation.graphics = false;
    boot.kernelParams = [ "console=ttyS0,115200n8" "console=tty1" ];
    systemd.services."serial-getty@ttyS0".enable = true;
    # VM-only: SSH + a throwaway password so the migration can be verified
    # headlessly (parity checks, Phase 6 rehearsal). Never reaches real hardware.
    services.openssh.enable = true;
    services.openssh.settings.PermitRootLogin = "yes";
    users.users.dhilipsiva.hashedPassword = lib.mkForce null;
    users.users.dhilipsiva.password = "test";
    users.users.root.password = "test";
  };

  # --- BOOTLOADER (Dual Boot Optimized) ---
  # We use GRUB because it detects Windows on a separate drive better than systemd-boot
  boot.loader = {
    efi = {
      canTouchEfiVariables = true;
      efiSysMountPoint = "/boot";
    };
    grub = {
      enable = true;
      devices = [ "nodev" ];
      efiSupport = true;
      useOSProber = true; # Finds your Windows SSD automatically
    };
  };

  # --- KERNEL & CPU ---
  # 26.05's default kernel already covers Ryzen 9000 X3D scheduling; the
  # linuxPackages_latest override is dropped (it can fight the NVIDIA module ABI
  # and loses binary-cache coverage). Re-add only if the VM shows a concrete need.

  # --- GRAPHICS (RTX 5090) ---
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false; # Desktop GPUs run better without aggressive power saving
    open = true; # REQUIRED for 50-series Blackwell (proprietary module is unsupported)
    nvidiaSettings = true;

    # Current production branch on 26.05 (confirm exact version via nix eval, not a
    # hardcoded number). NOT .beta (a pre-580 workaround) and NOT .legacy_580.
    package = config.boot.kernelPackages.nvidiaPackages.production;
  };

  # --- FIRMWARE ---
  # Rely on redistributable firmware + nixos-hardware (26.05's linux-firmware
  # already carries the MSI X870E Qualcomm Wi-Fi firmware). The old hand-rolled
  # fetchgit override with a placeholder sha256-AAAA… hash is removed — it could
  # never build. If a specific firmware is later proven missing on real hardware,
  # add a narrowly-scoped override with a real hash then (Phase 5/7).
  hardware.enableRedistributableFirmware = true;

  # --- UPS MONITORING (CyberPower) ---
  # 26.05's power.ups uses a structured schema: an upsd account under
  # `users.<name>` plus a `upsmon.monitor.<name>` entry (the old inline
  # `users.upsmon.upsmonConf` MONITOR string is gone, which is why the total
  # power value evaluated to 0 < MINSUPPLIES). passwordFile still points at the
  # plaintext /etc/nixos/ups-password here — Phase 4 moves it to sops.
  power.ups = {
    enable = true;
    mode = "standalone";
    ups.cyberpower = {
      driver = "usbhid-ups";
      port = "auto";
    };
    users.upsmon = {
      passwordFile = "/etc/nixos/ups-password"; # Create this file! (→ sops in Phase 4)
      upsmon = "primary"; # NUT renamed master/slave → primary/secondary
    };
    upsmon = {
      monitor.cyberpower = {
        system = "cyberpower@localhost";
        user = "upsmon";
        type = "primary";
        # powerValue defaults to 1; passwordFile defaults to users.upsmon.passwordFile
      };
      settings.SHUTDOWNCMD = "${pkgs.systemd}/bin/shutdown -h +0";
    };
  };

  # First-install anchor for this never-installed host (NOT a bump on an existing
  # machine). Per-host on purpose: a revived ThinkPad keeps its own value.
  system.stateVersion = "26.05";
}
