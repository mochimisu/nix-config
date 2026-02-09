{pkgs, ...}: {
  imports = [
    ./devices.nix
  ];

  services.home-assistant = {
    enable = true;
    openFirewall = true;
    configDir = "/earth/home-assistant";
    extraComponents = [
      "homeassistant_connect_zbt2"
      "mcp_server"
      "met"
      "otbr"
      "samsungtv"
      "tesla_wall_connector"
      "thread"
      "unifiprotect"
    ];
    extraPackages = ps: [
      ps."aiohttp-sse"
      # Required for HomeKit Device / HomeKit Controller (e.g. Aqara FP2).
      ps.aiohomekit
      ps.aiohomeconnect
      ps.androidtvremote2
      ps.beautifulsoup4
      ps.gtts
      ps.ha-silabs-firmware-client
      # Required for HomeKit Bridge.
      ps.hap-python
      # Required for Apple TV integration config flow.
      ps.pyatv
      ps.python-roborock
      ps.pychromecast
      ps.python-otbr-api
      ps.universal-silabs-flasher
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

  users.users.hass.extraGroups = [
    "dialout"
  ];

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
        "--paa-root-cert-dir"
        "/data/paa-root-certs"
      ];
      volumes = [
        "/earth/home-assistant/matter-server:/data"
        "/earth/home-assistant/matter-server/.matter_server:/root/.matter_server"
        "/earth/home-assistant/matter-server/paa-root-certs:/data/paa-root-certs"
      ];
      extraOptions = [
        "--network=host"
      ];
    };
    containers.otbr = {
      image = "openthread/otbr:latest";
      autoStart = true;
      environment = {
        BACKBONE_INTERFACE = "enp5s0";
        FIREWALL = "0";
        INFRA_IF_NAME = "enp5s0";
        NAT64 = "0";
      };
      cmd = [
        "--radio-url"
        "spinel+hdlc+uart:///dev/ttyACM0?uart-baudrate=460800"
      ];
      volumes = [
        "/earth/home-assistant/otbr:/data"
      ];
      extraOptions = [
        "--network=host"
        "--cap-add=NET_ADMIN"
        "--cap-add=NET_RAW"
        "--device=/dev/serial/by-id/usb-Nabu_Casa_ZBT-2_DCB4D9123AF0-if00:/dev/ttyACM0"
        "--device=/dev/net/tun"
      ];
    };
  };

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
    "net.ipv6.conf.default.forwarding" = 1;
    "net.ipv6.conf.all.disable_ipv6" = 0;
    "net.ipv6.conf.default.disable_ipv6" = 0;
  };
  boot.kernelModules = [
    "ip6table_filter"
    "ip6table_nat"
    "iptable_filter"
    "iptable_nat"
    "nf_conntrack"
    "nf_nat"
  ];

  systemd.tmpfiles.rules = [
    "d /earth/home-assistant 0750 hass hass - -"
    "d /earth/home-assistant/matter-server 0755 root root - -"
    "d /earth/home-assistant/matter-server/.matter_server 0755 root root - -"
    "d /earth/home-assistant/matter-server/paa-root-certs 0755 root root - -"
    "d /earth/home-assistant/otbr 0755 root root - -"
  ];

  systemd.services."podman-matter-server".preStart = ''
    ${pkgs.coreutils}/bin/mkdir -p /earth/home-assistant/matter-server/.matter_server
    ${pkgs.coreutils}/bin/mkdir -p /earth/home-assistant/matter-server/paa-root-certs
  '';

  systemd.services."podman-otbr".preStart = ''
    ${pkgs.coreutils}/bin/mkdir -p /earth/home-assistant/otbr
  '';
}
