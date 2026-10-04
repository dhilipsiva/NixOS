# Hardware and installation anchors are supplied separately after capture on the
# real laptop. flake.nix never exposes the test fixture as a deployable host.
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
{
  imports = [
    ./graphics.nix
    ./power.nix
    ./applications.nix
    inputs.lanzaboote.nixosModules.lanzaboote
  ];
  networking.hostName = "dhilipsiva-yoga";
  time.timeZone = lib.mkForce "Asia/Kolkata";
  hardware.enableRedistributableFirmware = true;
  hardware.cpu.intel.updateMicrocode = true;
  boot.initrd.systemd.enable = true;
  boot.loader = {
    systemd-boot = {
      enable = lib.mkForce false;
      configurationLimit = 5;
      editor = false;
    };
    efi = {
      canTouchEfiVariables = true;
      efiSysMountPoint = "/boot";
    };
  };
  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
    autoGenerateKeys.enable = false;
    autoEnrollKeys.enable = false;
    autoEnrollKeys.autoReboot = false;
  };
  # This file is created by prepare-credentials, never copied from another host.
  sops.defaultSopsFile = ../../secrets + "/yoga.yaml";
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
    # boardName belongs in installation.nix after reading the real DMI value.
  };
  nix.settings = {
    max-jobs = 1;
    cores = 4;
  };
  environment.systemPackages = with pkgs; [
    sbctl
    sbsigntool
    efitools
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
        && config.boot.initrd.luks.devices ? root;
      message = "Yoga requires its captured LUKS root and ext4/ESP filesystems; see YOGA.md.";
    }
    {
      assertion = config.swapDevices == [ ] && config.zramSwap.writebackDevice == null;
      message = "Yoga uses zram only, with no disk swap or writeback.";
    }
  ];
}
