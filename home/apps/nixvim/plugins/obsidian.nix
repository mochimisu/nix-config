{ config, ... }:
let
  vaultPath = "${config.home.homeDirectory}/Obsidian";
in {
  programs.nixvim.plugins.obsidian = {
    enable = true;
    settings = {
      workspaces = [
        {
          name = "vault";
          path = vaultPath;
        }
      ];
      completion.nvim_cmp = true;
      legacy_commands = false;
      opts = {
        legacy_commands = false;
      };
    };
  };

  home.file."Obsidian/.keep".text = "";
}
