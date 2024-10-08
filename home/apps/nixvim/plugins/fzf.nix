{ pkgs, ... }:
{
  home.packages = with pkgs; [
    fzf
  ];

  programs.nixvim.plugins.fzf-lua = {
    enable = true;
    keymaps = {
      "<C-p>" = {
        action = "files";
        mode = ["n" "v"];
      };
    };
  };
}
