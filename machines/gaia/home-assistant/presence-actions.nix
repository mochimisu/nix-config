{
  config,
  pkgs,
  ...
}: let
  pythonEnv = pkgs.python3.withPackages (ps: [
    ps.websockets
  ]);

  matterScriptsDir = ./scripts;
  matterSolarApiScript = "${matterScriptsDir}/matter-solar-api.py";

  matterSolarApiTool = pkgs.writeShellApplication {
    name = "matter-solar-api";
    runtimeInputs = [pythonEnv];
    text = ''
      export PYTHONPATH='${matterScriptsDir}':''${PYTHONPATH:-}
      exec ${pythonEnv}/bin/python3 ${matterSolarApiScript} "$@"
    '';
  };
in {
  environment.systemPackages = [
    matterSolarApiTool
  ];

  systemd.services.matter-solar-api = {
    description = "Local solar geometry API for Matter tools";
    wantedBy = ["multi-user.target"];
    after = ["network-online.target"];
    wants = ["network-online.target"];
    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = "3s";
      EnvironmentFile = config.sops.secrets."matter-env".path;
      ExecStart = "${matterSolarApiTool}/bin/matter-solar-api";
    };
  };
}
