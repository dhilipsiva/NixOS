{
  description = "Dhilipsiva's Hyper-Modern NixOS";

  inputs = {
    # Track latest-stable NixOS (26.05) to avoid breakage. RTX 5090 (nvidia open
    # module + production driver) and Ryzen 9000 X3D are supported on stable.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Hardware quirks (AMD microcode, NVIDIA, SSD) offloaded to nixos-hardware.
    nixos-hardware = {
      url = "github:nixos/nixos-hardware/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Declarative secrets. Pinned via flake.lock; re-verify the activation-script
    # wiring (setupSecretsForUsers) after any `nix flake update` (see modules/nixos/sops.nix).
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Declarative partitioning (Phase 5). Follows nixpkgs to stay on the 26.05 pin.
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      nixosConfigurations = {
        # Your New AI/Gaming Rig
        desktop = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [
            ./hosts/desktop/default.nix
            # Declarative partitioning: the module provides disko.* options,
            # hosts/desktop/disko.nix consumes them (LUKS2 -> ext4 + FAT32 ESP).
            inputs.disko.nixosModules.disko
            ./hosts/desktop/disko.nix
            ./modules/nixos
            inputs.sops-nix.nixosModules.sops
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = { inherit inputs; };
              home-manager.users.dhilipsiva = import ./home/dhilipsiva;
            }
          ];
        };
      };
    };
}
