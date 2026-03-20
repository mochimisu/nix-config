{
  config,
  pkgs,
  lib,
  ...
}: let
  # Declarative desired pairings. Keep setup codes in encrypted sops secret env file
  # using the environment variable named in `code_env`.
  matterDesiredPairings = [
    {
      name = "Office Blinds";
      room = "Office";
      code_env = "MATTER_CODE_OFFICE_BLINDS";
      network_only = false;
      match = {
        mac_env = "MATTER_MAC_OFFICE_BLINDS";
      };
    }

    {
      name = "Office Blinds Remote";
      room = "Office";
      code_env = "MATTER_CODE_OFFICE_BLINDS_REMOTE";
      network_only = false;
      match = {
        mac = "da:21:d9:f7:cc:5d";
      };
    }

    {
      name = "Downstairs Thermostat";
      room = "Downstairs";
      code_env = "MATTER_CODE_DOWNSTAIRS_THERMOSTAT";
      network_only = false;
      match = {
        unique_id_env = "MATTER_UID_DOWNSTAIRS_THERMOSTAT";
      };
    }

    {
      name = "Upstairs Thermostat";
      room = "Upstairs";
      code_env = "MATTER_CODE_UPSTAIRS_THERMOSTAT";
      network_only = false;
      match = {
        unique_id_env = "MATTER_UID_UPSTAIRS_THERMOSTAT";
      };
    }

    {
      name = "Office Light";
      room = "Office";
      code_env = "MATTER_CODE_OFFICE_LIGHT";
      network_only = false;
      match = {
        unique_id_env = "MATTER_UID_OFFICE_LIGHT";
      };
    }

    {
      name = "Office Floor Lamp";
      room = "Office";
      code_env = "MATTER_CODE_OFFICE_FLOOR_LAMP";
      network_only = false;
      match = {
        unique_id_env = "MATTER_UID_OFFICE_FLOOR_LAMP";
      };
    }

    {
      name = "MBR Bathroom Main";
      room = "MBR Bathroom";
      code_env = "MATTER_CODE_MBR_BATHROOM_MAIN";
      network_only = false;
      match = {
        unique_id_env = "MATTER_UID_MBR_BATHROOM_MAIN";
      };
    }

    {
      name = "MBR Bathroom Warm";
      room = "MBR Bathroom";
      code_env = "MATTER_CODE_MBR_BATHROOM_WARM";
      network_only = false;
      match = {
        unique_id_env = "MATTER_UID_MBR_BATHROOM_WARM";
      };
    }

    {
      name = "MBR Bathroom Mirror";
      room = "MBR Bathroom";
      code_env = "MATTER_CODE_MBR_BATHROOM_MIRROR";
      network_only = false;
      match = {
        unique_id_env = "MATTER_UID_MBR_BATHROOM_MIRROR";
      };
    }

    {
      name = "MBR Bathroom Fan";
      room = "MBR Bathroom";
      code_env = "MATTER_CODE_MBR_BATHROOM_FAN";
      network_only = false;
      match = {
        unique_id_env = "MATTER_UID_MBR_BATHROOM_FAN";
      };
    }

    {
      name = "MBR Shower";
      room = "MBR Bathroom";
      code_env = "MATTER_CODE_MBR_SHOWER";
      network_only = false;
      match = {
        unique_id_env = "MATTER_UID_MBR_SHOWER";
      };
    }

    {
      name = "MBR Bathtub";
      room = "MBR Bathroom";
      code_env = "MATTER_CODE_MBR_BATHTUB";
      network_only = false;
      match = {
        unique_id_env = "MATTER_UID_MBR_BATHTUB";
      };
    }

    {
      name = "Office Presence";
      room = "Office";
      code_env = "MATTER_CODE_OFFICE_PRESENCE";
      network_only = false;
      match = {
        unique_id_env = "MATTER_UID_OFFICE_PRESENCE";
      };
    }

    {
      name = "MBR Bathroom Toilet Presence";
      room = "MBR Bathroom";
      code_env = "MATTER_CODE_MBR_BATHROOM_PRESENCE";
      network_only = false;
      match = {
        unique_id_env = "MATTER_UID_MBR_BATHROOM_PRESENCE";
      };
    }

    {
      name = "MBR Bathroom Main Presence";
      room = "MBR Bathroom";
      code_env = "MATTER_CODE_MBR_BATHROOM_MAIN_PRESENCE";
      network_only = false;
      match = {
        unique_id_env = "MATTER_UID_MBR_BATHROOM_MAIN_PRESENCE";
      };
    }

    {
      name = "MBR Shower Presence";
      room = "MBR Bathroom";
      code_env = "MATTER_CODE_MBR_SHOWER_PRESENCE";
      network_only = false;
      match = {
        unique_id_env = "MATTER_UID_MBR_SHOWER_PRESENCE";
      };
    }

    {
      name = "MBR Presence";
      room = "MBR";
      code_env = "MATTER_CODE_MBR_PRESENCE";
      network_only = false;
      match = {
        unique_id_env = "MATTER_UID_MBR_PRESENCE";
      };
    }

    {
      name = "MBR Presence 2";
      room = "MBR";
      code_env = "MATTER_CODE_MBR_PRESENCE_2";
      network_only = false;
      match = {
        unique_id_env = "MATTER_UID_MBR_PRESENCE_2";
      };
    }

    {
      name = "Upstairs Bathroom Light";
      room = "Upstairs Bathroom";
      code_env = "MATTER_CODE_UPSTAIRS_BATHROOM_LIGHT";
      network_only = false;
      match = {
        unique_id_env = "MATTER_UID_UPSTAIRS_BATHROOM_LIGHT";
      };
    }

    {
      name = "Pantry Light";
      room = "Pantry";
      code_env = "MATTER_CODE_PANTRY_LIGHT";
      network_only = false;
      match = {
        unique_id_env = "MATTER_UID_PANTRY_LIGHT";
      };
    }

    {
      name = "Front Door Light";
      room = "Front Door";
      code_env = "MATTER_CODE_FRONT_DOOR_LIGHT";
      network_only = false;
      match = {
        unique_id_env = "MATTER_UID_FRONT_DOOR_LIGHT";
      };
    }

    {
      name = "Pantry Presence";
      room = "Pantry";
      code_env = "MATTER_CODE_PANTRY_PRESENCE";
      network_only = false;
      match = {
        unique_id_env = "MATTER_UID_PANTRY_PRESENCE";
      };
    }

    {
      name = "Office Presence - Far";
      room = "Office";
      code_env = "MATTER_CODE_OFFICE_PRESENCE_FAR";
      network_only = false;
      match = {
        unique_id_env = "MATTER_UID_OFFICE_PRESENCE_FAR";
      };
    }

    {
      name = "Office Air Quality";
      room = "Office";
      code_env = "MATTER_CODE_OFFICE_AIR_QUALITY";
      network_only = false;
      match = {
        unique_id_env = "MATTER_UID_OFFICE_AIR_QUALITY";
      };
    }

    {
      name = "Upstairs Bathroom Presence";
      room = "Upstairs Bathroom";
      code_env = "MATTER_CODE_UPSTAIRS_BATHROOM_PRESENCE";
      network_only = false;
      match = {
        unique_id_env = "MATTER_UID_UPSTAIRS_BATHROOM_PRESENCE_NEW";
      };
    }

    {
      name = "Nursery Blinds";
      room = "Nursery";
      code_env = "MATTER_CODE_NURSERY_BLINDS";
      network_only = false;
      match = {
        mac_env = "MATTER_MAC_NURSERY_BLINDS";
      };
    }

    {
      name = "Nursery Blinds Remote";
      room = "Nursery";
      code_env = "MATTER_CODE_NURSERY_BLINDS_REMOTE";
      network_only = false;
      match = {
        mac = "3e:de:81:b4:b3:8c";
      };
    }

    {
      name = "MBR Bathroom Right Outlet";
      room = "MBR Bathroom";
      code_env = "MATTER_CODE_MBR_OUTLET_RIGHT";
      network_only = false;
      match = {
        unique_id_env = "MATTER_UID_MBR_OUTLET_RIGHT";
      };
    }

    {
      name = "MBR Bathroom Toilet Fan";
      room = "MBR Bathroom";
      code_env = "MATTER_CODE_MBR_BATHROOM_TOILET_FAN";
      network_only = false;
      match = {
        unique_id_env = "MATTER_UID_MBR_BATHROOM_TOILET_FAN";
      };
    }

    {
      name = "MBR Bathroom Toilet Light";
      room = "MBR Bathroom";
      code_env = "MATTER_CODE_MBR_BATHROOM_TOILET_LIGHT";
      network_only = false;
      match = {
        unique_id_env = "MATTER_UID_MBR_BATHROOM_TOILET_LIGHT";
      };
    }

    {
      name = "MBR Bed Light";
      room = "MBR";
      code_env = "MATTER_CODE_MBR_BED_LIGHT";
      network_only = false;
      match = {
        unique_id_env = "MATTER_UID_MBR_BED_LIGHT";
      };
    }

    {
      name = "Aqara Hub M3";
      room = "Network Closet";
      code_env = "MATTER_CODE_AQARA_HUB_M3";
      network_only = false;
      match = {
        mac_env = "MATTER_MAC_AQARA_HUB_M3";
      };
    }

    # Example:
    # {
    #   name = "Nursery Sensor";
    #   code_env = "MATTER_CODE_NURSERY_SENSOR";
    #   network_only = false;
    #   match = {
    #     unique_id = "0123456789ABCDEF";
    #   };
    # }
  ];

  # Keep device labels in this file too, so adding a device usually means
  # touching only pairings.nix.
  matterExtraNodeLabels = {};

  matterExtraNodeRooms = {};

  nodeLabelKeyFromMatch = match:
    if match ? unique_id
    then "unique_id:${match.unique_id}"
    else if match ? unique_id_env
    then "unique_id_env:${match.unique_id_env}"
    else if match ? serial
    then "serial:${match.serial}"
    else if match ? serial_env
    then "serial_env:${match.serial_env}"
    else if match ? mac
    then "mac:${match.mac}"
    else if match ? mac_env
    then "mac_env:${match.mac_env}"
    else null;

  matterPairingNodeLabels =
    lib.listToAttrs
    (lib.filter (x: x != null) (map (pairing: let
      key = nodeLabelKeyFromMatch (pairing.match or {});
      label = pairing.name or null;
    in
      if key != null && label != null
      then {
        name = key;
        value = label;
      }
      else null)
    matterDesiredPairings));

  matterPairingNodeRooms =
    lib.listToAttrs
    (lib.filter (x: x != null) (map (pairing: let
      key = nodeLabelKeyFromMatch (pairing.match or {});
      room = pairing.room or null;
    in
      if key != null && room != null
      then {
        name = key;
        value = room;
      }
      else null)
    matterDesiredPairings));

  matterNodeLabels = matterExtraNodeLabels // matterPairingNodeLabels;
  matterNodeRooms = matterExtraNodeRooms // matterPairingNodeRooms;
  matterNodeRoomsByLabel =
    lib.listToAttrs
    (lib.filter (x: x != null) (map (pairing: let
      label = pairing.name or null;
      room = pairing.room or null;
    in
      if label != null && room != null
      then {
        name = label;
        value = room;
      }
      else null)
    matterDesiredPairings));
  matterDesiredPairingsJson = builtins.toJSON matterDesiredPairings;

  pythonEnv = pkgs.python3.withPackages (ps: [
    ps.websockets
  ]);

  matterPairInteractiveScript = ./scripts/matter-pair-interactive.py;
  matterPairRetryScript = ./scripts/matter-pair-retry.sh;

  matterPairInteractiveTool = pkgs.writeShellApplication {
    name = "matter-pair-interactive";
    runtimeInputs = [pythonEnv];
    text = ''
      export MATTER_DESIRED_PAIRINGS_JSON='${matterDesiredPairingsJson}'
      export MATTER_ENV_FILE='${config.sops.secrets."matter-env".path}'
      exec ${pythonEnv}/bin/python3 ${matterPairInteractiveScript} "$@"
    '';
  };

  matterPairRetryTool = pkgs.writeShellApplication {
    name = "matter-pair-retry";
    runtimeInputs = [
      matterPairInteractiveTool
    ];
    text = builtins.readFile matterPairRetryScript;
  };
in {
  # Export to sibling modules (devices.nix) so labeler and reconcile share one source.
  _module.args.matterDesiredPairings = matterDesiredPairings;
  _module.args.matterNodeLabels = matterNodeLabels;
  _module.args.matterNodeRooms = matterNodeRooms;
  _module.args.matterNodeRoomsByLabel = matterNodeRoomsByLabel;

  environment.systemPackages = [
    matterPairInteractiveTool
    matterPairRetryTool
  ];
}
