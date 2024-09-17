{ config, pkgs, lib, inputs, ...}:

let
  configsDir = "${config.home.homeDirectory}/stuff/configs";
in
{
  home.stateVersion = "24.11";
  home.packages = with pkgs; [ 
    git
    oh-my-zsh
  ];

  imports = [
    ./apps/hypr/hyprland.nix
    ./apps/hypr/hyprpaper.nix
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
      oh-my-zsh = {
        enable = true;
        theme = "agnoster";
        plugins = [
          "sudo"
          "git"
          "ssh-agent"
        ];
      };
    };
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

    #".config/hypr".source = "${configsDir}/.config/hypr";
    #".config/nvim".source = "${configsDir}/.config/nvim";
    #".config/waybar".source = "${configsDir}/.config/waybar";
    #".tmux.conf".source = "${configsDir}/.tmux.conf";
  };
  #
  # home.activation = {
  #   cloneRepo = lib.hm.dag.entryAfter ["writeBoundary"] ''
  #   if [ -d ${configsDir} ]; then
  #     echo "configs exist"
  #   else
  #     ${pkgs.git}/bin/git clone https://github.com/mochimisu/configs.git ${configsDir}
  #   fi
  #   ln -sfn ${configsDir}/.config/nvim ${config.home.homeDirectory}/.config/nvim
  #
  #   '';
  # };
}

