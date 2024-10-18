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
  programs.nixvim = {
    plugins.fzf-lua = {
      settings = {
        files = {
          git_icons = false;
        };
      };
    };
  };

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
    "nix-rs" = lib.mkForce "nix run nix-darwin -- switch --flake ${config.home.homeDirectory}/stuff/nix-config#oai-dev";
  };
}
