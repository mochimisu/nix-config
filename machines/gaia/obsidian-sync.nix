{...}: {
  services.syncthing = {
    enable = true;
    user = "brandon";
    group = "users";
    dataDir = "/earth/syncthing";
    configDir = "/earth/syncthing/.config/syncthing";
    guiAddress = "0.0.0.0:8384";
    openDefaultPorts = true;
    overrideDevices = false;
    overrideFolders = true;
    settings = {
      options = {
        urAccepted = -1;
      };
      folders = {
        obsidian = {
          path = "/earth/syncthing/obsidian";
          id = "obsidian";
          label = "Obsidian";
          devices = [];
          ignorePatterns = [
            "(?d).obsidian/workspace.json"
            "(?d).obsidian/workspace-mobile.json"
          ];
          versioning = {
            type = "trashcan";
            params.cleanoutDays = "30";
          };
        };
      };
    };
  };

  systemd.tmpfiles.rules = [
    "d /earth/syncthing 0775 brandon users - -"
    "d /earth/syncthing/.config 0775 brandon users - -"
    "d /earth/syncthing/.config/syncthing 0775 brandon users - -"
    "d /earth/syncthing/obsidian 0775 brandon users - -"
    "d /earth/syncthing/obsidian/.stversions 0775 brandon users - -"
  ];
}
