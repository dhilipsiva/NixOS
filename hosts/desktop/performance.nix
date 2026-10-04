# Desktop-only development/local-AI profile. Do not import on the ThinkPad.
{ pkgs, ... }:

{
  # amd-pstate uses the processor's CPPC support; this desktop prioritizes speed.
  boot.kernelParams = [ "amd_pstate=active" ];
  powerManagement.cpuFreqGovernor = "performance";

  # Compressed RAM swap absorbs transient build/model memory pressure. No disk
  # swap or repartitioning is required, and this is not a substitute for VRAM.
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 25;
    priority = 100;
  };

  # systemd-oomd protects the interactive session: a runaway user process is
  # killed on sustained memory pressure before the whole desktop stalls.
  systemd.oomd.enableUserSlices = true;

  # Let one large compilation scale over all OS-visible CPUs. Limit concurrent
  # derivations and lower the daemon's scheduling weight to keep editors usable.
  # Periodic SSD TRIM comes from nixos-hardware's common-pc-ssd module.
  nix.settings = {
    max-jobs = 2;
    cores = 0;
  };
  systemd.services.nix-daemon.serviceConfig = {
    CPUWeight = 50;
    IOWeight = 50;
  };

  # File watchers for large workspaces (Zed, language servers, Node tooling).
  boot.kernel.sysctl."fs.inotify.max_user_watches" = 1048576;

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Backend selection for this GPU; modules/nixos/ollama.nix owns the socket wiring.
  services.ollama = {
    package = pkgs.ollama-cuda;
    environmentVariables = {
      # One active model/request prioritizes interactive coding and VRAM capacity.
      OLLAMA_NUM_PARALLEL = "1";
      OLLAMA_MAX_LOADED_MODELS = "1";
      # Keep headroom for Hyprland/Zed on the same GPU. Let Ollama choose context size
      # and Flash Attention per model/backend rather than forcing incompatible settings.
      OLLAMA_GPU_OVERHEAD = "2147483648";
    };
  };

  environment.systemPackages = with pkgs; [
    btop
    nvtopPackages.nvidia
    lm_sensors
    pciutils
    usbutils
  ];
}
