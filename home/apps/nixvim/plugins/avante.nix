{pkgs, ...}: {
  programs.nixvim.plugins.avante = {
    enable = true;
    settings = {
      provider = "openai";
    };
  };
  programs.nixvim.extraPlugins = [
    pkgs.vimPlugins.img-clip-nvim
  ];
}
