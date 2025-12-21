{ config, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  networking.hostName = "dhilipsiva-desktop";

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
  # Kernel 6.12+ is required for Ryzen 9000 X3D scheduling
  boot.kernelPackages = pkgs.linuxPackages_latest;
  
  # --- GRAPHICS (RTX 5090) ---
  services.xserver.videoDrivers = [ "nvidia" ];
  
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false; # Desktop GPUs run better without aggressive power saving
    open = false; # Proprietary drivers are currently more stable for 50-series
    nvidiaSettings = true;
    
    # Force the Beta driver branch (570+) for Blackwell architecture support
    package = config.boot.kernelPackages.nvidiaPackages.beta;
  };

  # --- WIFI 7 (Firmware Fix) ---
  # Fixes the missing firmware for MSI X870E Qualcomm chips
  hardware.enableRedistributableFirmware = true;
  hardware.firmware = [
    pkgs.linux-firmware
    (pkgs.linux-firmware.overrideAttrs (old: {
      src = pkgs.fetchgit {
        url = "https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git";
        rev = "master"; 
        sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # Run once, let it fail, replace hash
      };
    }))
  ];

  # --- UPS MONITORING (CyberPower) ---
  power.ups = {
    enable = true;
    mode = "standalone";
    ups.cyberpower = {
      driver = "usbhid-ups";
      port = "auto";
    };
    users.upsmon = {
      passwordFile = "/etc/nixos/ups-password"; # Create this file!
      upsmonConf = ''
        MONITOR cyberpower@localhost 1 upsmon secret master
        SHUTDOWNCMD "${pkgs.systemd}/bin/shutdown -h +0"
      '';
    };
  };
}
