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
            ./modules/common.nix
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.dhilipsiva = import ./home/default.nix;
            }
          ];
        };
      };
    };
}
