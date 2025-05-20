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
    nixos-xivlauncher-rb = {
      url = "github:drakon64/nixos-xivlauncher-rb";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprpanel.url = "github:Jas-SinghFSU/HyprPanel";
    catppuccin.url = "github:catppuccin/nix";
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
                inputs.catppuccin.homeModules.catppuccin
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
      blackmoon = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; };
        system = "x86_64-linux";
        modules = [
          ./vars.nix
          ./machines/blackmoon/hardware-configuration.nix
          ./machines/blackmoon/configuration.nix
          ./boot-efi.nix
          ./common.nix
          ./common-gui.nix
          home-manager.nixosModules.home-manager {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.brandon = {
              imports = [
                ./machines/blackmoon/home
                  self.homeManagerModules.home
              ];
            };
          }
        ];
      };
      gaia = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; };
        system = "x86_64-linux";
        modules = [
          ./vars.nix
          # ./machines/gaia/hardware-configuration.nix
          ./machines/gaia/configuration.nix
          ./boot-efi.nix
          ./common.nix
          home-manager.nixosModules.home-manager {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.brandon = {
              imports = [
                ./machines/gaia/home
                  self.homeManagerModules.home
              ];
            };
          }
        ];
      };

      oasis = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; };
        system = "x86_64-linux";
        modules = [
          ./vars.nix
          ./machines/oasis/hardware-configuration.nix
          ./machines/oasis/configuration.nix
          ./boot-efi.nix
          ./common.nix
          ./common-gui.nix
          home-manager.nixosModules.home-manager {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.brandon = {
              imports = [
                ./machines/oasis/home.nix
                self.homeManagerModules.home
              ];
            };
          }
        ];
      };

    };
  };
}
