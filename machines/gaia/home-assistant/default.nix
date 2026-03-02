{config, pkgs, lib, ...}: {
  imports = [
    ./devices.nix
    ./remote-actions.nix
    ./presence-actions.nix
    ./pairings.nix
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

  # Matter support for Home Assistant Core (no Supervisor add-ons on NixOS).
  # Home Assistant connects to this via `ws://127.0.0.1:5580/ws`.
  virtualisation.podman.enable = true;
  virtualisation.oci-containers = {
    backend = "podman";
    containers.matter-server = {
      image = "ghcr.io/matter-js/python-matter-server:stable";
      autoStart = true;
      cmd = [
        "--paa-root-cert-dir"
        "/data/paa-root-certs"
        "--bluetooth-adapter"
        "0"
        "--primary-interface"
        "enp5s0"
      ];
      volumes = [
        "/earth/home-assistant/matter-server:/data"
        "/earth/home-assistant/matter-server/.matter_server:/root/.matter_server"
        "/earth/home-assistant/matter-server/paa-root-certs:/data/paa-root-certs"
        "/run/dbus:/run/dbus:ro"
      ];
      extraOptions = [
        "--network=host"
        "--security-opt=apparmor=unconfined"
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
    "d /earth/home-assistant 0750 hass hass - -"
    "d /earth/home-assistant/matter-server 0755 root root - -"
    "d /earth/home-assistant/matter-server/.matter_server 0755 root root - -"
    "d /earth/home-assistant/matter-server/paa-root-certs 0755 root root - -"
    "d /earth/home-assistant/otbr 0755 root root - -"
    "d /var/lib/matter-thread-watchdog 0750 root root - -"
  ];

  systemd.services."home-assistant" = {
    # Ensure HA actually starts on boot and only after /earth is available.
    wantedBy = [ "multi-user.target" ];
    after = [ "earth.mount" ];
    requires = [ "earth.mount" ];
  };

  systemd.services."podman-matter-server" = {
    after = [ "earth.mount" ];
    requires = [ "earth.mount" ];
    unitConfig.RequiresMountsFor = [ "/earth" ];
    preStart = ''
      ${pkgs.coreutils}/bin/mkdir -p /earth/home-assistant/matter-server/.matter_server
      ${pkgs.coreutils}/bin/mkdir -p /earth/home-assistant/matter-server/paa-root-certs
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
          podman exec otbr ot-ctl "$@" 2>/dev/null
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

  # Detects Thread/RCP bad states and self-heals OTBR + Matter server.
  systemd.services.matter-thread-watchdog = let
    threadWatchdog = pkgs.writeShellApplication {
      name = "matter-thread-watchdog";
      runtimeInputs = [
        pkgs.coreutils
        pkgs.gawk
        pkgs.gnugrep
        pkgs.podman
        pkgs.systemd
      ];
      text = ''
        set -u

        state_dir="/var/lib/matter-thread-watchdog"
        last_restart_file="$state_dir/last-restart-epoch"
        mkdir -p "$state_dir"

        offline_threshold="''${THREAD_WATCHDOG_OFFLINE_THRESHOLD:-5}"
        cooldown_sec="''${THREAD_WATCHDOG_RESTART_COOLDOWN_SEC:-180}"
        alert_email="''${MATTER_ALERT_EMAIL:-home@bwang.dev}"
        alert_from="''${MATTER_ALERT_FROM:-home@bwang.dev}"
        ot_state=""

        bad_reason=""
        if ! podman ps --format '{{.Names}}' | grep -qx otbr; then
          bad_reason="otbr container missing"
        fi

        ot_state="$(podman exec otbr ot-ctl state 2>/dev/null | head -n1 | tr -d '\r' || true)"
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
        if journalctl -u podman-otbr.service --since "5 min ago" --no-pager 2>/dev/null | grep -q "RadioSpinelNoResponse"; then
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
              bad_reason="offline_thread_nodes=$offline_thread_nodes"
            fi
          fi
        fi

        if [ -z "$bad_reason" ]; then
          echo "matter-thread-watchdog: healthy"
          exit 0
        fi

        now_epoch="$(date +%s)"
        last_restart=0
        if [ -f "$last_restart_file" ]; then
          last_restart="$(cat "$last_restart_file" 2>/dev/null || echo 0)"
        fi
        elapsed="$((now_epoch - last_restart))"
        force_recover=0
        if printf '%s' "$bad_reason" | grep -q "rcp-timeout"; then
          force_recover=1
        fi
        if [ "$elapsed" -lt "$cooldown_sec" ] && [ "$force_recover" -ne 1 ]; then
          echo "matter-thread-watchdog: bad state detected ($bad_reason) but in cooldown (''${elapsed}s < ''${cooldown_sec}s)"
          exit 0
        fi

        echo "$now_epoch" > "$last_restart_file"
        echo "matter-thread-watchdog: recovering from bad state: $bad_reason"
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
        systemctl restart podman-otbr.service
        systemctl start otbr-ensure-dataset.service matter-reconcile.service matter-apply-node-labels.service matter-apply-ha-names.service

        if [ -n "$alert_email" ]; then
          subject="[gaia] Matter/Thread watchdog recovery triggered"
          body="Host: $(hostname)
Time: $(date -Iseconds)
Reason: $bad_reason
OfflineThreadNodes: $offline_thread_nodes
Action: cycled Thread USB (when possible), restarted podman-otbr; started reconcile/label timers."

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
      "podman-matter-server.service"
      "network-online.target"
    ];
    wants = [
      "podman-otbr.service"
      "podman-matter-server.service"
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
}
