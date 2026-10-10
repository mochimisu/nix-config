# User-approved Gaia/Comet private Obsidian vault sharing.
{ config, lib, ... }:
let
  vault = "/home/steamos/Obsidian Vault";
  others = lib.filterAttrs (n: _: n != "obsidian") config.services.syncthing.settings.folders;
  overlaps = a: b: a == b || lib.hasPrefix "${a}/" b || lib.hasPrefix "${b}/" a;
in {
  assertions = [
    { assertion = config.home.username == "steamos"; message = "Comet Obsidian overlay is for steamos."; }
    { assertion = builtins.all (f: !(overlaps f.path vault)) (builtins.attrValues others); message = "Obsidian vault overlaps another Syncthing folder."; }
  ];
  services.syncthing = {
    enable = true;
    settings.devices.gaia = {
      id = "XQIBVXP-GOKDEV5-SZ2JD43-VQTHAFK-XWEQW6R-JZUP7W3-OPG5OJ3-PCEO5AH";
      addresses = lib.mkDefault [ "tcp://192.168.1.35:22000" ];
    };
    settings.options = {
      globalAnnounceEnabled = lib.mkDefault false;
      localAnnounceEnabled = lib.mkDefault false;
      relaysEnabled = lib.mkDefault false;
      natEnabled = lib.mkDefault false;
      listenAddresses = lib.mkDefault [ "tcp://127.0.0.1:22000" ];
    };
    settings.folders.obsidian = {
      id = "obsidian";
      label = "Obsidian";
      path = vault;
      type = "sendreceive";
      devices = [ "gaia" ];
      ignorePatterns = [ "(?d).obsidian/workspace.json" "(?d).obsidian/workspace-mobile.json" ];
      versioning = { type = "trashcan"; params.cleanoutDays = "30"; };
    };
  };
  # No SD dependency: Obsidian must keep working when removable media is absent.
}
