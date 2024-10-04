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
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = { self, nixpkgs, home-manager, nix-darwin, ... } @inputs: {
    defaultPackage.x86_64-linux = home-manager.defaultPackage.x86_64-linux;

    homeManagerModules.home = {
      imports = [
        inputs.nixvim.homeManagerModules.nixvim
        ./home
      ];
    };

    homeConfigurations = {
      brandon = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs;
        modules = [ 
          self.homeManagerModules.home 
        ];
      };
    };

    darwinConfigurations = {
      oai-dev = nix-darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        modules = [
          ./vars.nix
          ./machines/oai-dev/configuration.nix
          home-manager.darwinModules.home-manager {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.brandonw = {
              imports = [
                ./machines/oai-dev/home.nix
                self.homeManagerModules.home
              ];
            };
          }
        ];
      };
    };

    nixosConfigurations = {
      glasscastle = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; };
        system = "x86_64-linux";
        modules = [
          ./vars.nix
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
                ./machines/glasscastle/home.nix
                self.homeManagerModules.home
              ];
            };
          }
        ];
      };
      espresso = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; };
        system = "x86_64-linux";
        modules = [
          ./vars.nix
          ./machines/espresso/hardware-configuration.nix
          ./machines/espresso/configuration.nix
          ./boot-efi.nix
          ./common.nix
          ./common-gui.nix
          home-manager.nixosModules.home-manager {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.brandon = {
              imports = [
                ./machines/espresso/home.nix
                self.homeManagerModules.home
              ];
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
