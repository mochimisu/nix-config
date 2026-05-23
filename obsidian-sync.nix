{
  config,
  lib,
  ...
}: let
  hostName = config.networking.hostName;
  isGaia = hostName == "gaia";

  devices = {
    gaia.id = "XQIBVXP-GOKDEV5-SZ2JD43-VQTHAFK-XWEQW6R-JZUP7W3-OPG5OJ3-PCEO5AH";
    blackmoon.id = "76MRCNR-ILIME3O-6ERD6DK-I6NQ4K2-FBOXCY6-SFRXXHR-5Y5XK6M-TSIXUAK";
    oasis.id = "3R7C3XS-VLVI4G3-CLHAEKS-IRCFNV6-VH7TXY5-2UP7GPR-MCNSWRR-75R6YAG";
    "Z Flip 7".id = "3MH7HAJ-X7S3ELW-IVQVNF7-5DFLL4X-JP252S7-FSFMFRZ-K2IHDMY-ER7XIQJ";
    # Add espresso/glasscastle/oasis here after each host has generated a
    # Syncthing device ID. Device IDs are public peer identities, not secrets.
  };

  nixosClientDevices = lib.filterAttrs (name: _: name != "gaia" && name != "Z Flip 7") devices;
  knownNixosClientNames = builtins.attrNames nixosClientDevices;

  ignorePatterns = [
    "(?d).obsidian/workspace.json"
    "(?d).obsidian/workspace-mobile.json"
  ];

  versioning = {
    type = "trashcan";
    params.cleanoutDays = "30";
  };
in {
  services.syncthing = {
    enable = true;
    user = "brandon";
    group = "users";
    dataDir = lib.mkIf isGaia "/earth/syncthing";
    configDir = lib.mkIf isGaia "/earth/syncthing/.config/syncthing";
    guiAddress = lib.mkIf isGaia "0.0.0.0:8384";
    openDefaultPorts = true;
    overrideDevices = lib.mkDefault false;
    overrideFolders = lib.mkIf isGaia true;
    settings = {
      options.urAccepted = -1;
      devices =
        if isGaia
        then devices
        else {
          gaia = devices.gaia;
        };
      folders.obsidian = {
        id = "obsidian";
        label = "Obsidian";
        path =
          if isGaia
          then "/earth/syncthing/obsidian"
          else "/home/brandon/Obsidian Vault";
        devices =
          if isGaia
          then knownNixosClientNames ++ ["Z Flip 7"]
          else ["gaia"];
        inherit ignorePatterns versioning;
      };
    };
  };

  systemd.tmpfiles.rules = lib.mkIf isGaia [
    "d /earth/syncthing 0775 brandon users - -"
    "d /earth/syncthing/.config 0775 brandon users - -"
    "d /earth/syncthing/.config/syncthing 0775 brandon users - -"
    "d /earth/syncthing/obsidian 0775 brandon users - -"
    "d /earth/syncthing/obsidian/.stversions 0775 brandon users - -"
  ];
}
