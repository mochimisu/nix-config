{ pkgs, ...}:
{
  home.packages = with pkgs; [
    nodejs
  ];
  programs.nixvim.extraPlugins = [
    pkgs.vimPlugins.coc-nvim
  ];

  #programs.nixvim.extraPlugins = [
  #  (pkgs.vimUtils.buildVimPlugin {
  #    name = "coc.nvim";
  #    src = builtins.fetchTarball "https://github.com/neoclide/coc.nvim/archive/master.tar.gz";
  #    build = "npm ci";
  #  })
  #];
}
