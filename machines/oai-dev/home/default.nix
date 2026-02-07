{
  pkgs,
  lib,
  config,
  ...
}: {
  imports = [
    ./fastfetch.nix
    ./mac-apps.nix
  ];

  home.packages = with pkgs; [
    # FZF replacement
    fd
    # vconv
    ffmpeg

    # utils
    watch
    fx
    autoraise
    lazygit

    nerd-fonts.caskaydia-cove
    source-sans

    discord
  ];
  programs.aerospace.settings.start-at-login = true;
  programs.nixvim = {
    plugins.fzf-lua = {
      settings = {
        files = {
          git_icons = false;
        };
      };
    };
    plugins.lsp.capabilities = ''
      capabilities.workspace.didChangeWatchedFiles.dynamicRegistration = false
    '';
  };
  programs.wofi.enable = lib.mkForce false;
  programs.spotify-player.enable = lib.mkForce false;

  home.file.".config/nvim/coc-settings.json".text = lib.mkForce ''
    {
      "eslint.autoFixOnSave": true,
        "tslint.autoFixOnSave": true,
        "eslint.filetypes": ["javascript", "javascriptreact", "typescript", "typescriptreact"],
        "tslint.filetypes": ["typescript", "typescriptreact"],
        "pyright.inlayHints.functionReturnTypes": false,
        "pyright.inlayHints.variableTypes": false,
        "pyright.inlayHints.parameterTypes": false,
        "pyright.disableDiagnostics": true,
        "[javascript][javascriptreact][typescript][typescriptreact]": {
          "coc.preferences.formatOnSave": true
        },
        "tsserver.formatOnType": true,
        "coc.preferences.formatOnType": true,
        "typescript.autoClosingTags": false,
        "python.pythonPath": "/Users/brandonw/.virtualenvs/openai/bin/python",
    }
  '';
  home.file.".config/lazygit/config.yml".text = ''
    git:
      autoFetch: false
  '';

  home.shellAliases = {
    "nix-rs" = lib.mkForce "sudo nix run nix-darwin -- switch --flake ${config.home.homeDirectory}/stuff/nix-config#oai-dev";
    "gitp" = "GIT_SSH_COMMAND='ssh -i ~/.ssh/id_ed25519_personal -o IdentitiesOnly=yes' git push --no-verify";
    "cdc" = "cd ~/code/openai/chatgpt";
    "cdcw" = "cd ~/code/openai/chatgpt/web";
    "cdcs" = "cd ~/code/openai/chatgpt/search-service";
  };
  # catppuccin = {
  #   enable = true;
  #   flavor = "mocha";
  # };
  programs.zsh.envExtra = ''
    source ~/.zshenv-local
  '';

  # Prefer kitty on macOS for this machine.
  programs.alacritty.enable = lib.mkForce false;
  programs.kitty = {
    enable = lib.mkForce true;
    font = {
      name = "CaskaydiaCove Nerd Font";
      size = 13;
    };
    keybindings = {
      "cmd+enter" = "toggle_fullscreen";
    };
    settings = {
      allow_remote_control = "yes";
      background_opacity = 0.8;
      font_family = "CaskaydiaCove Nerd Font";
      bold_font = "CaskaydiaCove Nerd Font Bold";
      italic_font = "CaskaydiaCove Nerd Font Italic";
      hide_window_decorations = "yes";
      macos_traditional_fullscreen = true;
      macos_thicken_font = 0.05;
    };
  };
}
