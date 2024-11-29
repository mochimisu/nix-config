{ config, pkgs, lib, inputs, keyboardLayout, ...}:

let
  configsDir = "${config.home.homeDirectory}/stuff/nix-config";
in
{
  home.stateVersion = "24.11";
  home.packages = with pkgs; [ 
    tmux
    btop
    silver-searcher
    tree
  ];

  imports = [
    ./apps/hypr
    ./apps/tmux.nix
    ./apps/nixvim
    ./apps/zsh
  ];

  home.sessionPath = ["$HOME/bin"];

  programs = {
    git = {
      enable = true;
      userName = "mochimisu";
      userEmail = "brandonwang@me.com";
    };
    spotify-player.enable = true;
  };

  programs.direnv.enable = true;

  home.shellAliases = {
    "nix-rs" = "sudo nixos-rebuild switch --flake ${configsDir}";
    "nix-rsf" = "sudo nixos-rebuild switch --flake ${configsDir} --fast";
    "nix-up" = "cd ${configsDir} && nix flake update && cd -";
    "nixpkgs" = "nix search nixpkgs";
    "nixdir" = "cd ${configsDir}";
    "steam" = "mangohud steam";
  };

  # Dark mode
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
    };
  };

  gtk = {
    enable = true;
    gtk3.extraConfig = {
      "gtk-application-prefer-dark-theme" = "1";
    };
    
    gtk4.extraConfig = {
      "gtk-application-prefer-dark-theme" = "1";
    };
  };

  home.file = {
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

