{pkgs, ...}: {
  services.home-assistant = {
    enable = true;
    openFirewall = true;
    configDir = "/earth/home-assistant";
    extraComponents = [
      "met"
      "samsungtv"
      "tesla_wall_connector"
      "thread"
      "unifiprotect"
    ];
    extraPackages = ps: [
      ps.aiohomeconnect
      ps.androidtvremote2
      ps.beautifulsoup4
      ps.gtts
      ps.python-roborock
      ps.pychromecast
      ps.python-otbr-api
      ps.uiprotect
    ];
    customComponents = [
      pkgs.home-assistant-custom-components.ac_infinity
      pkgs.home-assistant-custom-components.bambu_lab
    ];
    config = {
      default_config = {};
      automation = "!include automations.yaml";
      http = {
        server_port = 8123;
      };
      scene = "!include scenes.yaml";
    };
  };

  # mDNS is required for many Matter devices (discovery + commissioning).
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    nssmdns6 = true;
    openFirewall = true;
  };

  # Matter operates over UDP/5540.
  networking.firewall.allowedUDPPorts = [
    5540
  ];

  # Matter support for Home Assistant Core (no Supervisor add-ons on NixOS).
  # Home Assistant connects to this via `ws://127.0.0.1:5580/ws`.
  virtualisation.podman.enable = true;
  virtualisation.oci-containers = {
    backend = "podman";
    containers.matter-server = {
      image = "ghcr.io/home-assistant-libs/python-matter-server:stable";
      autoStart = true;
      cmd = [
        "--primary-interface"
        "enp5s0"
      ];
      volumes = [
        "/earth/home-assistant/matter-server:/data"
        "/earth/home-assistant/matter-server/.matter_server:/root/.matter_server"
      ];
      extraOptions = [
        "--network=host"
      ];
    };
  };

  systemd.tmpfiles.rules = [
    "d /earth/home-assistant 0750 hass hass - -"
    "d /earth/home-assistant/matter-server 0755 root root - -"
    "d /earth/home-assistant/matter-server/.matter_server 0755 root root - -"
  ];

  systemd.services."podman-matter-server".preStart = ''
    ${pkgs.coreutils}/bin/mkdir -p /earth/home-assistant/matter-server/.matter_server
  '';
}
