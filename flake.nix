{
  description = "my flake";
  inputs = {
    skwd-wall = {
      url = "github:liixini/skwd-wall/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Published File Dispatch source; the reviewed revision lives in flake.lock.
    gaia-file-dispatch.url = "github:mochimisu/file-dispatch";
    wikimem-skill = {
      url = "github:mochimisu/wikimem-skill";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    hyprgrass = {
      # Upstream hyprpm.toml's supported pairing for nixpkgs Hyprland 0.56.2.
      # Revisit with Hyprland upgrades; master targets newer compositor APIs.
      url = "github:horriblename/hyprgrass/8e605468cbf429791d61ddbfaeb14ff5e08fec3e";
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
    matter-layer = {
      url = "github:mochimisu/matter-layer";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dashcam-viewer = {
      url = "github:mochimisu/dashcam-viewer";
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
    # Host policy stays explicit below; this helper owns only common wiring.
    mkNixosHost = {hostModules, modules ? [], homeModules, homeArgs ? {}}:
      nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {inherit inputs;};
        modules = [./vars.nix] ++ hostModules ++ [
          ./boot-efi.nix
          ./common.nix
        ] ++ modules ++ [
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = {inherit inputs;};
            home-manager.users.brandon = {
              _module.args = homeArgs;
              imports = [
                inputs.catppuccin.homeModules.catppuccin
              ] ++ homeModules ++ [
                self.homeModules.home
                ./home/desktop.nix
              ];
            };
          }
        ];
      };
  in {
    packages.x86_64-linux = {
      default = self.nixosConfigurations.oasis.config.system.build.toplevel;
      chatgpt = pkgsX86Linux.callPackage ./pkgs/chatgpt/package.nix {};
      skwd-wall = inputs.skwd-wall.packages.x86_64-linux.default;
      update-chatgpt = pkgsX86Linux.callPackage ./pkgs/chatgpt/update.nix {};

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
        inputs.wikimem-skill.homeManagerModules.default
        inputs.nixvim.homeModules.nixvim
        ./home
      ];
    };

    homeConfigurations = {
      "deck@cove" = home-manager.lib.homeManagerConfiguration {
        pkgs = pkgsX86Linux;
        extraSpecialArgs = {inherit inputs;};
        modules = [
          inputs.catppuccin.homeModules.catppuccin
          self.homeModules.home
          ./machines/cove/home.nix
        ];
      };

      "steamos@comet" = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          system = "aarch64-linux";
          config.allowUnfree = true;
        };
        extraSpecialArgs = {inherit inputs;};
        modules = [
          inputs.catppuccin.homeModules.catppuccin
          self.homeModules.home
          ./machines/comet/home.nix
        ];
      };

      brandon = home-manager.lib.homeManagerConfiguration {
        pkgs = pkgsX86Linux;
        modules = [
          inputs.catppuccin.homeModules.catppuccin
          self.homeModules.home
          ./home/desktop.nix
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
                ./home/desktop.nix
              ];
            };
          }
        ];
      };
    };

    nixosConfigurations = {
      glasscastle = mkNixosHost {
        hostModules = [
          ./machines/glasscastle/hardware-configuration.nix
          ./machines/glasscastle/configuration.nix
        ];
        modules = [
          ./common-gui.nix
          ./desktop.nix
          ./common-gaming.nix
        ];
        homeModules = [./machines/glasscastle/home.nix];
      };
      espresso = mkNixosHost {
        hostModules = [
          ./machines/espresso/hardware-configuration.nix
          ./machines/espresso/configuration.nix
        ];
        modules = [
          ./common-gui.nix
          ./desktop.nix
          ./common-gaming.nix
        ];
        homeModules = [./machines/espresso/home.nix];
      };
      blackmoon = mkNixosHost {
        hostModules = [
          ./machines/blackmoon/hardware-configuration.nix
          ./machines/blackmoon/configuration.nix
        ];
        modules = [
          ./common-gui.nix
          ./desktop.nix
          ./common-gaming.nix
        ];
        homeModules = [./machines/blackmoon/home];
        homeArgs.skwdSuite = inputs.skwd-wall.packages.x86_64-linux.default;
      };
      oasis = mkNixosHost {
        hostModules = [
          ./machines/oasis/hardware-configuration.nix
          ./machines/oasis/configuration.nix
        ];
        modules = [
          ./common-gui.nix
          ./desktop.nix
          ./common-gaming.nix
        ];
        homeModules = [./machines/oasis/home];
      };
      gaia = mkNixosHost {
        hostModules = [
          ./machines/gaia/hardware-configuration.nix
          ./machines/gaia/configuration.nix
        ];
        modules = [
          inputs.sops-nix.nixosModules.sops
        ];
        homeModules = [./machines/gaia/home];
      };
    };
  };
}
