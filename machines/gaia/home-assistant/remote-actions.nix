{config, pkgs, lib, matterNodeRooms ? {}, matterNodeRoomsByLabel ? {}, ...}: let
  # Blinds remote bindings (Matter-over-Thread, handled directly through matter.js server API).
  # Keep this zero so runtime resolves by MAC and survives node-id churn.
  remoteNodeId = 0;
  blindsEndpoint = 1;
  officeRemoteMac = "da:21:d9:f7:cc:5d";
  nurseryRemoteMac = "3e:de:81:b4:b3:8c";
  keepaliveIntervalSec = 30;

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
      export MATTER_REMOTE_ACTION_DEDUPE_WINDOW_SEC=''${MATTER_REMOTE_ACTION_DEDUPE_WINDOW_SEC:-0.8}
      exec ${pythonEnv}/bin/python3 ${matterRemoteActionsScript} "$@"
    '';
  };

  matterKeepaliveTool = pkgs.writeShellApplication {
    name = "matter-keepalive";
    runtimeInputs = [pythonEnv];
    text = ''
      export MATTER_KEEPALIVE_INTERVAL_SEC='${toString keepaliveIntervalSec}'
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
    description = "Matter keepalive for all Thread devices";
    wantedBy = [
      "multi-user.target"
    ];
    after = [
      "podman-matter-server.service"
      "podman-otbr.service"
      "otbr-ensure-dataset.service"
      "network-online.target"
    ];
    wants = [
      "podman-matter-server.service"
      "podman-otbr.service"
      "otbr-ensure-dataset.service"
      "network-online.target"
    ];
    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = "5s";
      EnvironmentFile = config.sops.secrets."matter-env".path;
      ExecStartPre = "${pkgs.bash}/bin/bash -c 'for i in {1..60}; do (echo > /dev/tcp/127.0.0.1/5580) >/dev/null 2>&1 && exit 0; sleep 1; done; echo matter-server ws not ready >&2; exit 1'";
      ExecStart = "${matterKeepaliveTool}/bin/matter-keepalive";
    };
  };

  systemd.services.matter-remote-actions = {
    description = "Matter.js remote actions for office and nursery blinds";
    wantedBy = [
      "multi-user.target"
    ];
    after = [
      "podman-matter-server.service"
      "podman-otbr.service"
      "otbr-ensure-dataset.service"
      "network-online.target"
    ];
    wants = [
      "podman-matter-server.service"
      "podman-otbr.service"
      "otbr-ensure-dataset.service"
      "network-online.target"
    ];
    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = "5s";
      EnvironmentFile = config.sops.secrets."matter-env".path;
      ExecStartPre = "${pkgs.bash}/bin/bash -c 'for i in {1..60}; do (echo > /dev/tcp/127.0.0.1/5580) >/dev/null 2>&1 && exit 0; sleep 1; done; echo matter-server ws not ready >&2; exit 1'";
      ExecStart = "${matterRemoteActionsTool}/bin/matter-remote-actions";
    };
  };
}
