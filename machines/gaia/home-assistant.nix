{...}: {
  services.home-assistant = {
    enable = true;
    openFirewall = true;
    configDir = "/earth/home-assistant";
    extraComponents = [
      "met"
      "samsungtv"
      "tesla_wall_connector"
      "unifiprotect"
    ];
    extraPackages = ps: [
      ps.pychromecast
      ps.uiprotect
    ];
    config = {
      default_config = {};
      http = {
        server_host = "0.0.0.0";
        server_port = 8123;
      };
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
      ];
      extraOptions = [
        "--network=host"
      ];
    };
  };

  systemd.tmpfiles.rules = [
    "d /earth/home-assistant 0750 hass hass - -"
    "d /earth/home-assistant/matter-server 0755 root root - -"
  ];
}
