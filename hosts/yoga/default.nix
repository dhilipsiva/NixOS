# Lenovo Yoga Slim 7 15ILL9, installed by the owner with the official NixOS
# 26.05 graphical installer on 2026-10-04 (GNOME, generation 1). This host
# preserves that installation: the unencrypted ext4 root, the 1 GiB ESP and the
# unsigned systemd-boot loader with Secure Boot disabled (no signing keys exist
# on this machine), the same boot policy as the ThinkPad. Hardware and anchors
# live in hardware-configuration.nix and installation.nix, captured on the
# laptop itself.
{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ./installation.nix
    ./graphics.nix
    ./power.nix
    ./applications.nix
  ];
  networking.hostName = "dhilipsiva-yoga";
  time.timeZone = lib.mkForce "Asia/Kolkata";
  hardware.enableRedistributableFirmware = true;
  hardware.cpu.intel.updateMicrocode = true;
  # systemd stage 1 on the plain ext4 root. Five generations fit the 1 GiB ESP
  # beside the protected recovery copy of the original installation.
  boot.initrd.systemd.enable = true;
  boot.loader = {
    systemd-boot = {
      enable = true;
      configurationLimit = 5;
      editor = false;
    };
    efi = {
      canTouchEfiVariables = true;
      efiSysMountPoint = "/boot";
    };
  };
  # Created by prepare-credentials on this laptop, never copied from another host.
  sops.defaultSopsFile = ../../secrets/yoga.yaml;
  services.openssh = {
    enable = true;
    openFirewall = false;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };
  users.users.root.openssh.authorizedKeys.keyFiles = [ ../../secrets/owner.pub ];
  users.users.dhilipsiva.extraGroups = [
    "render"
    "video"
  ];
  repo.maintenance = {
    enable = true;
    host = "yoga";
    role = "subscriber";
    flatpakApps = [ "org.vinegarhq.Sober" ];
    # boardName is in installation.nix, read from the real DMI value.
  };
  nix.settings = {
    max-jobs = 1;
    cores = 4;
  };
  systemd.services.nix-daemon.serviceConfig = {
    CPUWeight = 50;
    IOWeight = 50;
  };
  boot.kernel.sysctl."fs.inotify.max_user_watches" = 1048576;
  environment.systemPackages = with pkgs; [
    btop
    pciutils
    usbutils
  ];
  services.ollama = {
    package = pkgs.ollama-vulkan;
    environmentVariables = {
      OLLAMA_VULKAN = "1";
      OLLAMA_NUM_PARALLEL = "1";
      OLLAMA_MAX_LOADED_MODELS = "1";
    };
  };
  assertions = [
    {
      assertion =
        config.fileSystems."/".fsType == "ext4"
        && config.fileSystems."/boot".fsType == "vfat"
        && config.boot.initrd.luks.devices == { };
      message = "Yoga preserves its installed unencrypted ext4 root and ESP; see YOGA.md.";
    }
    {
      assertion = config.swapDevices == [ ] && config.zramSwap.writebackDevice == null;
      message = "Yoga uses zram only, with no disk swap or writeback.";
    }
  ];
}
