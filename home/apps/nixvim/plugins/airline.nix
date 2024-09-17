{pkgs, ...}: {
  programs.nixvim = {
    plugins.airline = {
      enable = true;
      settings = {
        powerline_fonts = 1;
        theme = "jellybeans";
      };
      # TODO battery
    };
    extraPlugins = [
      pkgs.vimPlugins.vim-airline-themes
    ];
  };
}


