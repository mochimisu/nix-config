{ config, pkgs, lib, ...}:

let
  configsDir = "${config.home.homeDirectory}/stuff/configs";
in
{
  home.stateVersion = "24.05";
  home.packages = with pkgs; [ 
    git
    oh-my-zsh
  ];
  

  home.dconf.settings = {
    "org.gnome.desktop.interface" = {
      "gtk-theme" = "Adwaita-dark";
      "color-scheme" = "dark";
    };
  };

  programs = {
    dconf.enable = true;
    git = {
      enable = true;
      userName = "mochimisu";
      userEmail = "brandonwang@me.com";
      configExtra = {
        init.defaultBranch = main
      };
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
    neovim = {
      enable = true;
      defaultEditor = true;
    };
  };
  services.xdg-desktop-portal-gtk.enable = true;

  home.file = {

    #".config/hypr".source = "${configsDir}/.config/hypr";
    #".config/nvim".source = "${configsDir}/.config/nvim";
    #".config/waybar".source = "${configsDir}/.config/waybar";
    #".tmux.conf".source = "${configsDir}/.tmux.conf";
  };

  home.activation = {
    cloneRepo = lib.hm.dag.entryAfter ["writeBoundary"] ''
    if [ -d ${configsDir} ]; then
      echo "configs exist"
    else
      ${pkgs.git}/bin/git clone https://github.com/mochimisu/configs.git ${configsDir}
    fi
    ln -sfn ${configsDir}/.config/hypr ${config.home.homeDirectory}/.config/hypr
    ln -sfn ${configsDir}/.config/nvim ${config.home.homeDirectory}/.config/nvim
    ln -sfn ${configsDir}/.config/waybar ${config.home.homeDirectory}/.config/waybar
    ln -sfn ${configsDir}/.tmux.conf ${config.home.homeDirectory}/.tmux.conf

    '';
  };
}

