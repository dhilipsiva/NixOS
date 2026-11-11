{ pkgs, ... }:

{
  services.flatpak.enable = true;
  programs.obs-studio = {
    enable = true;
    package = pkgs.obs-studio.override { cudaSupport = true; };
  };
  # PRIME offload for the Steam client and everything it launches, so Proton
  # games render on the RTX 3070 rather than the Intel iGPU.
  programs.steam.package = pkgs.steam.override {
    extraEnv = {
      __NV_PRIME_RENDER_OFFLOAD = "1";
      __VK_LAYER_NV_optimus = "NVIDIA_only";
      __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    };
  };
  environment.systemPackages = with pkgs; [
    prismlauncher
    vinegar
    flameshot
    pass-wayland
  ];
  home-manager.users.dhilipsiva = { config, lib, ... }: {
    home.activation.migrateLegacyApplications =
      lib.hm.dag.entryBetween [ "linkGeneration" ] [ "writeBoundary" ]
        ''
          run ${pkgs.python3}/bin/python3 ${../../scripts/migrate-home.py} \
            --home "$HOME" --source "$HOME/.files/.config" \
            --managed ${
              pkgs.writeText "managed-home-paths.json" (
                builtins.toJSON (map (file: file.target) (builtins.attrValues config.home.file))
              )
            }
        '';
  };
}
