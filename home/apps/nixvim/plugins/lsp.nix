{
  lib,
  pkgs,
  ...
}: {
  programs.nixvim = {
    ##############################################################################
    # 1 ─ Enable Nixvim’s built-in LSP layer
    ##############################################################################
    keymaps = [
      {
        mode = "n";
        key = "E"; # Shift+e
        action = "<cmd>lua vim.diagnostic.open_float()<CR>";
        options = {
          silent = true;
          noremap = true;
          desc = "LSP diagnostics float";
        };
      }
    ];
    plugins.lsp = {
      enable = true;

      # -------------------------------------------------------------------------
      # 1.1  Which language-servers to start
      # -------------------------------------------------------------------------
      servers = {
        # JavaScript / TypeScript
        ts_ls.enable = true;

        # HTML / CSS-like embedded languages
        html.enable = true;

        # Python
        pyright = {
          enable = true;
          settings = {
            python.analysis = {
              # identical to your CoC tweaks
              diagnosticMode = "openFilesOnly";
              typeCheckingMode = "basic"; # or "off" if you only need jumps
            };
            # Faster root detection than Pyright’s default (HOME)
            rootDirectory = {
              patterns = ["pyproject.toml" "setup.cfg" "setup.py" ".git"];
            };
          };
        };
      };

      # -------------------------------------------------------------------------
      # 1.2  Handy default key-maps (feel free to change)
      # -------------------------------------------------------------------------
      keymaps = {
        silent = true;
        lspBuf = {
          "gd" = "definition"; # go-to definition  (your old CocAction)
          "gr" = "references";
          "gD" = "declaration";
          "gi" = "implementation";
          "K" = "hover";
          "<leader>rn" = "rename";
          "<leader>ca" = "code_action";
        };
      };
    };

    ##############################################################################
    # 2 ─ Completion: nvim-cmp + LuaSnip (closest match to CoC experience)
    ##############################################################################
    extraPlugins = with pkgs.vimPlugins; [
      nvim-cmp
      cmp-nvim-lsp
      cmp-buffer
      cmp-path
      luasnip
      cmp_luasnip

      # color yuck
      yuck-vim
    ];

    # Minimal Lua snippet to wire cmp → LSP
    extraConfigLua = ''
      local cmp = require'cmp'
      local luasnip = require'luasnip'

      cmp.setup({
          snippet = { expand = function(args) luasnip.lsp_expand(args.body) end },
          mapping = cmp.mapping.preset.insert({
              ['<C-Space>'] = cmp.mapping.complete(),
              ['<CR>']      = cmp.mapping.confirm({ select = true }),
              }),
          sources = {
          { name = 'nvim_lsp' },
          { name = 'luasnip'  },
          { name = 'path'     },
          { name = 'buffer'   },
          }
          })
    '';

    # ---------- formatters & auto-format on save ----------
    plugins."conform-nvim" = {
      enable = true;

      # 1.1  Which formatter(s) to run per filetype
      settings = {
        formatters_by_ft = {
          javascript = ["prettierd"]; # prettierd faster than prettier
          typescript = ["prettierd"];
          javascriptreact = ["prettierd"];
          typescriptreact = ["prettierd"];
          html = ["prettierd"];
          python = ["ruff_format"]; # ruff faster than black
          nix = ["alejandra"];
        };

        # 1.2  Run automatically whenever you write the buffer
        format_on_save = {
          lspFallback = true;
          timeoutMs = 10000;
        };
      };
    };

    # ---------- make sure the CLI tools are on $PATH ----------
    extraPackages = with pkgs; [
      prettierd
      ruff
      alejandra
    ];
  };
}
