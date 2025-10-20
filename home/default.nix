{
  config,
  pkgs,
  lib,
  ...
}: let
  configsDir = "${config.home.homeDirectory}/stuff/nix-config";
  isLinux = pkgs.stdenv.isLinux;
  isGui = config.variables.isGui or true;
in {
  home.stateVersion = "24.11";
  home.packages = with pkgs; [
    tmux
    btop
    silver-searcher
    tree
    obsidian
  ];

  imports = [
    ../vars.nix
    ./apps/tmux.nix
    ./apps/nixvim
    ./apps/zsh
    ./apps/kitty.nix

    # status bar, choose one
    # ./apps/hyprpanel.nix # customization not as deep as id like
    # ./apps/waybar # horizontal only
    ./apps/eww # high cpu usage

    # notification manager
    # (don't need with hyprpanel)
    # ./apps/dunst.nix
    ./apps/mako.nix

    # Application launcher, choose one
    ./apps/rofi.nix
    # ./apps/walker.nix # daemon mode broken, too slow otherwise
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
  dconf.settings = lib.mkIf isGui {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
    };
  };

  gtk = lib.mkIf isGui {
    enable = true;
    gtk3.extraConfig = {
      "gtk-application-prefer-dark-theme" = "1";
    };

    gtk4.extraConfig = {
      "gtk-application-prefer-dark-theme" = "1";
    };
  };

  # per-app translucency
  xdg.configFile."gtk-3.0/gtk.css".source = builtins.toFile "gtk.css" ''
    .thunar .sidebar .view {
      background-color: rgba(0,0,0,0.3);
    }
    .thunar .standard-view .view {
      background-color: rgba(0,0,0,0.2);
    }
    .thunar toolbar {
      background-color: rgba(0,0,0,0.1);
    }
    .thunar,
    .thunar menubar,
    .thunar .shortcuts-pane
    {
      background-color: rgba(0,0,0,0.5);
    }
    .thunar toolbar > * > * > * > *
    {
      background-color: rgba(0,0,0,0.3);
    }
  '';

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

  xdg.desktopEntries = lib.mkIf isLinux {
    "xivlauncher-rb" = {
      name = "XIVLauncher-RB";
      icon = "xivlauncher";
      exec = "sh -c \"SDL_VIDEODRIVER=wayland XIVLauncher.Core\"";
      terminal = false;
      type = "Application";
      categories = ["Game"];
    };
  };
}
