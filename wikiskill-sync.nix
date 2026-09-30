{ config, lib, ... }:
let
  host = config.networking.hostName;
  enabled = builtins.elem host [ "blackmoon" "gaia" ];
in {
  # Reuse devices, identity, transport and service ownership from obsidian-sync.nix.
  services.syncthing.settings.folders.wikiskill = lib.mkIf enabled {
    id = "wikiskill";
    label = "Wikiskill";
    path = "/home/brandon/stuff/wikiskill";
    devices = [ (if host == "gaia" then "blackmoon" else "gaia") ];
    type = "sendreceive";
    fsWatcherEnabled = true;
    fsWatcherDelayS = 10;
    rescanIntervalS = 3600;
    ignorePerms = true;
    # Keep up to one million received versions per file, without age expiry.
    # This is not a backup of edits made locally on this device.
    versioning = {
      type = "simple";
      params = { keep = "1000000"; cleanoutDays = "0"; };
    };
    maxConflicts = -1;
    ignorePatterns = [
      "/.git" "/.codex" "/.agents" "/node_modules"
      "/wiki/dist" "/_exports" "/_sources/automation-runs"
      "__pycache__" ".DS_Store" "*.tmp" "*.swp" "*~"
      # Host-local state/config/credentials must never become shared corpus.
      "/.config" "/.local" "/.env" "/.env.*" "/.AGENTS.LOCAL.md"
    ];
  };
}
