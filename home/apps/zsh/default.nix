{
  pkgs,
  lib,
  ...
}: {
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
          tags = ["as:plugin" "depth:1"];
        }
        {
          name = "chisui/zsh-nix-shell";
          tags = ["as:plugin" "depth:1"];
        }
      ];
    };
    sessionVariables = {
      SDL_VIDEODRIVER = "wayland";
      # for gnome-keyring
      SSH_AUTH_SOCK = lib.optionalString pkgs.stdenv.isLinux "/run/user/$(id -u)/gcr/ssh";
    };

    shellAliases = {
      cdx = "codex --search --dangerously-bypass-approvals-and-sandbox";
      cdxr = "cdx resume";
    };

    initContent = ''
      bindkey "^[[A" up-line-or-search
      bindkey "^[[B" down-line-or-search
      # disable ctrl s/q
      stty -ixon
      export PATH="$HOME/.npm-global/bin:$PATH"
      # local zsh for things like keys
      [ -f ~/.zshrc-local ] && source ~/.zshrc-local
      if [[ -t 0 && -t 1 ]]; then
        fastfetch
      fi
    '';
  };
}
