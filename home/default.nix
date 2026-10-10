{
  config,
  pkgs,
  lib,
  ...
}: let
  configsDir = "${config.home.homeDirectory}/stuff/nix-config";
  chatgptUpdater = pkgs.callPackage ../pkgs/chatgpt/update.nix {};
in {
  home.stateVersion = "24.11";
  catppuccin.autoEnable = false;

  home.packages = with pkgs; [
    tmux
    btop
    tree
    obsidian
  ];

  imports = [
    ./wikimem.nix
    ../vars.nix
    ./apps/tmux.nix
    ./apps/nixvim
    ./apps/zsh
    ./apps/kitty.nix

    # Application launcher, choose one
    ./apps/rofi.nix
    # ./apps/walker.nix # daemon mode broken, too slow otherwise
  ];

  home.sessionPath = ["$HOME/bin"];

  programs = {
    git = {
      enable = true;
      signing.format = "openpgp";
      settings = lib.mkIf (config.variables.gitIdentity or true) {
        user.name = "mochimisu";
        user.email = "brandonwang@me.com";
      };
    };
    spotify-player.enable = true;
  };

  programs.direnv.enable = true;

  home.shellAliases = {
    "nix-rs" = "nh os switch ${configsDir}";
    "nix-rsf" = "nh os switch ${configsDir} -- --fast";
    "nix-up" = "(cd ${lib.escapeShellArg configsDir} && nix flake update && ${lib.getExe chatgptUpdater})";
    "nixpkgs" = "nix search nixpkgs";
    "nixdir" = "cd ${configsDir}";
    "steam" = "mangohud steam";
  };

  home.activation = {
    cloneRepo = lib.hm.dag.entryAfter ["writeBoundary"] ''
      set -e
      if [ -d ${configsDir} ]; then
        echo "skipping clone, nix-config exists"
      else
        ${pkgs.git}/bin/git clone https://github.com/mochimisu/nix-config.git ${configsDir} || true
      fi
    '';
  };
}
