{
  config,
  lib,
  pkgs,
  ...
}:
let
  defaultVaultPath = "${config.home.homeDirectory}/Obsidian Vault";
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
    force = true;
    text = builtins.toJSON {
      vaults.vault = {
        path = vaultPath;
        ts = 0;
        open = true;
      };
    };
  };
}
