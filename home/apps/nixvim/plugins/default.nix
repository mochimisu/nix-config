{pkgs, ...}: {
  imports = [
    ./airline.nix
    ./coc.nix
    ./fzf.nix
    ./commentary.nix
    ./flash.nix
    ./hop.nix
  ];
  programs.nixvim = {
    colorschemes.ayu.enable = true;

    plugins = {
      indent-blankline.enable = true;
      treesitter.enable = true;
      rainbow-delimiters = {
        enable = true;
      };
      # todo camelcase motion
      # todo grep
      commentary = {
        enable = true;
      };

      copilot-vim.enable = true;
    };
  };
}
