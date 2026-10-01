{ config, lib, ... }:
{
  # Retain paused declarations so activation also stops previously configured folders.
  # Obsidian continues to use Syncthing independently.
  services.syncthing.settings.folders =
    lib.mkIf (builtins.elem config.networking.hostName [ "blackmoon" "gaia" ]) {
      wikiskill = {
        id = "wikiskill";
        path = "/home/brandon/stuff/wikiskill";
        paused = true;
      };
      wikiskill-plugin = {
        id = "wikiskill-plugin";
        path = "/home/brandon/plugins/wikiskill";
        paused = true;
      };
    };
}
