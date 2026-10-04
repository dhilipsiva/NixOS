{ lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./graphics.nix
    ./power.nix
    ./applications.nix
  ];
  networking.hostName = "dhilipsiva-thinkpad";
  time.timeZone = lib.mkForce "Asia/Kolkata";
  hardware.enableRedistributableFirmware = true;
  boot.loader = {
    systemd-boot = {
      enable = true;
      configurationLimit = 3;
    };
    efi = {
      canTouchEfiVariables = true;
      efiSysMountPoint = "/boot";
    };
  };
  sops.defaultSopsFile = ../../secrets/thinkpad.yaml;
  services.openssh = {
    enable = true;
    openFirewall = false;
  };
  users.users.root.openssh.authorizedKeys.keyFiles = [ ../../secrets/owner.pub ];
  repo.maintenance = {
    enable = true;
    host = "thinkpad";
    role = "subscriber";
    boardName = "20YSS01K00";
  };
  nix.settings = {
    max-jobs = 1;
    cores = 4;
  };
  zramSwap = {
    enable = true;
    swapDevices = 1;
    algorithm = "zstd";
    memoryPercent = 25;
    priority = 100;
  };
  systemd.services.nix-daemon.serviceConfig = {
    CPUWeight = 50;
    IOWeight = 50;
  };
  boot.kernel.sysctl."fs.inotify.max_user_watches" = 1048576;
  environment.systemPackages = with pkgs; [
    btop
    nvtopPackages.nvidia
    pciutils
    usbutils
  ];
  services.ollama = {
    package = pkgs.ollama-cuda;
    environmentVariables = {
      OLLAMA_NUM_PARALLEL = "1";
      OLLAMA_MAX_LOADED_MODELS = "1";
      OLLAMA_GPU_OVERHEAD = "2147483648";
    };
  };
  system.stateVersion = "24.11";
  home-manager.users.dhilipsiva.home.stateVersion = "26.05";
}
