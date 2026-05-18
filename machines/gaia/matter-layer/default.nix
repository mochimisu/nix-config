{config, ...}: {
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
      "network-online.target"
    ];
    wants = [
      "podman-matter-server.service"
      "network-online.target"
    ];
  };
}
