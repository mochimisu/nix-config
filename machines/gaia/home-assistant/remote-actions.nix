{config, pkgs, lib, matterNodeRooms ? {}, matterNodeRoomsByLabel ? {}, ...}: let
  # Blinds remote bindings (Matter-over-Thread, handled directly through matter.js server API).
  # Keep this zero so runtime resolves by MAC and survives node-id churn.
  remoteNodeId = 0;
  blindsEndpoint = 1;
  officeRemoteMac = "da:21:d9:f7:cc:5d";
  nurseryRemoteMac = "3e:de:81:b4:b3:8c";
  guestBedroomRemoteMac = "a6:86:cb:d2:f3:37";
  guestBedroomWindowBlindsMac = "88:13:bf:aa:5c:13";
  guestBedroomDoorBlindsMac = "88:13:bf:aa:48:2b";
  mbrRemoteMac = "fa:f8:03:5a:fc:f5";
  mbrRemote2Mac = "d6:46:db:18:f0:d1";
  mbrDoorBlindsLeftMac = "70:4b:ca:2e:69:3f";
  mbrDoorBlindsRightMac = "70:4b:ca:2f:9b:83";
  keepaliveIntervalSec = 15;

  pythonEnv = pkgs.python3.withPackages (ps: [
    ps.websockets
  ]);

  matterRemoteActionsScript = ./scripts/matter-remote-actions.py;
  matterKeepaliveScript = ./scripts/matter-keepalive.py;
  matterEventsScript = ./scripts/matter-events.py;
  matterHealthScript = ./scripts/matter-health.py;
  matterWatchScript = ./scripts/matter-watch.py;
  matterNodeRoomsJson = builtins.toJSON matterNodeRooms;
  matterNodeRoomsByLabelJson = builtins.toJSON matterNodeRoomsByLabel;
  matterServerUnit = "podman-matter-server.service";
  matterWsPort = "5580";
  matterWsUrl = "ws://127.0.0.1:${matterWsPort}/ws";

  matterRemoteActionsTool = pkgs.writeShellApplication {
    name = "matter-remote-actions";
    runtimeInputs = [pythonEnv];
    text = ''
      export MATTER_REMOTE_NODE_ID='${toString remoteNodeId}'
      export MATTER_BLINDS_ENDPOINT='${toString blindsEndpoint}'
      # Office defaults (legacy + explicit names).
      export MATTER_OFFICE_REMOTE_MAC='${officeRemoteMac}'
      export MATTER_OFFICE_BLINDS_MAC=''${MATTER_OFFICE_BLINDS_MAC:-''${MATTER_BLINDS_MAC:-}}
      # Nursery binding.
      export MATTER_NURSERY_REMOTE_MAC='${nurseryRemoteMac}'
      export MATTER_NURSERY_BLINDS_MAC=''${MATTER_NURSERY_BLINDS_MAC:-''${MATTER_MAC_NURSERY_BLINDS:-}}
      # Guest bedroom binding.
      export MATTER_GUEST_BEDROOM_REMOTE_MAC='${guestBedroomRemoteMac}'
      export MATTER_GUEST_BEDROOM_WINDOW_BLINDS_MAC='${guestBedroomWindowBlindsMac}'
      export MATTER_GUEST_BEDROOM_DOOR_BLINDS_MAC='${guestBedroomDoorBlindsMac}'
      # MBR binding.
      export MATTER_MBR_REMOTE_MAC='${mbrRemoteMac}'
      export MATTER_MBR_REMOTE_2_MAC='${mbrRemote2Mac}'
      export MATTER_MBR_DOOR_BLINDS_LEFT_MAC='${mbrDoorBlindsLeftMac}'
      export MATTER_MBR_DOOR_BLINDS_RIGHT_MAC='${mbrDoorBlindsRightMac}'
      export MATTER_REMOTE_ACTION_DEDUPE_WINDOW_SEC=''${MATTER_REMOTE_ACTION_DEDUPE_WINDOW_SEC:-0.8}
      exec ${pythonEnv}/bin/python3 ${matterRemoteActionsScript} "$@"
    '';
  };

  matterKeepaliveTool = pkgs.writeShellApplication {
    name = "matter-keepalive";
    runtimeInputs = [pythonEnv];
    text = ''
      export MATTER_KEEPALIVE_INTERVAL_SEC=''${MATTER_KEEPALIVE_INTERVAL_SEC:-${toString keepaliveIntervalSec}}
      export MATTER_KEEPALIVE_READ_TIMEOUT_SEC=''${MATTER_KEEPALIVE_READ_TIMEOUT_SEC:-4}
      export MATTER_KEEPALIVE_SKIP_SLEEPY=''${MATTER_KEEPALIVE_SKIP_SLEEPY:-1}
      export MATTER_KEEPALIVE_FORCE_PRODUCT_KEYWORDS="''${MATTER_KEEPALIVE_FORCE_PRODUCT_KEYWORDS:-fp300,presence,bilresa}"
      export MATTER_KEEPALIVE_FORCE_ATTRIBUTE_PATHS="''${MATTER_KEEPALIVE_FORCE_ATTRIBUTE_PATHS:-2/1030/0,1/1030/0,0/47/12,0/40/5}"
      exec ${pythonEnv}/bin/python3 ${matterKeepaliveScript} "$@"
    '';
  };

  matterEventsTool = pkgs.writeShellApplication {
    name = "matter-events";
    runtimeInputs = [pythonEnv];
    text = ''
      exec ${pythonEnv}/bin/python3 ${matterEventsScript} "$@"
    '';
  };

  matterHealthTool = pkgs.writeShellApplication {
    name = "matter-health";
    runtimeInputs = [pythonEnv];
    text = ''
      exec ${pythonEnv}/bin/python3 ${matterHealthScript} "$@"
    '';
  };

  matterWatchTool = pkgs.writeShellApplication {
    name = "matter-watch";
    runtimeInputs = [pythonEnv];
    text = ''
      export MATTER_NODE_ROOMS_JSON='${matterNodeRoomsJson}'
      export MATTER_NODE_ROOMS_BY_LABEL_JSON='${matterNodeRoomsByLabelJson}'
      export MATTER_WS_URL='${matterWsUrl}'
      exec ${pythonEnv}/bin/python3 ${matterWatchScript} "$@"
    '';
  };
in {
  environment.systemPackages = [
    matterRemoteActionsTool
    matterKeepaliveTool
    matterEventsTool
    matterHealthTool
    matterWatchTool
  ];

  systemd.services.matter-keepalive = {
    description = "Matter keepalive for routerlike Thread devices";
    wantedBy = [
      "multi-user.target"
    ];
    after = [
      matterServerUnit
      "podman-otbr.service"
      "otbr-ensure-dataset.service"
      "network-online.target"
    ];
    wants = [
      matterServerUnit
      "podman-otbr.service"
      "otbr-ensure-dataset.service"
      "network-online.target"
    ];
    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = "5s";
      EnvironmentFile = config.sops.secrets."matter-env".path;
      Environment = [
        "MATTER_WS_URL=${matterWsUrl}"
        "MATTER_KEEPALIVE_INTERVAL_SEC=${toString keepaliveIntervalSec}"
        "MATTER_KEEPALIVE_READ_TIMEOUT_SEC=4"
        "MATTER_KEEPALIVE_SKIP_SLEEPY=1"
        "MATTER_KEEPALIVE_FORCE_PRODUCT_KEYWORDS=fp300,presence,bilresa"
        "MATTER_KEEPALIVE_FORCE_ATTRIBUTE_PATHS=2/1030/0,1/1030/0,0/47/12,0/40/5"
      ];
      ExecStartPre = "${pkgs.bash}/bin/bash -c 'for i in {1..60}; do (echo > /dev/tcp/127.0.0.1/${matterWsPort}) >/dev/null 2>&1 && exit 0; sleep 1; done; echo matter-server ws not ready >&2; exit 1'";
      ExecStart = "${matterKeepaliveTool}/bin/matter-keepalive";
    };
  };

  systemd.services.matter-remote-actions = {
    description = "Matter.js remote actions for office, nursery, guest bedroom, and MBR blinds";
    wantedBy = [
      "multi-user.target"
    ];
    after = [
      matterServerUnit
      "podman-otbr.service"
      "otbr-ensure-dataset.service"
      "network-online.target"
    ];
    wants = [
      matterServerUnit
      "podman-otbr.service"
      "otbr-ensure-dataset.service"
      "network-online.target"
    ];
    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = "5s";
      EnvironmentFile = config.sops.secrets."matter-env".path;
      Environment = [
        "MATTER_WS_URL=${matterWsUrl}"
      ];
      ExecStartPre = "${pkgs.bash}/bin/bash -c 'for i in {1..60}; do (echo > /dev/tcp/127.0.0.1/${matterWsPort}) >/dev/null 2>&1 && exit 0; sleep 1; done; echo matter-server ws not ready >&2; exit 1'";
      ExecStart = "${matterRemoteActionsTool}/bin/matter-remote-actions";
    };
  };
}
