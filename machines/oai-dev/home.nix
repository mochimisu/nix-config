{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # FZF replacement
    fd
  ];
  programs.zsh = {
    initExtra = ''
    source ~/.zshrc-oai
    '';
  };
  programs.nixvim.plugins.fzf-lua = {
    settings = {
      files = {
        git_icons = false;
      };
    };
  };
}
