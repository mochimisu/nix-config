{pkgs, ...}: {
  imports = [];
  programs.nixvim = {
    colorschemes.ayu.enable = true;

    plugins = {
      indent-blankline = {
        enable = true;
      };
      airline = {
        enable = true;
        settings = {
          powerline_fonts = 1;
          theme = "jellybeans";
        };
        # TODO battery
      };
      # how to configure this?
      rainbow-delimiters = {
        enable = true;
      };
      # todo easymotion
      # todo camelcase motion
      # todo tcomment
      fzf-lua = {
        enable = true;
        keymaps = {
          "<C-p>" = {
            action = "files";
            mode = ["n" "v"];
          };
        };
      };
      # todo grep
      # todo coc
    };
    extraPlugins = [
      (pkgs.vimUtils.buildVimPlugin {
       name = "vim-airline-themes";
       src = pkgs.fetchFromGitHub {
       owner = "vim-airline";
       repo = "vim-airline-themes";
       rev = "master";
       hash = "sha256-XwlNwTawuGvbwq3EbsLmIa76Lq5RYXzwp9o3g7urLqM=";
       };
       })
    ];
    };
}
