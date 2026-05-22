{
  config,
  lib,
  pkgs,
  ...
}:
let
  defaultVaultPath = "${config.home.homeDirectory}/Obsidian";
  vaultPath = config.variables.obsidianVaultPath or defaultVaultPath;
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

  home.file."Obsidian/.keep" = lib.mkIf (vaultPath == defaultVaultPath) {
    text = "";
  };

  xdg.configFile."obsidian/obsidian.json" = lib.mkIf pkgs.stdenv.isLinux {
    text = builtins.toJSON {
      vaults.vault = {
        path = vaultPath;
        ts = 0;
        open = true;
      };
    };
  };
}
