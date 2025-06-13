{
  pkgs,
  lib,
  ...
}: {
  programs.nixvim = {
    ###########################################################################
    # Plugins                                                                 #
    ###########################################################################
    plugins.avante = {
      enable = true;

      # Core behaviour -------------------------------------------------------
      settings = {
        provider = "openai";
        chat_max_line_count = 300;

        # Pull the token & optional proxy from your shell env
        providers.openai = {
          model = "o3";
          extra_request_body = {
            max_completion_tokens = 8192;
            reasoning_effort = "medium";
            temperature = 0.2;
          };
        };

        # A comfy, semi-transparent floating window
        window = {
          border = "rounded";
          width = 0.6; # percentage of screen
          height = 0.6;
          backdrop = 0.2; # dim the background slightly
        };
      };
    };

    # Avante & helper plugins in one place -----------------------------------
    extraPlugins = with pkgs.vimPlugins; [
      img-clip-nvim # Paste images from clipboard into the buffer
      avante-nvim # Avante core plugin, kept on same revision as its dependencies
      plenary-nvim # Utility library of Lua functions used by many plugins
      nui-nvim # UI component library powering Neovim plugins
      dressing-nvim # Enhances Neovim's built-in UI for input and select dialogs
      nvim-web-devicons # Adds file-type icons to Neovim
      render-markdown-nvim # Render Markdown content inside Neovim
      which-key-nvim # Displays available keybindings in a popup
    ];

    ###########################################################################
    # Keymaps                                                                 #
    ###########################################################################
    keymaps = let
      map = mode: key: cmd: desc: {
        inherit mode key;
        action = "<cmd>" + cmd + "<CR>";
        options.desc = desc;
      };
    in [
      # Top-level: toggle chat
      (map "n" "<leader>aa" "AvanteToggle" "AI chat")

      # Ask mode (normal/visual)
      (map ["n" "v"] "<leader>ag"
        "lua require('avante.api').ask{question='Correct the text to standard English, but keep any code blocks inside intact.'}"
        "Grammar fix")
      (map ["n" "v"] "<leader>as"
        "lua require('avante.api').ask{question='Summarise the following text'}"
        "Summarise")

      # Edit mode (visual) – pre-fill prompt then <C-s> to send
      (map "v" "<leader>aG"
        "lua require('avante.utils').prefill_edit('Correct the text to standard English, but keep any code blocks inside intact.')"
        "Grammar fix (edit)")
      (map "v" "<leader>aO"
        "lua require('avante.utils').prefill_edit('Optimize the following code')"
        "Optimise code")
    ];

    ###########################################################################
    # Lua helpers                                                             #
    ###########################################################################
    extraConfigLua = ''
      -- Simple helper that mimics the wiki’s prefill_edit_window ----------------
      local M = {}
      function M.prefill_edit(request)
        require('avante.api').edit()
        local bufnr = vim.api.nvim_get_current_buf()
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { request })
        vim.api.nvim_win_set_cursor(0, {1, #request + 1})
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<C-s>', true, true, true), 'v', true)
      end
    '';

    ###########################################################################
    # which-key                                                               #
    ###########################################################################
    plugins.which-key.enable = true;
    plugins.which-key.settings.spec = [
      {
        lhs = "<leader>a"; # the key sequence
        name = "+Avante"; # label shown by which-key (“+” hides the rhs)
      }
    ];
  };
}
