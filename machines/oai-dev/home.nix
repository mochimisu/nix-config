{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # FZF replacement
    fd
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
            name = "romkatv/powerlevel10k";
            tags = [ as:theme depth:1 ];
          }
          {
            name = "zsh-users/zsh-history-substring-search";
            tags = [ as:plugin depth:1 ];
          }
        ];
    };
    # work specific
    initExtra = ''
    source ~/.zshrc-oai
    '';
  };
}
