{pkgs, lib, ...}: {
  imports = [
    ./airline.nix
    # ./coc.nix
    ./lsp.nix
    ./fzf.nix
    ./commentary.nix
    ./flash.nix
    ./hop.nix
    ./avante.nix
    ./obsidian.nix
  ];
  programs.nixvim = {
    colorschemes.ayu = {
      enable = true;
      settings.overrides = {
        Normal = { bg = "None"; };
        NormalFloat = { bg = "None"; };
        ColorColumn = { bg = "None"; };
        SignColumn = { bg = "None"; };
        Folded = { bg = "None"; };
        FoldColumn = { bg = "None"; };
        CursorLine = { bg = "None"; };
        CursorColumn = { bg = "None"; };
        VertSplit = { bg = "None"; };
      };
    };
    nixpkgs.useGlobalPackages = true;
    extraPackages = [
      pkgs.nodejs
    ];
    globals.copilot_node_command = lib.mkForce "${pkgs.nodejs}/bin/node";

    plugins = {
      indent-blankline.enable = true;
      treesitter.enable = true;
      rainbow-delimiters = {
        enable = true;
      };
      # todo camelcase motion
      commentary = {
        enable = true;
      };

      copilot-vim.enable = true;
    };
  };
}
