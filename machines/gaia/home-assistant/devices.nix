{
  config,
  pkgs,
  matterNodeLabels ? {},
  ...
}: let
  # Prefer setting the Matter device's own NodeLabel (0/40/5) so names survive
  # HA state wipes and re-pairing. Entity_id-based HA customizations are fragile.
  # Disambiguation strategy for multiple devices:
  # - Prefer BasicInfo UniqueID (0/40/18) when present: `unique_id:<value>`
  # - Else SerialNumber (0/40/15): `serial:<value>`
  # - Else MAC from GeneralDiagnostics NetworkInterfaces (0/51/0 field 4): `mac:<aa:bb:cc:dd:ee:ff>`
  #
  # Source of truth is in pairings.nix via _module.args.matterNodeLabels.
  # You can discover candidate keys with `matter-node-labels --list`.
  matterNodeLabelsJson = builtins.toJSON matterNodeLabels;
  matterServerUnit = "podman-matter-server.service";
  matterWsPort = "5580";
  matterWsUrl = "ws://127.0.0.1:${matterWsPort}/ws";

  pythonEnv = pkgs.python3.withPackages (ps: [
    ps.websockets
  ]);

  matterLabeler = pkgs.writeText "matter-node-labels.py" (builtins.readFile ./scripts/matter-node-labels.py);

  matterHaNamer = pkgs.writeText "matter-ha-namer.py" (builtins.readFile ./scripts/matter-ha-namer.py);

  matterNodeLabelsTool = pkgs.writeShellApplication {
    name = "matter-node-labels";
    runtimeInputs = [pythonEnv];
    text = ''
      export MATTER_NODE_LABELS_JSON='${matterNodeLabelsJson}'
      exec ${pythonEnv}/bin/python3 ${matterLabeler} "$@"
    '';
  };

  matterHaNamerTool = pkgs.writeShellApplication {
    name = "matter-ha-namer";
    runtimeInputs = [pythonEnv];
    text = ''
      export MATTER_NODE_LABELS_JSON='${matterNodeLabelsJson}'
      exec ${pythonEnv}/bin/python3 ${matterHaNamer} "$@"
    '';
  };

in {
  environment.systemPackages = [
    matterNodeLabelsTool
    matterHaNamerTool
  ];

  systemd.services.matter-apply-node-labels = {
    description = "Apply Matter NodeLabel overrides (Nix-defined)";
    after = [
      matterServerUnit
      "network-online.target"
    ];
    wants = [
      matterServerUnit
      "network-online.target"
    ];
    serviceConfig = {
      Type = "oneshot";
      EnvironmentFile = config.sops.secrets."matter-env".path;
      Environment = [
        "MATTER_WS_URL=${matterWsUrl}"
      ];
      ExecStartPre = "${pkgs.bash}/bin/bash -c 'for i in {1..60}; do (echo > /dev/tcp/127.0.0.1/${matterWsPort}) >/dev/null 2>&1 && exit 0; sleep 1; done; echo matter-server ws not ready >&2; exit 1'";
      ExecStart = "${matterNodeLabelsTool}/bin/matter-node-labels";
    };
  };

  # Devices may come online after boot; retry periodically.
  systemd.timers.matter-apply-node-labels = {
    wantedBy = [
      "timers.target"
    ];
    timerConfig = {
      OnBootSec = "2min";
      OnUnitInactiveSec = "1h";
      Unit = "matter-apply-node-labels.service";
    };
  };

  systemd.services.matter-apply-ha-names = {
    description = "Apply Home Assistant device names from Matter labels";
    after = [
      "home-assistant.service"
      matterServerUnit
      "network-online.target"
    ];
    wants = [
      "home-assistant.service"
      matterServerUnit
      "network-online.target"
    ];
    serviceConfig = {
      Type = "oneshot";
      EnvironmentFile = config.sops.secrets."matter-env".path;
      Environment = [
        "MATTER_WS_URL=${matterWsUrl}"
      ];
      ExecStartPre = "${pkgs.bash}/bin/bash -c 'for i in {1..60}; do (echo > /dev/tcp/127.0.0.1/8123) >/dev/null 2>&1 && (echo > /dev/tcp/127.0.0.1/${matterWsPort}) >/dev/null 2>&1 && exit 0; sleep 1; done; echo HA or matter ws not ready >&2; exit 1'";
      ExecStart = "${matterHaNamerTool}/bin/matter-ha-namer";
    };
  };

  systemd.timers.matter-apply-ha-names = {
    wantedBy = [
      "timers.target"
    ];
    timerConfig = {
      OnBootSec = "4min";
      OnUnitInactiveSec = "1h";
      Unit = "matter-apply-ha-names.service";
    };
  };

}
