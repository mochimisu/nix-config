{
  inputs,
  lib,
  pkgs,
  ...
}: let
  archiveRoot = "/earth/blackvue";
  json = pkgs.formats.json {};
  vehicles = [
    {
      id = "blackvue-boxster";
      owner = "brandon";
      group = "users";
      directoryMode = "0775";
      image = ./dashcam-viewer-assets/boxster.webp;
      metadata = {
        schemaVersion = 1;
        archive.format = "blackvue";
        vehicle = {
          displayName = "Boxster";
          make = "Porsche";
          model = "Boxster";
          year = 2009;
          colorName = "Black";
          colorHex = "#34383d";
          archiveLabel = "Primary archive";
          image = ".dashcam-viewer-vehicle.webp";
        };
      };
    }
    {
      id = "blackvue-taycan";
      owner = "brandon";
      group = "users";
      directoryMode = "0775";
      image = ./dashcam-viewer-assets/taycan.webp;
      metadata = {
        schemaVersion = 1;
        archive.format = "blackvue";
        vehicle = {
          displayName = "Taycan";
          make = "Porsche";
          model = "Taycan 4S";
          year = 2020;
          colorName = "White";
          colorHex = "#e7e7e4";
          archiveLabel = "Primary archive";
          image = ".dashcam-viewer-vehicle.webp";
        };
      };
    }
    {
      id = "blackvue-taycan-old";
      owner = "brandon";
      group = "users";
      directoryMode = "0775";
      image = ./dashcam-viewer-assets/taycan.webp;
      metadata = {
        schemaVersion = 1;
        archive.format = "blackvue";
        vehicle = {
          displayName = "Taycan Archive";
          make = "Porsche";
          model = "Taycan 4S";
          year = 2020;
          colorName = "White";
          colorHex = "#e7e7e4";
          archiveLabel = "Legacy footage";
          image = ".dashcam-viewer-vehicle.webp";
        };
      };
    }
    {
      id = "tesla-redbean";
      # TeslaUSB's declarative account uses stable UID 1500. Keep the numeric
      # owner usable even while its separate ingest-module change is staged.
      owner = "1500";
      group = "media";
      directoryMode = "2775";
      image = ./dashcam-viewer-assets/redbean.webp;
      metadata = {
        schemaVersion = 1;
        archive.format = "teslausb";
        vehicle = {
          displayName = "Redbean";
          make = "Tesla";
          model = null;
          year = null;
          colorName = null;
          colorHex = "#69717c";
          archiveLabel = "TeslaUSB archive";
          image = ".dashcam-viewer-vehicle.webp";
        };
      };
    }
  ];
  configuredVehicles = map (vehicle:
    vehicle
    // {
      metadataFile = json.generate "dashcam-viewer-${vehicle.id}.json" vehicle.metadata;
    })
  vehicles;
in {
  imports = [inputs.dashcam-viewer.nixosModules.default];

  services.dashcam-viewer = {
    enable = true;
    videoRoot = archiveRoot;
    port = 3000;
    openFirewall = true;

    # Keep access aligned with the archive ingest jobs. In particular, Brandon
    # is also in `media`, which owns the TeslaUSB archive.
    user = "brandon";
    group = "users";
    createUser = false;
    archiveWritable = true;

    environment = {
      DASHCAM_TESLAUSB_STATUS_CONFIG = builtins.toJSON {
        tesla-redbean = {
          target = "root@192.168.1.161";
          identityFile = "/run/credentials/dashcam-viewer.service/teslausb-status-key";
        };
      };
      DASHCAM_TESLAUSB_STATUS_SSH_PATH = lib.getExe pkgs.openssh;
    };

    after = ["earth.mount" "dashcam-viewer-archive-config.service"];
    requires = ["earth.mount" "dashcam-viewer-archive-config.service"];
  };

  systemd.services.dashcam-viewer.serviceConfig.LoadCredential = [
    "teslausb-status-key:/home/brandon/.ssh/id_ed25519_teslausb"
  ];

  systemd.services.dashcam-viewer-archive-config = {
    description = "Install Dashcam Viewer vehicle metadata and artwork";
    after = ["earth.mount"];
    requires = ["earth.mount"];
    before = ["dashcam-viewer.service"];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    script =
      lib.concatMapStringsSep "\n" (vehicle: ''
        ${pkgs.coreutils}/bin/install -d -m ${vehicle.directoryMode} -o ${vehicle.owner} -g ${vehicle.group} '${archiveRoot}/${vehicle.id}'
        ${pkgs.coreutils}/bin/install -m 0664 -o ${vehicle.owner} -g ${vehicle.group} '${vehicle.metadataFile}' '${archiveRoot}/${vehicle.id}/.dashcam-viewer.json'
        ${pkgs.coreutils}/bin/install -m 0664 -o ${vehicle.owner} -g ${vehicle.group} '${vehicle.image}' '${archiveRoot}/${vehicle.id}/.dashcam-viewer-vehicle.webp'
      '')
      configuredVehicles;
  };
}
