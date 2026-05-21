{
  config,
  lib,
  pkgs,
  ...
}: let
  devLiveLock = "/run/lock/matter-layer-dev-live.lock";
  matterLayerStart = pkgs.writeShellScript "matter-layer-with-dev-live-lock" ''
    exec ${pkgs.util-linux}/bin/flock ${devLiveLock} ${config.services.matter-layer.package}/bin/matter-layer
  '';
in {
  services.matter-layer = {
    enable = true;
    port = 3010;
    openFirewall = true;
    matterWsUrl = "ws://127.0.0.1:${toString config.gaia.homeAssistant.matterjs.port}/ws";
    rulesModule = ./rules.ts;
    bindings = builtins.fromJSON (builtins.readFile ./bindings.json);
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
