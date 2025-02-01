{ ... }:
{
  imports = [
    ./p10k.nix
  ];

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    zplug = {
      enable = true;
      plugins = [
      {
        name = "zsh-users/zsh-history-substring-search";
        tags = [ "as:plugin" "depth:1" ];
      }
      {
        name = "chisui/zsh-nix-shell";
        tags = [ "as:plugin" "depth:1" ];
      }
      {
        name = "bobsoppe/zsh-ssh-agent";
        tags = [ "as:plugin" "depth:1" ];
      }
      ];
    };
    initExtra = ''
      # ssh-agent lazy loading
      zstyle :omz:plugins:ssh-agent lazy yes
      bindkey "^[[A" up-line-or-search
      bindkey "^[[B" down-line-or-search
      # disable ctrl s/q
      stty -ixon
    '';
  };
}
