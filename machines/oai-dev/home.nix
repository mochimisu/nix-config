{ pkgs, lib, config, ... }:
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

  home.shellAliases = {
    "nix-rs" = lib.mkForce "nix run nix-darwin -- switch --flake ${config.home.homeDirectory}/stuff/nix-config";
  };
}
