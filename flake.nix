{
  description = "Dhilipsiva's Hyper-Modern NixOS";

  inputs = {
    # The "Unstable" branch is mandatory for your RTX 5090 and Ryzen 9000
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
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
