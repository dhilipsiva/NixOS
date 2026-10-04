{ pkgs, ... }:

{
  services.flatpak.enable = true;
  programs.obs-studio = {
    enable = true;
    package = pkgs.obs-studio.override { cudaSupport = true; };
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
