{
  imports = [
    ./airline.nix
    ./coc.nix
    ./fzf.nix
    ./commentary.nix
    ./flash.nix
    ./hop.nix
    ./avante.nix
  ];
  programs.nixvim = {
    colorschemes.ayu.enable = true;
    nixpkgs.useGlobalPackages = true;

    plugins = {
      indent-blankline.enable = true;
      treesitter.enable = true;
      rainbow-delimiters = {
        enable = true;
      };
      # todo camelcase motion
      commentary = {
        enable = true;
      };

      copilot-vim.enable = true;
    };
  };
}
