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
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flatpaks = {
      url = "github:gmodena/nix-flatpak";
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
    catppuccin.url = "github:catppuccin/nix";
    nix-snapd = {
      url = "github:nix-community/nix-snapd";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    aagl = {
      url = "github:ezKEa/aagl-gtk-on-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = {
    self,
    nixpkgs,
    home-manager,
    nix-darwin,
    ...
  } @ inputs: {
    defaultPackage.x86_64-linux = home-manager.defaultPackage.x86_64-linux;
    packages.x86_64-linux = {
      gaia-iso = let
        isoSystem = nixpkgs.lib.nixosSystem {
          specialArgs = {inherit inputs;};
          system = "x86_64-linux";
          modules = [
            "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
            ./vars.nix
            ({lib, ...}: {
              boot.supportedFilesystems = lib.mkForce [
                "ext4"
                "vfat"
                "btrfs"
                "xfs"
              ];
              boot.initrd.supportedFilesystems = lib.mkForce [
                "ext4"
                "vfat"
                "btrfs"
                "xfs"
              ];
            })
            ./common.nix
            ./machines/gaia/configuration.nix
          ];
        };
      in
        isoSystem.config.system.build.isoImage;
    };

    homeModules.home = {
      imports = [
        inputs.nixvim.homeModules.nixvim
        ./home
      ];
    };

    homeConfigurations = {
      brandon = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs;
        modules = [
          self.homeModules.home
        ];
      };
    };

    darwinConfigurations = {
      oai-dev = nix-darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        modules = [
          ./vars.nix
          ./machines/oai-dev/configuration.nix
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.brandonw = {
              imports = [
                inputs.catppuccin.homeModules.catppuccin
                ./machines/oai-dev/home
                self.homeModules.home
              ];
            };
          }
        ];
      };
    };

    nixosConfigurations = {
      glasscastle = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs;};
        system = "x86_64-linux";
        modules = [
          ./vars.nix
          ./machines/glasscastle/hardware-configuration.nix
          ./machines/glasscastle/configuration.nix
          ./boot-efi.nix
          ./common.nix
          ./common-gui.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.brandon = {
              imports = [
                inputs.catppuccin.homeModules.catppuccin
                ./machines/glasscastle/home.nix
                self.homeModules.home
              ];
            };
          }
        ];
      };
      espresso = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs;};
        system = "x86_64-linux";
        modules = [
          ./vars.nix
          ./machines/espresso/hardware-configuration.nix
          ./machines/espresso/configuration.nix
          ./boot-efi.nix
          ./common.nix
          ./common-gui.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.brandon = {
              imports = [
                inputs.catppuccin.homeModules.catppuccin
                ./machines/espresso/home.nix
                self.homeModules.home
              ];
            };
          }
        ];
      };
      blackmoon = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs;};
        system = "x86_64-linux";
        modules = [
          ./vars.nix
          ./machines/blackmoon/hardware-configuration.nix
          ./machines/blackmoon/configuration.nix
          ./boot-efi.nix
          ./common.nix
          ./common-gui.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.brandon = {
              imports = [
                inputs.catppuccin.homeModules.catppuccin
                ./machines/blackmoon/home
                self.homeModules.home
              ];
            };
          }
        ];
      };
      oasis = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs;};
        system = "x86_64-linux";
        modules = [
          ./vars.nix
          ./machines/oasis/hardware-configuration.nix
          ./machines/oasis/configuration.nix
          ./boot-efi.nix
          ./common.nix
          ./common-gui.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.brandon = {
              imports = [
                inputs.catppuccin.homeModules.catppuccin
                ./machines/oasis/home
                self.homeModules.home
              ];
            };
          }
        ];
      };
      gaia = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs;};
        system = "x86_64-linux";
        modules = [
          ./vars.nix
          ./machines/gaia/hardware-configuration.nix
          ./machines/gaia/configuration.nix
          ./boot-efi.nix
          ./common.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.brandon = {
              imports = [
                inputs.catppuccin.homeModules.catppuccin
                ./machines/gaia/home
                self.homeModules.home
              ];
            };
          }
        ];
      };
    };
  };
}
