{ pkgs, lib, config, ... }:
{
  home.packages = with pkgs; [
    # FZF replacement
    fd
  ];
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
    "gitp" = "GIT_SSH_COMMAND='ssh -i ~/.ssh/id_ed25519-personal -o IdentitiesOnly=yes' git push --no-verify";
  };

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
          family = "Cascadia Code PL";
          style  = "Regular";
        };
        bold = {
          family = "Cascadia Code PL";
          style  = "Bold";
        };
        italic = {
          family = "Cascadia Code PL";
          style  = "Italic";
        };
      };

      # Color scheme
      colors = {
        primary = {
          background = "#000000";
          foreground = "#FFFFFF";
        };

        normal = {
          black   = "#1a1a1a";
          red     = "#f4005f";
          green   = "#98e024";
          yellow  = "#fa8419";
          blue    = "#9d65ff";
          magenta = "#f4005f";
          cyan    = "#58d1eb";
          white   = "#c4c5b5";
        };

        bright = {
          black   = "#625e4c";
          red     = "#f4005f";
          green   = "#98e024";
          yellow  = "#e0d561";
          blue    = "#9d65ff";
          magenta = "#f4005f";
          cyan    = "#58d1eb";
          white   = "#f6f6ef";
        };
      };

      # Custom key binding
      keyboard.bindings = [
        {
          action = "ToggleSimpleFullscreen";
          key    = "Return";
          mods   = "Super";
        }
      ];
    };
  };
  
}
