{
  config,
  pkgs,
  matterNodeRooms ? {},
  matterNodeRoomsByLabel ? {},
  ...
}: let
  keepaliveIntervalSec = 15;

  pythonEnv = pkgs.python3.withPackages (ps: [
    ps.websockets
  ]);

  matterKeepaliveScript = ./scripts/matter-keepalive.py;
  matterEventsScript = ./scripts/matter-events.py;
  matterHealthScript = ./scripts/matter-health.py;
  matterWatchScript = ./scripts/matter-watch.py;
  matterNodeRoomsJson = builtins.toJSON matterNodeRooms;
  matterNodeRoomsByLabelJson = builtins.toJSON matterNodeRoomsByLabel;
  matterServerUnit = "podman-matter-server.service";
  matterWsPort = "5580";
  matterWsUrl = "ws://127.0.0.1:${matterWsPort}/ws";

  matterKeepaliveTool = pkgs.writeShellApplication {
    name = "matter-keepalive";
    runtimeInputs = [pythonEnv];
    text = ''
      export MATTER_KEEPALIVE_INTERVAL_SEC=''${MATTER_KEEPALIVE_INTERVAL_SEC:-${toString keepaliveIntervalSec}}
      export MATTER_KEEPALIVE_READ_TIMEOUT_SEC=''${MATTER_KEEPALIVE_READ_TIMEOUT_SEC:-4}
      export MATTER_KEEPALIVE_SKIP_SLEEPY=''${MATTER_KEEPALIVE_SKIP_SLEEPY:-1}
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
        "MATTER_KEEPALIVE_FORCE_PRODUCT_KEYWORDS=fp300,presence,bilresa,myggbett"
        "MATTER_KEEPALIVE_FORCE_ATTRIBUTE_PATHS=1/69/0,2/1030/0,1/1030/0,0/47/12,0/40/5"
      ];
      ExecStartPre = "${pkgs.bash}/bin/bash -c 'for i in {1..60}; do (echo > /dev/tcp/127.0.0.1/${matterWsPort}) >/dev/null 2>&1 && exit 0; sleep 1; done; echo matter-server ws not ready >&2; exit 1'";
      ExecStart = "${matterKeepaliveTool}/bin/matter-keepalive";
    };
  };
}
