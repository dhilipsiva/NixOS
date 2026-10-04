# Attended first installation only. Import alongside hardware generated on Yoga
# and set system.stateVersion to the stable release actually used to install.
# No shared desktop, SOPS passwords or automatic updates until signed boot works.
{
  lib,
  pkgs,
  inputs,
  ...
}:
{
  imports = [ inputs.lanzaboote.nixosModules.lanzaboote ];
  networking.hostName = "dhilipsiva-yoga";
  networking.networkmanager.enable = true;
  time.timeZone = "Asia/Kolkata";
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  hardware.enableRedistributableFirmware = true;
  hardware.cpu.intel.updateMicrocode = true;
  boot.initrd.systemd.enable = true;
  boot.loader = {
    systemd-boot = {
      enable = lib.mkForce false;
      editor = false;
      configurationLimit = 5;
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
  swapDevices = [ ];
  users.mutableUsers = true;
  users.users.dhilipsiva = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
  };
  services.openssh = {
    enable = true;
    openFirewall = false;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };
  environment.systemPackages = with pkgs; [
    git
    sbctl
    sbsigntool
    efitools
    cryptsetup
  ];
}
