{ lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./graphics.nix
    ./power.nix
    ./applications.nix
    ../../modules/nixos/lucy.nix
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
    flatpakApps = [ "org.vinegarhq.Sober" ];
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
  # Lucy on the ThinkPad. Ollama runs on the RTX 3070 Laptop GPU through CUDA;
  # OLLAMA_GPU_OVERHEAD above keeps 2 GiB of its 8 GiB for the compositor and
  # PRIME offload, so about 6 GiB remain for a model. Lucy's own pin, Qwen3.6
  # 35B-A3B, needs about 25 GiB and Qwen3.6 ships no smaller size, so this host
  # takes the Yoga's pin: qwen3.5:9b-q4_K_M, the same qwen3.5 tool-call renderer
  # as the desktop's model, 5.2 GiB of weights plus a 0.9 GiB vision projector,
  # 16K context. Weights plus the 16K KV cache exceed the remaining 6 GiB, so the
  # CUDA runner may keep part of the layers in the 16 GiB of RAM; `journalctl -u
  # ollama -b` shows the split and `lucy chat` latency is the acceptance measure.
  # Digest: SHA-256 of the registry manifest
  # (registry.ollama.ai/v2/library/qwen3.5/manifests/9b-q4_K_M), the value
  # verified on the Yoga on 2026-10-20; a different pin is a one-line change here.
  repo.lucy = {
    enable = true;
    model = {
      name = "qwen3.5:9b-q4_K_M";
      digest = "56671c2ab9385f9cfcb404638e32cd62d88e3501d44822208363c010179a3c90";
    };
  };
  system.stateVersion = "24.11";
  home-manager.users.dhilipsiva.home.stateVersion = "26.05";
}
