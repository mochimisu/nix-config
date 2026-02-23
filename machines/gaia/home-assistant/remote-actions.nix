{pkgs, lib, ...}: let
  # Office bindings (Matter-over-Thread, handled directly through matter.js server API).
  remoteMac = "96:fe:3c:95:81:67";
  # Keep this zero so runtime resolves by MAC and survives node-id churn.
  remoteNodeId = 0;
  blindsMac = "88:13:bf:aa:50:df";
  blindsEndpoint = 1;

  # Add any extra nodes you want to keep warm. The remote node is automatically
  # added at runtime after MAC/node resolution.
  keepaliveNodeIds = [
    10
    13
  ];
  keepaliveIntervalSec = 30;

  pythonEnv = pkgs.python3.withPackages (ps: [
    ps.websockets
  ]);

  matterRemoteActionsScript = ./scripts/matter-remote-actions.py;
  matterEventsScript = ./scripts/matter-events.py;
  matterHealthScript = ./scripts/matter-health.py;
  matterWatchScript = ./scripts/matter-watch.py;

  matterRemoteActionsTool = pkgs.writeShellApplication {
    name = "matter-remote-actions";
    runtimeInputs = [pythonEnv];
    text = ''
      export MATTER_REMOTE_MAC='${remoteMac}'
      export MATTER_REMOTE_NODE_ID='${toString remoteNodeId}'
      export MATTER_BLINDS_MAC='${blindsMac}'
      export MATTER_BLINDS_ENDPOINT='${toString blindsEndpoint}'
      export MATTER_KEEPALIVE_NODE_IDS='${lib.concatStringsSep "," (map toString keepaliveNodeIds)}'
      export MATTER_KEEPALIVE_INTERVAL_SEC='${toString keepaliveIntervalSec}'
      exec ${pythonEnv}/bin/python3 ${matterRemoteActionsScript} "$@"
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
      exec ${pythonEnv}/bin/python3 ${matterWatchScript} "$@"
    '';
  };
in {
  environment.systemPackages = [
    matterRemoteActionsTool
    matterEventsTool
    matterHealthTool
    matterWatchTool
  ];

  systemd.services.matter-remote-actions = {
    description = "Matter.js remote actions for office blinds";
    wantedBy = [
      "multi-user.target"
    ];
    after = [
      "podman-matter-server.service"
      "network-online.target"
    ];
    wants = [
      "podman-matter-server.service"
      "network-online.target"
    ];
    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = "5s";
      ExecStartPre = "${pkgs.bash}/bin/bash -c 'for i in {1..60}; do (echo > /dev/tcp/127.0.0.1/5580) >/dev/null 2>&1 && exit 0; sleep 1; done; echo matter-server ws not ready >&2; exit 1'";
      ExecStart = "${matterRemoteActionsTool}/bin/matter-remote-actions";
    };
  };
}
