{
  config,
  lib,
  pkgs,
  ...
}: let
  devLiveLock = "/run/lock/matter-layer-dev-live.lock";
  matterWsPort = toString config.gaia.homeAssistant.matterjs.port;
  matterLayerStart = pkgs.writeShellScript "matter-layer-with-dev-live-lock" ''
    for _ in $(${pkgs.coreutils}/bin/seq 1 60); do
      if ${pkgs.bash}/bin/bash -c 'exec 3<>/dev/tcp/127.0.0.1/${matterWsPort}' 2>/dev/null; then
        exec ${pkgs.util-linux}/bin/flock ${devLiveLock} ${config.services.matter-layer.package}/bin/matter-layer
      fi
      ${pkgs.coreutils}/bin/sleep 1
    done
    echo "matter-layer: Matter.js websocket port ${matterWsPort} did not become ready" >&2
    exit 1
  '';
in {
  services.matter-layer = {
    enable = true;
    port = 3010;
    openFirewall = true;
    matterWsUrl = "ws://127.0.0.1:${toString config.gaia.homeAssistant.matterjs.port}/ws";
    rulesModule = ./rules.ts;
    bindings = builtins.fromJSON (builtins.readFile ./bindings.json);
    environment = {
      MATTER_LAYER_WEB_DEV = "0";
    };
  };

  systemd.services.matter-layer = {
    after = [
      "podman-matter-server.service"
    ];
    wants = [
      "podman-matter-server.service"
    ];
    serviceConfig = {
      ExecStart = lib.mkForce matterLayerStart;
    };
  };

  systemd.tmpfiles.rules = [
    "f ${devLiveLock} 0666 root root -"
  ];
}
