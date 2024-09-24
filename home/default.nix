{ config, pkgs, lib, inputs, keyboardLayout, ...}:

let
  configsDir = "${config.home.homeDirectory}/stuff/nix-confis";
in
{
  home.stateVersion = "24.11";
  home.packages = with pkgs; [ 
    git
    oh-my-zsh
    tmux
    btop
    silver-searcher
    tree
  ];

  imports = [
    ./apps/hypr
    ./apps/tmux.nix
    ./apps/waybar.nix
    ./apps/nixvim
  ];
  

  programs = {
    git = {
      enable = true;
      userName = "mochimisu";
      userEmail = "brandonwang@me.com";
    };
    zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;
      zplug = {
        enable = true;
          plugins = [
            {
              name = "romkatv/powerlevel10k";
              tags = [ as:theme depth:1 ];
            }
            {
              name = "zsh-users/zsh-history-substring-search";
              tags = [ as:plugin depth:1 ];
            }
          ];
      };
    };
  };

  home.shellAliases = {
    "nix-rs" = "sudo nixos-rebuild switch --flake ${configsDir}/flake.nix";
    "nix-up" = "cd ${configsDir} && nix flake update && cd -";
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
  #
   home.activation = {
     cloneRepo = lib.hm.dag.entryAfter ["writeBoundary"] ''
     if [ -d ${configsDir} ]; then
       echo "skipping clone, nix-config exist"
     else
       ${pkgs.git}/bin/git clone https://github.com/mochimisu/nix-config.git ${configsDir}
     fi
     '';
   };
}

