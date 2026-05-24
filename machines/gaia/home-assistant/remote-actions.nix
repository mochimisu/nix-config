{
  pkgs,
  matterNodeRooms ? {},
  matterNodeRoomsByLabel ? {},
  ...
}: let
  keepaliveIntervalSec = 30;

  pythonEnv = pkgs.python3.withPackages (ps: [
    ps.websockets
  ]);

  matterKeepaliveScript = ./scripts/matter-keepalive.py;
  matterEventsScript = ./scripts/matter-events.py;
  matterHealthScript = ./scripts/matter-health.py;
  matterWatchScript = ./scripts/matter-watch.py;
  matterNodeRoomsJson = builtins.toJSON matterNodeRooms;
  matterNodeRoomsByLabelJson = builtins.toJSON matterNodeRoomsByLabel;
  matterWsPort = "5580";
  matterWsUrl = "ws://127.0.0.1:${matterWsPort}/ws";

  matterKeepaliveTool = pkgs.writeShellApplication {
    name = "matter-keepalive";
    runtimeInputs = [pythonEnv];
    text = ''
      export MATTER_KEEPALIVE_INTERVAL_SEC=''${MATTER_KEEPALIVE_INTERVAL_SEC:-${toString keepaliveIntervalSec}}
      export MATTER_KEEPALIVE_READ_TIMEOUT_SEC=''${MATTER_KEEPALIVE_READ_TIMEOUT_SEC:-4}
      export MATTER_KEEPALIVE_SKIP_SLEEPY=''${MATTER_KEEPALIVE_SKIP_SLEEPY:-1}
      export MATTER_KEEPALIVE_NODE_BACKOFF_BASE_SEC=''${MATTER_KEEPALIVE_NODE_BACKOFF_BASE_SEC:-60}
      export MATTER_KEEPALIVE_NODE_BACKOFF_MAX_SEC=''${MATTER_KEEPALIVE_NODE_BACKOFF_MAX_SEC:-900}
      export MATTER_KEEPALIVE_MAX_ATTRIBUTES_PER_PASS=''${MATTER_KEEPALIVE_MAX_ATTRIBUTES_PER_PASS:-1}
      export MATTER_KEEPALIVE_FORCE_PRODUCT_KEYWORDS="''${MATTER_KEEPALIVE_FORCE_PRODUCT_KEYWORDS:-fp300,presence,bilresa,myggbett}"
      export MATTER_KEEPALIVE_FORCE_ATTRIBUTE_PATHS="''${MATTER_KEEPALIVE_FORCE_ATTRIBUTE_PATHS:-1/69/0,2/1030/0,1/1030/0,0/47/12,0/40/5}"
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
      export MATTER_WATCH_ZBT2_ENABLE='1'
      exec ${pythonEnv}/bin/python3 ${matterWatchScript} "$@"
    '';
  };
in {
  environment.systemPackages = [
    matterKeepaliveTool
    matterEventsTool
    matterHealthTool
    matterWatchTool
  ];

  # Keep the manual `matter-keepalive` tool available, but do not run the
  # background service while matter-layer performs targeted stale probes.
}
