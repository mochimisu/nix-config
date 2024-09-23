{ pkgs, ... }:
{
  home.packages = with pkgs; [
    fzf
  ];

  programs.nixvim.plugins.fzf-lua = {
    enable = true;
    settings = {
        files = {
            git_icons = false;
        };
    };
    keymaps = {
      "<C-p>" = {
        action = "files";
        mode = ["n" "v"];
      };
    };
  };
}
