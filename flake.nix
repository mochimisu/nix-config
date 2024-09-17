{
  description = "my flake";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
        url = "github:nix-community/home-manager";
        inputs.nixpkgs.follows = "nixpkgs";
    };
    rose-pine-hyprcursor.url = "github:ndom91/rose-pine-hyprcursor";
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = { self, nixpkgs, home-manager, ... } @inputs: {
    defaultPackage.x86_64-linux = home-manager.defaultPackage.x86_64-linux;
    nixosConfigurations = {
      glasscastle = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; };
        system = "x86_64-linux";
        modules = [
          ./machines/glasscastle/hardware-configuration.nix
          ./machines/glasscastle/configuration.nix
          ./boot-efi.nix
          ./common.nix
          ./common-gui.nix
          home-manager.nixosModules.home-manager {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.brandon = {
              imports = [ 
              # nixvim must be here, or we hit inf recursion
              # https://github.com/gmodena/nix-flatpak/issues/25
              inputs.nixvim.homeManagerModules.nixvim
              ./home ];
            };
          }
        ];
      };
      whitesun = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; };
        system = "x86_64-linux";
        modules = [
          #./machines/whitesun/hardware-configuration.nix
          #./machines/whitesun/configuration.nix
          ./boot-efi.nix
          ./common.nix
          ./common-gui.nix
        ];
      };
    };
  };
}
