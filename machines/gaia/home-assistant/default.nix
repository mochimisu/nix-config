{config, pkgs, lib, ...}: let
  containerImages = import ../container-images.nix;
  format = pkgs.formats.yaml {};
  matterServerUnit = "podman-matter-server.service";
  matterjsDataDir = "/earth/home-assistant/matterjs-server";
  haConfig = {
    default_config = {};
    automation = "!include automations.yaml";
    http = {
      server_port = 8123;
      use_x_forwarded_for = true;
      trusted_proxies = [
        "127.0.0.1"
        "::1"
      ];
    };
    scene = "!include scenes.yaml";
  };
  haConfigFile =
    pkgs.runCommand "home-assistant-container-configuration.yaml" {
      preferLocalBuilds = true;
    } ''
      cp ${format.generate "configuration.yaml" haConfig} $out
      sed -i -e "s/'\!\([a-z_]\+\) \(.*\)'/\!\1 \2/;s/^\!\!/\!/;" $out
    '';
  haCustomComponents = [
    pkgs.home-assistant-custom-components.ac_infinity
    pkgs.home-assistant-custom-components.bambu_lab
  ];
  matterThreadZbt2Recover = pkgs.writeShellApplication {
    name = "matter-thread-zbt2-recover";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.iproute2
      pkgs.systemd
    ];
    text = builtins.readFile ./scripts/matter-thread-zbt2-recover.sh;
  };
in {
  nixpkgs.overlays = [
    (import ../../../overlays/ha-ac-infinity.nix)
    (import ../../../overlays/ha-bambulab.nix)
  ];

  imports = [
    ./devices.nix
    ./matterjs.nix
    ./remote-actions.nix
    ./presence-actions.nix
    ./pairings.nix
  ];

  # Avoid serial probing races on the Thread radio (common with ttyACM devices).
  networking.modemmanager.enable = lib.mkForce false;

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  # Keep the Thread radio awake; autosuspend can destabilize OTBR/RCP transport.
  services.udev.extraRules = ''
    ACTION=="add|change", SUBSYSTEM=="usb", ATTR{idVendor}=="303a", ATTR{idProduct}=="831a", ATTR{serial}=="DCB4D9123AF0", TEST=="power/control", ATTR{power/control}="on"
    ACTION=="add|change", SUBSYSTEM=="tty", ATTRS{idVendor}=="303a", ATTRS{idProduct}=="831a", ENV{ID_MM_DEVICE_IGNORE}="1"
    # Realtek RTL8761BU Bluetooth adapter: keep it out of USB autosuspend or it
    # can time out, reset, and come back as a new hci index mid-commissioning.
    ACTION=="add|change", SUBSYSTEM=="usb", ATTR{idVendor}=="0bda", ATTR{idProduct}=="a729", TEST=="power/control", ATTR{power/control}="on"
  '';

  # mDNS is required for many Matter devices (discovery + commissioning).
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    nssmdns6 = true;
    openFirewall = true;
  };

  networking.firewall = {
    # Matter operates over UDP/5540.
    allowedUDPPorts = [
      5540
    ];
    allowedTCPPorts = [
      8123
      config.gaia.homeAssistant.matterjs.port
    ];

    # Thread/Matter event reports may enter Gaia either directly through the
    # local ZBT-2 OTBR (`wpan0`) or through same-dataset Ethernet border routers
    # such as the Aqara M3 hubs and IKEA DIRIGERA on `enp5s0`. Thread OMR
    # prefixes are ULA /64s and can change when the dataset is rebuilt, so keep
    # the Ethernet fallback broad enough for any current same-LAN border router
    # while still scoped to Matter-over-Thread traffic.
    trustedInterfaces = lib.mkAfter [
      "wpan0"
    ];
    extraCommands = ''
      ${pkgs.iptables}/bin/ip6tables -A nixos-fw -i enp5s0 -s fc00::/7 -p udp --dport 5540 -j nixos-fw-accept -m comment --comment "Allow Matter-over-Thread from ULA OMR routes via Ethernet border routers"
      ${pkgs.iptables}/bin/ip6tables -A nixos-fw -i enp5s0 -s fc00::/7 -p udp --sport 5540 -j nixos-fw-accept -m comment --comment "Allow Matter-over-Thread replies from ULA OMR routes via Ethernet border routers"
    '';
  };

  # Home Assistant runs as the upstream Container install type, while Matter.js
  # and OTBR remain separately managed host containers/services.
  virtualisation.podman.enable = true;
  virtualisation.oci-containers = {
    backend = "podman";
    containers.home-assistant = {
      image = "ghcr.io/home-assistant/home-assistant:${config.services.home-assistant.package.version}";
      autoStart = true;
      environment = {
        TZ = "America/Los_Angeles";
      };
      capabilities = {
        NET_ADMIN = true;
        NET_RAW = true;
      };
      privileged = true;
      volumes = [
        "/earth/home-assistant:/config"
        "/run/dbus:/run/dbus:ro"
      ];
      extraOptions = [
        "--network=host"
        "--security-opt=apparmor=unconfined"
      ];
    };
    containers.matter-server = {
      image = config.gaia.homeAssistant.matterjs.image;
      pull = "missing";
      autoStart = true;
      environment = {
        STORAGE_PATH = "/data";
        PORT = toString config.gaia.homeAssistant.matterjs.port;
        LISTEN_ADDRESS = "0.0.0.0";
        LOG_LEVEL = "debug";
        PRIMARY_INTERFACE = "enp5s0";
        ENABLE_TEST_NET_DCL = "true";
        OTA_PROVIDER_DIR = "/data/ota-provider";
        BLUETOOTH_ADAPTER = "1";
      };
      volumes = [
        "${matterjsDataDir}:/data"
        "/earth/home-assistant/matter-server/paa-root-certs:/data/paa-root-certs:ro"
        "/run/dbus:/run/dbus:ro"
      ];
      extraOptions = [
        "--network=host"
        "--security-opt=apparmor=unconfined"
        "--user=0:0"
      ];
    };
    containers.otbr = {
      image = containerImages.otbr;
      autoStart = true;
      environment = {
        BACKBONE_INTERFACE = "enp5s0";
        FIREWALL = "0";
        OTBR_FIREWALL = "0";
        INFRA_IF_NAME = "enp5s0";
        NAT64 = "0";
        # Keep OTBR's native web UI loopback-only and off port 80 so Gaia's
        # nginx homepage can own HTTP normally. homepage.nix proxies it back
        # out for LAN/tailnet users on :8088.
        HTTP_HOST = "127.0.0.1";
        HTTP_PORT = "8080";
      };
      cmd = [
        "--radio-url"
        # Match Home Assistant's ZBT-2 Thread setup: 460800 baud with RTS/CTS.
        "spinel+hdlc+uart:///dev/ttyACM0?uart-baudrate=460800&uart-flow-control"
      ];
      volumes = [
        "/earth/home-assistant/otbr:/data"
      ];
      extraOptions = [
        "--network=host"
        "--cap-add=NET_ADMIN"
        "--cap-add=NET_RAW"
        # The host-side path is prepared by podman-otbr preStart; map it to the
        # container's expected radio path.
        "--device=/run/otbr-thread-radio:/dev/ttyACM0"
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
    # When forwarding is enabled, keep RA processing active on the infra NIC
    # so Thread/Matter route updates are not dropped.
    "net.ipv6.conf.enp5s0.accept_ra" = 2;
    "net.ipv6.conf.enp5s0.accept_ra_rt_info_max_plen" = 64;
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
    "d /earth/backups 0755 root root - -"
    "d /earth/backups/matter 0750 root root - -"
    "d /earth/home-assistant 0750 hass hass - -"
    "d /earth/home-assistant/matter-server 0755 root root - -"
    "d /earth/home-assistant/matter-server/paa-root-certs 0755 root root - -"
    "d ${matterjsDataDir} 0755 root root - -"
    "d ${matterjsDataDir}/ota-provider 0755 root root - -"
    "d /earth/home-assistant/otbr 0755 root root - -"
    "d /var/lib/matter-thread-watchdog 0750 root root - -"
  ];

  environment.systemPackages = [
    matterThreadZbt2Recover
  ];

  # NetworkManager can occasionally reset per-interface RA handling on links where
  # forwarding is enabled. Re-assert accept_ra on the HA infra NIC so alternate
  # Thread BRs (e.g. Aqara M3) remain usable during OTBR recovery.
  systemd.services.enforce-enp5s0-accept-ra = {
    description = "Enforce IPv6 RA acceptance on enp5s0 for Thread BR failover";
    after = [
      "NetworkManager.service"
      "network-online.target"
    ];
    wants = [
      "NetworkManager.service"
      "network-online.target"
    ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "enforce-enp5s0-accept-ra" ''
        set -euo pipefail
        ${pkgs.procps}/bin/sysctl -w net.ipv6.conf.enp5s0.accept_ra=2 >/dev/null
        ${pkgs.procps}/bin/sysctl -w net.ipv6.conf.enp5s0.accept_ra_rt_info_max_plen=64 >/dev/null
      '';
    };
  };

  systemd.timers.enforce-enp5s0-accept-ra = {
    enable = true;
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1min";
      OnUnitActiveSec = "2min";
      Unit = "enforce-enp5s0-accept-ra.service";
    };
  };

  systemd.services."podman-home-assistant" = {
    # Keep existing dependencies on home-assistant.service working while the
    # actual unit is generated by virtualisation.oci-containers.
    aliases = [ "home-assistant.service" ];
    unitConfig = {
      RequiresMountsFor = [ "/earth" ];
    };
    after = [
      "earth.mount"
      "network-online.target"
    ];
    wants = [ "network-online.target" ];
    requires = [ "earth.mount" ];
    preStart = ''
      set -euo pipefail

      ${pkgs.coreutils}/bin/mkdir -p /earth/home-assistant/custom_components
      ${pkgs.coreutils}/bin/rm -f /earth/home-assistant/configuration.yaml
      ${pkgs.coreutils}/bin/cp --no-preserve=mode ${haConfigFile} /earth/home-assistant/configuration.yaml
      ${pkgs.coreutils}/bin/chmod 0644 /earth/home-assistant/configuration.yaml

      for component in ${lib.escapeShellArgs haCustomComponents}; do
        while IFS= read -r manifest; do
          src_dir="$(${pkgs.coreutils}/bin/dirname "$manifest")"
          domain="$(${pkgs.coreutils}/bin/basename "$src_dir")"
          ${pkgs.coreutils}/bin/rm -rf "/earth/home-assistant/custom_components/$domain"
          ${pkgs.coreutils}/bin/cp -a "$src_dir" "/earth/home-assistant/custom_components/$domain"
          ${pkgs.coreutils}/bin/chmod -R u+rwX,go+rX "/earth/home-assistant/custom_components/$domain"
        done < <(${pkgs.findutils}/bin/find "$component" -name manifest.json)
      done
    '';
  };

  systemd.services."podman-matter-server" = {
    after = [
      "earth.mount"
      "network-online.target"
      "podman-otbr.service"
      "otbr-ensure-dataset.service"
      "otbr-prefer-zbt2-router.service"
    ];
    wants = [
      "network-online.target"
      "podman-otbr.service"
      "otbr-ensure-dataset.service"
      "otbr-prefer-zbt2-router.service"
    ];
    requires = [ "earth.mount" ];
    unitConfig.RequiresMountsFor = [ "/earth" ];
    serviceConfig.TimeoutStopSec = lib.mkForce "2min";
    preStart = ''
      ${pkgs.coreutils}/bin/mkdir -p /earth/home-assistant/matter-server/paa-root-certs
      ${pkgs.coreutils}/bin/mkdir -p ${matterjsDataDir} ${matterjsDataDir}/ota-provider
    '';
  };

  systemd.services."podman-otbr" = {
    after = [ "earth.mount" ];
    requires = [ "earth.mount" ];
    unitConfig = {
      RequiresMountsFor = [ "/earth" ];
      # Skip start when no ACM serial devices exist at all.
      ConditionPathExistsGlob = "/dev/ttyACM*";
    };
    preStart = ''
      ${pkgs.coreutils}/bin/mkdir -p /earth/home-assistant/otbr

      thread_dev_by_id="/dev/serial/by-id/usb-Nabu_Casa_ZBT-2_DCB4D9123AF0-if00"
      thread_dev=""
      if [ -e "$thread_dev_by_id" ]; then
        thread_dev="$(${pkgs.coreutils}/bin/readlink -f "$thread_dev_by_id" 2>/dev/null || true)"
      fi
      if [ -z "$thread_dev" ]; then
        for candidate in /dev/ttyACM*; do
          if [ -e "$candidate" ]; then
            thread_dev="$candidate"
            break
          fi
        done
      fi
      if [ -z "$thread_dev" ]; then
        echo "podman-otbr: no Thread RCP device found" >&2
        exit 1
      fi
      ${pkgs.coreutils}/bin/ln -sfn "$thread_dev" /run/otbr-thread-radio
      echo "podman-otbr: using Thread RCP $thread_dev"
    '';
    serviceConfig = {
      # OTBR can wedge after transient RCP/USB faults; keep trying automatically.
      Restart = lib.mkForce "always";
      RestartSec = "5s";
    };
  };

  # OTBR can occasionally lose active dataset after RCP/USB faults. Re-seed from
  # decrypted sops env file and bring Thread back up when needed.
  systemd.services.otbr-ensure-dataset = let
    otbrEnsureDataset = pkgs.writeShellApplication {
      name = "otbr-ensure-dataset";
      runtimeInputs = [
        pkgs.coreutils
        pkgs.gnugrep
        pkgs.podman
      ];
      text = lib.replaceStrings ["@otbrImage@"] [containerImages.otbr] (builtins.readFile ./scripts/otbr-ensure-dataset.sh);
    };
  in {
    description = "Ensure OTBR has active Thread dataset";
    after = [
      "podman-otbr.service"
      "network-online.target"
    ];
    wants = [
      "podman-otbr.service"
      "network-online.target"
    ];
    serviceConfig = {
      Type = "oneshot";
      EnvironmentFile = config.sops.secrets."matter-env".path;
      ExecStart = "${otbrEnsureDataset}/bin/otbr-ensure-dataset";
      # podman exec may leave short-lived helper processes behind; do not fail
      # the unit on cgroup cleanup timing issues after successful execution.
      KillMode = "none";
      TimeoutStopSec = "5s";
    };
  };

  systemd.timers.otbr-ensure-dataset = {
    wantedBy = [
      "timers.target"
    ];
    timerConfig = {
      OnBootSec = "20s";
      OnUnitInactiveSec = "30min";
      Unit = "otbr-ensure-dataset.service";
    };
  };

  # Prefer Gaia's ZBT-2 OTBR as an active Thread router. Thread parent and
  # leader selection remains autonomous, but keeping the ZBT-2 router-eligible
  # and quickly promoted avoids it sitting as a child behind the Aqara M3.
  systemd.services.otbr-prefer-zbt2-router = let
    otbrPreferZbt2Router = pkgs.writeShellApplication {
      name = "otbr-prefer-zbt2-router";
      runtimeInputs = [
        pkgs.coreutils
        pkgs.podman
      ];
      text = lib.replaceStrings ["@otbrImage@"] [containerImages.otbr] (builtins.readFile ./scripts/otbr-prefer-zbt2-router.sh);
    };
  in {
    description = "Prefer Gaia ZBT-2 as an active Thread router";
    after = [
      "podman-otbr.service"
      "otbr-ensure-dataset.service"
      "network-online.target"
    ];
    wants = [
      "podman-otbr.service"
      "network-online.target"
    ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${otbrPreferZbt2Router}/bin/otbr-prefer-zbt2-router";
      KillMode = "none";
      TimeoutStopSec = "5s";
    };
  };

  systemd.timers.otbr-prefer-zbt2-router = {
    wantedBy = [
      "timers.target"
    ];
    timerConfig = {
      OnBootSec = "90s";
      OnUnitInactiveSec = "5min";
      Unit = "otbr-prefer-zbt2-router.service";
    };
  };

  # Detects Thread/RCP bad states and self-heals OTBR + Matter server.
  systemd.services.matter-thread-watchdog = let
    threadWatchdog = pkgs.writeShellApplication {
      name = "matter-thread-watchdog";
      runtimeInputs = [
        pkgs.coreutils
        pkgs.gawk
        pkgs.gnugrep
        pkgs.hostname
        pkgs.podman
        pkgs.systemd
        matterThreadZbt2Recover
      ];
      text = lib.replaceStrings ["@gnugrep@" "@otbrImage@"] ["${pkgs.gnugrep}" containerImages.otbr] (builtins.readFile ./scripts/matter-thread-watchdog.sh);
    };
  in {
    enable = true;
    description = "Watchdog for Matter/Thread bad states";
    wantedBy = [ "multi-user.target" ];
    after = [
      "podman-otbr.service"
      matterServerUnit
      "network-online.target"
    ];
    wants = [
      "podman-otbr.service"
      matterServerUnit
      "network-online.target"
    ];
    serviceConfig = {
      Type = "oneshot";
      EnvironmentFile = config.sops.secrets."matter-env".path;
      ExecStart = "${threadWatchdog}/bin/matter-thread-watchdog";
      # Avoid false failures caused by lingering podman exec cleanup helpers.
      KillMode = "none";
      TimeoutStopSec = "5s";
    };
  };

  systemd.timers.matter-thread-watchdog = {
    enable = true;
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "3min";
      OnUnitInactiveSec = "1min";
      Unit = "matter-thread-watchdog.service";
    };
  };

  # Cloudflare Tunnel for remote Home Assistant access without port-forwarding.
  # Expects CF_TUNNEL_TOKEN in the existing matter-env secret.
  systemd.services.cloudflare-ha-tunnel = {
    description = "Cloudflare Tunnel for Home Assistant";
    wantedBy = [ "multi-user.target" ];
    after = [
      "network-online.target"
      "home-assistant.service"
    ];
    wants = [
      "network-online.target"
      "home-assistant.service"
    ];
    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = "3s";
      EnvironmentFile = config.sops.secrets."matter-env".path;
      ExecStart = pkgs.writeShellScript "cloudflare-ha-tunnel-start" ''
        set -euo pipefail
        if [ -z "''${CF_TUNNEL_TOKEN:-}" ]; then
          echo "cloudflare-ha-tunnel: CF_TUNNEL_TOKEN missing in matter-env" >&2
          exit 1
        fi
        exec ${pkgs.cloudflared}/bin/cloudflared tunnel --no-autoupdate run --token "''${CF_TUNNEL_TOKEN}"
      '';
    };
  };
}
