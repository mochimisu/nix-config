{ config, pkgs, lib, ... }:
{
  home.packages = with pkgs; [
    nodejs
  ];
  programs.nixvim.extraPlugins = [
    pkgs.vimPlugins.coc-nvim
    pkgs.vimPlugins.coc-tsserver
    pkgs.vimPlugins.coc-json
    pkgs.vimPlugins.coc-css
    pkgs.vimPlugins.coc-eslint
    pkgs.vimPlugins.coc-prettier
    pkgs.vimPlugins.coc-html
    pkgs.vimPlugins.coc-python
    pkgs.vimPlugins.coc-pyright
  ];

  programs.nixvim = {
    enable = true;
    opts = {
      encoding = "utf-8";  # Set encoding to utf-8
      hidden = true;       # Enable hidden buffers
      cmdheight = 2;       # Give more space for messages
      updatetime = 300;    # Faster update time
      shortmess = "c";     # Don't pass messages to completion menu
      signcolumn = "yes";  # Always show signcolumn
      statusline = "%{coc#status()}%{get(b:, 'coc_current_function', '')}";  # Statusline
    };
    plugins = {
      lsp = {
        enable = true;
        servers = {
          jedi_language_server = {
            enable = true;
          };
        };
      };
    };

    keymaps = config.lib.nixvim.keymaps.mkKeymaps
    {}
    (
      lib.mapAttrsToList (key: action: {
        mode = "n";
        inherit action key;
      }) {
        "[g" = "<Plug>(coc-diagnostic-prev)";
        "]g" = "<Plug>(coc-diagnostic-nexs)";
        "gd" = "<Plug>(coc-definition)";
        "gy" = "<Plug>(coc-type-definition)";
        "gi" = "<Plug>(coc-implementation)";
        "gr" = "<Plug>(coc-references)";
        "<leader>rn" = "<Plug>(coc-rename)";
        "<leader>f" = "<Plug>(coc-format-selected)";
        "<leader>ac" = "<Plug>(coc-codeaction)";
        "<leader>qf" = "<Plug>(coc-fix-current)";
        "<leader>cl" = "<Plug>(coc-codelens-action)";
        "<F2>" = ":bprevious<CR>";
        "<F3>" = ":bnext<CR>";
        "<space>a" = ":<C-u>CocList diagnostics<CR>";
        "<space>e" = ":<C-u>CocList extensions<CR>";
        "<space>c" = ":<C-u>CocList commands<CR>";
        "<space>o" = ":<C-u>CocList outline<CR>";
        "<space>s" = ":<C-u>CocList -I symbols<CR>";
        "<space>j" = ":<C-u>CocNext<CR>";
        "<space>k" = ":<C-u>CocPrev<CR>";
        "<space>p" = ":<C-u>CocListResume<CR>";
      }
      ++
      lib.mapAttrsToList (key: action: {
        mode = "v";
        inherit action key;
      }) {
        "<leader>f" = "<Plug>(coc-format-selected)";
        "<leader>a" = "<Plug>(coc-codeaction-selected)";
      }
      ++
      lib.mapAttrsToList (key: action: {
        mode = "i";
        inherit action key;
        options = {
          silent = true;
          expr = true;
          noremap = true;
        };
      }) {
        "<CR>" = "coc#pum#visible() ? coc#pum#confirm() : \"\\<C-g>u\\<CR>\\<c-r>=coc#on_enter()\\<CR>\"";
        "<C-x><C-z>" = "coc#pum#visible() ? coc#pum#stop() : \"\\<C-x><C-z>\"";
        # "<TAB>" = "coc#pum#visible() ? coc#pum#next(1) : <SID>check_back_space() ? \"\\<Tab>\" : coc#refresh()";
        # "<S-TAB>" = "coc#pum#visible() ? coc#pum#prev(1) : \"\\<C-h>\"";
        "<C-Space>" = "coc#refresh()";
      }
    );
    autoCmd = [
    {
      event = [ "CursorHold" ];
      command = "silent call CocActionAsync('highlight')";
    }
    {
      event = [ "FileType" ];
      pattern = [ "typescript" "json" ];
      command = "setl formatexpr=CocAction('formatSelected')";
    }
    {
      event = [ "User" ];
      pattern = [ "CocJumpPlaceholder" ];
      command = "call CocActionAsync('showSignatureHelp')";
    }
    ];
    userCommands = {
      Format = {
        command = "call CocActionAsync('format')";
      };
      Fold = {
        command = "call CocAction('fold')";
      };
      OR = {
        command = "call CocActionAsync('runCommand', 'editor.action.organizeImport')";
      };
    };
  };

  home.file.".config/nvim/coc-settings.json".text = ''
{
"eslint.autoFixOnSave": true,
"tslint.autoFixOnSave": true,
"eslint.filetypes": ["javascript", "javascriptreact", "typescript", "typescriptreact"],
"tslint.filetypes": ["typescript", "typescriptreact"],
"pyright.inlayHints.functionReturnTypes": false,
"pyright.inlayHints.variableTypes": false,
"pyright.inlayHints.parameterTypes": false,
"pyright.disableDiagnostics": true,
"[javascript][javascriptreact][typescript][typescriptreact][python]": {
  "coc.preferences.formatOnSave": true
},
"tsserver.formatOnType": true,
"coc.preferences.formatOnType": true,
"typescript.autoClosingTags": false,
}
  '';
}
