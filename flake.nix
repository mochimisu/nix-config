{
  description = "my flake";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    hyprgrass = {
      # Keep this input for the touchscreen module while Hyprland itself comes from nixpkgs.
      url = "github:horriblename/hyprgrass";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    rose-pine-hyprcursor.url = "github:ndom91/rose-pine-hyprcursor";
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    codex-cli-nix.url = "github:sadjow/codex-cli-nix";
    flatpaks = {
      url = "github:gmodena/nix-flatpak";
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
    nix-openclaw.url = "github:openclaw/nix-openclaw";
    matter-layer = {
      url = "github:mochimisu/matter-layer";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = {
    self,
    nixpkgs,
    home-manager,
    nix-darwin,
    ...
  } @ inputs: let
    pkgsX86Linux = import nixpkgs {
      system = "x86_64-linux";
      config.allowUnfree = true;
    };
  in {
    packages.x86_64-linux = {
      gaia-iso = let
        isoSystem = nixpkgs.lib.nixosSystem {
          specialArgs = {inherit inputs;};
          system = "x86_64-linux";
          modules = [
            "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
            ./vars.nix
            inputs.sops-nix.nixosModules.sops
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
              # The installer profile and Gaia service stack both set this for
              # Redis; keep the ISO evaluation deterministic.
              boot.kernel.sysctl."vm.overcommit_memory" = lib.mkForce "1";
            })
            ./common.nix
            ./machines/gaia/configuration.nix
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
            }
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
        pkgs = pkgsX86Linux;
        modules = [
          inputs.catppuccin.homeModules.catppuccin
          self.homeModules.home
          {
            home.username = "brandon";
            home.homeDirectory = "/home/brandon";
          }
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
          ./common-gaming.nix
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
          ./common-gaming.nix
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
          ./common-gaming.nix
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
          ./common-gaming.nix
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
          inputs.sops-nix.nixosModules.sops
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
