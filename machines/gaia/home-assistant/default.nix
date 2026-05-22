{config, pkgs, lib, ...}: let
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
    text = ''
      set -euo pipefail

      force=0
      if [ "''${1:-}" = "--force" ]; then
        force=1
      fi
      from_watchdog="''${MATTER_THREAD_RECOVER_FROM_WATCHDOG:-0}"
      timer_paused=0

      restore_watchdog_timer() {
        if [ "$timer_paused" -eq 1 ]; then
          systemctl start matter-thread-watchdog.timer || true
        fi
      }
      trap restore_watchdog_timer EXIT

      m3_route_pattern='^fd[0-9a-f:]+::/64 via fe80::[0-9a-f:]+ dev enp5s0 proto ra'
      if ! ip -6 route show | grep -E "$m3_route_pattern" >/dev/null; then
        echo "matter-thread-zbt2-recover: no alternate Thread ULA route via enp5s0; M3 fallback is not visible" >&2
        echo "matter-thread-zbt2-recover: refusing to bounce ZBT-2 without --force" >&2
        if [ "$force" -ne 1 ]; then
          exit 1
        fi
      fi

      echo "matter-thread-zbt2-recover: alternate Thread routes before recovery:"
      ip -6 route show | grep -E "$m3_route_pattern" || true

      echo "matter-thread-zbt2-recover: pausing watchdog and restarting only ZBT-2 OTBR"
      if [ "$from_watchdog" = "1" ]; then
        systemctl stop matter-thread-watchdog.timer || true
      else
        systemctl stop matter-thread-watchdog.timer matter-thread-watchdog.service || true
      fi
      timer_paused=1
      systemctl restart podman-otbr.service

      echo "matter-thread-zbt2-recover: re-seeding/checking dataset and preferring ZBT-2 as router"
      systemctl start otbr-ensure-dataset.service
      systemctl start otbr-prefer-zbt2-router.service

      echo "matter-thread-zbt2-recover: restarting local Matter listeners, not Matter.js server"
      systemctl try-restart matter-keepalive.service || true
      systemctl start matter-apply-node-labels.service matter-apply-ha-names.service || true
      systemctl start matter-thread-watchdog.timer

      echo "matter-thread-zbt2-recover: route state after recovery:"
      ip -6 route show | grep -E '(^fd[0-9a-f:]+::/64 .* (dev enp5s0|dev wpan0))' || true
      systemctl --no-pager --full status podman-otbr.service | sed -n '1,18p'
    '';
  };
in {
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

  # Matter operates over UDP/5540.
  networking.firewall.allowedUDPPorts = [
    5540
  ];
  networking.firewall.allowedTCPPorts = [
    8123
    config.gaia.homeAssistant.matterjs.port
  ];

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
      image = "ghcr.io/matter-js/matterjs-server:${config.gaia.homeAssistant.matterjs.imageTag}";
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
      image = "openthread/otbr:latest";
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
        "spinel+hdlc+uart:///dev/ttyACM0?uart-baudrate=460800"
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
    unitConfig = {
      Alias = "home-assistant.service";
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
      text = ''
        set -u

        if [ -z "''${MATTER_THREAD_DATASET_HEX:-}" ]; then
          echo "otbr-ensure-dataset: MATTER_THREAD_DATASET_HEX not set; skipping"
          exit 0
        fi

        is_attached_state() {
          case "$1" in
            child|router|leader) return 0 ;;
            *) return 1 ;;
          esac
        }

        podman_otctl() {
          local container
          container="$(
            podman ps \
              --filter ancestor=docker.io/openthread/otbr:latest \
              --format '{{.Names}}' \
              | head -n1
          )"
          if [ -z "$container" ]; then
            return 1
          fi
          podman exec "$container" ot-ctl "$@" 2>/dev/null
        }

        with_retry() {
          local attempts max_attempts
          max_attempts=''${OTBR_CTL_MAX_ATTEMPTS:-30}
          attempts=0
          while [ "$attempts" -lt "$max_attempts" ]; do
            if "$@"; then
              return 0
            fi
            attempts=$((attempts + 1))
            sleep 1
          done
          return 1
        }

        if ! with_retry podman_otctl state >/dev/null; then
          echo "otbr-ensure-dataset: ot-ctl not reachable after retries; will retry on next timer run"
          exit 0
        fi

        state="$(podman_otctl state | head -n1 | tr -d '\r' || true)"
        if is_attached_state "$state"; then
          # Do not rewrite dataset while attached; it can force re-attach churn.
          echo "otbr-ensure-dataset: state=$state, skipping dataset reseed"
          echo "otbr-ensure-dataset: final_state=$state"
          exit 0
        fi

        desired="$(printf '%s' "$MATTER_THREAD_DATASET_HEX" | tr 'A-F' 'a-f')"
        active="$(podman_otctl dataset active -x | grep -E '^[0-9a-fA-F]+$' | head -n1 | tr 'A-F' 'a-f' || true)"

        if [ -z "$active" ] || [ "$active" != "$desired" ]; then
          echo "otbr-ensure-dataset: setting active dataset"
          if ! with_retry podman_otctl dataset set active "$MATTER_THREAD_DATASET_HEX" >/dev/null; then
            echo "otbr-ensure-dataset: unable to set dataset right now; will retry on next timer run"
            exit 0
          fi
        fi

        state="$(podman_otctl state | head -n1 | tr -d '\r' || true)"
        if ! is_attached_state "$state"; then
          echo "otbr-ensure-dataset: state=$state, starting Thread"
          with_retry podman_otctl ifconfig up >/dev/null || true
          with_retry podman_otctl thread start >/dev/null || true
        fi

        # Give OTBR time to attach after startup/restart so boot-time checks
        # don't report transient detached states.
        attach_wait_sec="''${OTBR_ATTACH_WAIT_SEC:-45}"
        waited=0
        final_state="$(podman_otctl state | head -n1 | tr -d '\r' || true)"
        while ! is_attached_state "$final_state" && [ "$waited" -lt "$attach_wait_sec" ]; do
          sleep 1
          waited=$((waited + 1))
          final_state="$(podman_otctl state | head -n1 | tr -d '\r' || true)"
        done

        echo "otbr-ensure-dataset: final_state=$final_state"
      '';
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
      text = ''
        set -u

        podman_otctl() {
          local container
          container="$(
            podman ps \
              --filter ancestor=docker.io/openthread/otbr:latest \
              --format '{{.Names}}' \
              | head -n1
          )"
          if [ -z "$container" ]; then
            return 1
          fi
          podman exec "$container" ot-ctl "$@" 2>/dev/null
        }

        with_retry() {
          local attempts max_attempts
          max_attempts=''${OTBR_CTL_MAX_ATTEMPTS:-30}
          attempts=0
          while [ "$attempts" -lt "$max_attempts" ]; do
            if "$@"; then
              return 0
            fi
            attempts=$((attempts + 1))
            sleep 1
          done
          return 1
        }

        if ! with_retry podman_otctl state >/dev/null; then
          echo "otbr-prefer-zbt2-router: ot-ctl not reachable; will retry later"
          exit 0
        fi

        # These commands are best-effort across OTBR image versions. They are
        # harmless when unsupported and useful when the CLI exposes them.
        podman_otctl routereligible enable >/dev/null || true
        podman_otctl routerupgradethreshold 32 >/dev/null || true
        podman_otctl routerselectionjitter 1 >/dev/null || true

        state="$(podman_otctl state | head -n1 | tr -d '\r' || true)"
        if [ "$state" = "child" ]; then
          podman_otctl state router >/dev/null || true
        fi

        # Gaia has seen repeated TREL ack timeouts against the Aqara M3 even
        # with excellent 15.4 RSSI. Prefer the direct Thread radio path when
        # this OpenThread build supports toggling TREL from ot-ctl.
        if [ "''${OTBR_DISABLE_TREL:-1}" = "1" ]; then
          podman_otctl trel disable >/dev/null || true
        fi

        final_state="$(podman_otctl state | head -n1 | tr -d '\r' || true)"
        echo "otbr-prefer-zbt2-router: state=$final_state"
      '';
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
      text = ''
        set -u

        state_dir="/var/lib/matter-thread-watchdog"
        last_restart_file="$state_dir/last-restart-epoch"
        bad_checks_file="$state_dir/consecutive-bad-checks"
        mkdir -p "$state_dir"

        offline_threshold="''${THREAD_WATCHDOG_OFFLINE_THRESHOLD:-5}"
        recovery_after_checks="''${THREAD_WATCHDOG_RECOVERY_AFTER_CHECKS:-10}"
        hard_recovery_after_checks="''${THREAD_WATCHDOG_HARD_RECOVERY_AFTER_CHECKS:-30}"
        cooldown_sec="''${THREAD_WATCHDOG_RESTART_COOLDOWN_SEC:-3600}"
        settle_sec="''${THREAD_WATCHDOG_OTBR_SETTLE_SEC:-900}"
        alert_email="''${MATTER_ALERT_EMAIL:-home@bwang.dev}"
        alert_from="''${MATTER_ALERT_FROM:-home@bwang.dev}"
        ot_state=""
        otbr_container=""

        restart_matter_clients() {
          systemctl try-restart \
            matter-keepalive.service || true
        }

        recover_zbt2() {
          force_arg="''${1:-}"
          if [ -n "$force_arg" ]; then
            MATTER_THREAD_RECOVER_FROM_WATCHDOG=1 matter-thread-zbt2-recover "$force_arg"
          else
            MATTER_THREAD_RECOVER_FROM_WATCHDOG=1 matter-thread-zbt2-recover
          fi
        }

        find_otbr_container() {
          podman ps \
            --filter ancestor=docker.io/openthread/otbr:latest \
            --format '{{.Names}}' \
            | head -n1
        }

        bad_reason=""
        otbr_container="$(find_otbr_container || true)"
        if [ -z "$otbr_container" ]; then
          bad_reason="otbr container missing"
        fi

        if [ -n "$otbr_container" ]; then
          ot_state="$(podman exec "$otbr_container" ot-ctl state 2>/dev/null | head -n1 | tr -d '\r' || true)"
        fi
        if [ -z "$ot_state" ]; then
          if [ -n "$bad_reason" ]; then
            bad_reason="$bad_reason; ot-ctl unreachable"
          else
            bad_reason="ot-ctl unreachable"
          fi
        elif [ "$ot_state" != "child" ] && [ "$ot_state" != "router" ] && [ "$ot_state" != "leader" ]; then
          if [ -n "$bad_reason" ]; then
            bad_reason="$bad_reason; ot-state=$ot_state"
          else
            bad_reason="ot-state=$ot_state"
          fi
        fi

        # Catch known RCP transport failures even when the service still looks active.
        if journalctl -u podman-otbr.service --since "30 sec ago" --no-pager 2>/dev/null | grep -q "RadioSpinelNoResponse"; then
          if [ -n "$bad_reason" ]; then
            bad_reason="$bad_reason; rcp-timeout"
          else
            bad_reason="rcp-timeout"
          fi
        fi

        offline_thread_nodes=0
        if command -v matter-health >/dev/null 2>&1; then
          offline_thread_nodes="$(
            matter-health 2>/dev/null \
              | awk -F '\t' '
                  NR==1 { next }
                  $2=="False" && $5 ~ /(Inovelli|Meross|IKEA of Sweden|SmartWings|Aqara|Nanoleaf)/ { c++ }
                  END { print c+0 }
                '
          )"
          if [ "$offline_thread_nodes" -ge "$offline_threshold" ]; then
            if [ -n "$bad_reason" ]; then
              bad_reason="$bad_reason; offline_thread_nodes=$offline_thread_nodes"
            else
              echo "matter-thread-watchdog: Matter nodes degraded (offline_thread_nodes=$offline_thread_nodes) but OTBR state is $ot_state; not restarting Thread"
              rm -f "$bad_checks_file"
              exit 0
            fi
          fi
        fi

        if [ -z "$bad_reason" ]; then
          rm -f "$bad_checks_file"
          echo "matter-thread-watchdog: healthy"
          exit 0
        fi

        bad_checks=0
        if [ -f "$bad_checks_file" ]; then
          bad_checks="$(cat "$bad_checks_file" 2>/dev/null || echo 0)"
        fi
        bad_checks="$((bad_checks + 1))"
        echo "$bad_checks" > "$bad_checks_file"

        now_epoch="$(date +%s)"
        last_restart=0
        if [ -f "$last_restart_file" ]; then
          last_restart="$(cat "$last_restart_file" 2>/dev/null || echo 0)"
        fi
        elapsed="$((now_epoch - last_restart))"
        otbr_age_sec=""
        active_usec="$(systemctl show -P ActiveEnterTimestampMonotonic podman-otbr.service 2>/dev/null || echo 0)"
        uptime_usec="$(awk '{ printf "%d", $1 * 1000000 }' /proc/uptime 2>/dev/null || echo 0)"
        if [ -n "$active_usec" ] && [ "$active_usec" -gt 0 ] && [ "$uptime_usec" -gt "$active_usec" ]; then
          otbr_age_sec="$(( (uptime_usec - active_usec) / 1000000 ))"
        fi
        force_recover=0
        # Only bypass cooldown when RCP timeout is happening right now *and*
        # ot-ctl is currently unreachable for several checks in a row. This
        # avoids cycling the radio while OTBR/Matter are still recovering from
        # a recent restart and rebuilding operational addresses.
        if [ "$bad_checks" -ge "$recovery_after_checks" ] && printf '%s' "$bad_reason" | grep -q "rcp-timeout" && printf '%s' "$bad_reason" | grep -q "ot-ctl unreachable"; then
          force_recover=1
        fi

        # Two-stage recovery:
        # Initial bad checks -> observe only. Matter.js and OTBR can take a few
        # minutes to settle after a border-router restart or OMR prefix change.
        # Recovery check -> OTBR restart only.
        # Later checks -> hard recovery (USB cycle + OTBR restart), cooldown-gated.
        if [ "$bad_checks" -lt "$recovery_after_checks" ]; then
          echo "matter-thread-watchdog: bad state observed ($bad_reason), waiting for confirmation ($bad_checks/$recovery_after_checks)"
          exit 0
        fi

        if [ -n "$otbr_age_sec" ] && [ "$otbr_age_sec" -lt "$settle_sec" ]; then
          echo "matter-thread-watchdog: bad state observed ($bad_reason), but OTBR restarted ''${otbr_age_sec}s ago; allowing settle window ''${settle_sec}s"
          exit 0
        fi

        if [ "$bad_checks" -eq "$recovery_after_checks" ]; then
          echo "matter-thread-watchdog: targeted ZBT-2 recovery from bad state: $bad_reason"
          echo "$now_epoch" > "$last_restart_file"
          if ! recover_zbt2; then
            echo "matter-thread-watchdog: targeted ZBT-2 recovery refused without fallback route; forcing because bad state was confirmed"
            recover_zbt2 --force
          fi
          rm -f "$bad_checks_file"
          exit 0
        fi

        if [ "$bad_checks" -lt "$hard_recovery_after_checks" ] && [ "$force_recover" -ne 1 ]; then
          echo "matter-thread-watchdog: bad state persists ($bad_reason) but hard recovery waits for $hard_recovery_after_checks checks; currently $bad_checks"
          exit 0
        fi

        if [ "$elapsed" -lt "$cooldown_sec" ] && [ "$force_recover" -ne 1 ]; then
          echo "matter-thread-watchdog: bad state persists ($bad_reason) but hard-recovery cooldown active (''${elapsed}s < ''${cooldown_sec}s)"
          exit 0
        fi

        echo "$now_epoch" > "$last_restart_file"
        echo "matter-thread-watchdog: hard recovery from bad state: $bad_reason"
        thread_dev_by_id="/dev/serial/by-id/usb-Nabu_Casa_ZBT-2_DCB4D9123AF0-if00"
        thread_dev_fallback=""
        for candidate in /dev/ttyACM*; do
          if [ -e "$candidate" ]; then
            thread_dev_fallback="$candidate"
            break
          fi
        done
        usb_reset_done=0
        tty_real=""
        if [ -e "$thread_dev_by_id" ]; then
          tty_real="$(readlink -f "$thread_dev_by_id" 2>/dev/null || true)"
        elif [ -n "$thread_dev_fallback" ]; then
          tty_real="$(readlink -f "$thread_dev_fallback" 2>/dev/null || true)"
        fi
        if [ -n "$tty_real" ]; then
          tty_name="$(basename "$tty_real" 2>/dev/null || true)"
          if [ -n "$tty_name" ] && [ -e "/sys/class/tty/$tty_name/device" ]; then
            usb_node="$(readlink -f "/sys/class/tty/$tty_name/device" 2>/dev/null || true)"
            while [ -n "$usb_node" ] && [ "$usb_node" != "/" ]; do
              if [ -w "$usb_node/authorized" ]; then
                # Only cycle the USB *device* node (e.g. .../3-4), never an
                # interface node (e.g. .../3-4:1.0). Cycling an interface can
                # leave cdc_acm unbound with no ttyACM device.
                usb_base="$(basename "$usb_node" 2>/dev/null || true)"
                if printf '%s' "$usb_base" | ${pkgs.gnugrep}/bin/grep -q ':'; then
                  usb_node="$(dirname "$usb_node")"
                  continue
                fi
                echo "matter-thread-watchdog: cycling USB device at $usb_node"
                echo 0 > "$usb_node/authorized" || true
                sleep 1
                echo 1 > "$usb_node/authorized" || true
                usb_reset_done=1
                break
              fi
              usb_node="$(dirname "$usb_node")"
            done
          fi
        fi
        if [ "$usb_reset_done" -ne 1 ]; then
          echo "matter-thread-watchdog: USB reset path not found; continuing with OTBR restart"
        fi
        recover_zbt2 --force
        rm -f "$bad_checks_file"

        if [ -n "$alert_email" ]; then
          subject="[gaia] Matter/Thread watchdog recovery triggered"
          body="Host: $(hostname)
Time: $(date -Iseconds)
Reason: $bad_reason
OfflineThreadNodes: $offline_thread_nodes
Action: hard recovery (cycled Thread USB when possible, restarted podman-otbr); started label timers."

          if command -v sendmail >/dev/null 2>&1; then
            {
              printf 'From: %s\n' "$alert_from"
              printf 'To: %s\n' "$alert_email"
              printf 'Subject: %s\n' "$subject"
              printf '\n%s\n' "$body"
            } | sendmail -t || true
          elif command -v mail >/dev/null 2>&1; then
            printf '%s\n' "$body" | mail -s "$subject" -r "$alert_from" "$alert_email" || true
          else
            echo "matter-thread-watchdog: alert email requested but no sendmail/mail binary found"
          fi
        fi
      '';
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
