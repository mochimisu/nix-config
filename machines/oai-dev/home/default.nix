{
  pkgs,
  lib,
  config,
  ...
}: {
  imports = [
    ./fastfetch.nix
  ];

  home.packages = with pkgs; [
    # FZF replacement
    fd
    # vconv
    ffmpeg

    # utils
    watch
    autoraise

    nerd-fonts.caskaydia-cove
    source-sans

    discord
  ];
  programs.aerospace.userSettings.start-at-login = true;
  programs.nixvim = {
    plugins.fzf-lua = {
      settings = {
        files = {
          git_icons = false;
        };
      };
    };
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

  # Use alacritty over kitty on macOS
  programs.kitty.enable = lib.mkForce false;
  programs.alacritty = {
    enable = true;

    # Main Alacritty settings
    settings = {
      font = {
        # Global font size
        size = 13.0;

        # Font faces
        normal = {
          family = "CaskaydiaCove Nerd Font";
          style = "Regular";
        };
        bold = {
          family = "CaskaydiaCove Nerd Font";
          style = "Bold";
        };
        italic = {
          family = "CaskaydiaCove Nerd Font";
          style = "Italic";
        };
      };

      # Custom key binding
      keyboard.bindings = [
        {
          action = "ToggleSimpleFullscreen";
          key = "Return";
          mods = "Super";
        }
      ];

      window = {
        opacity = 0.8;
        decorations = "transparent";
      };
    };
  };
}
