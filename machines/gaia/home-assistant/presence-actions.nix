{
  config,
  pkgs,
  lib,
  matterNodeLabels ? {},
  ...
}: let
  pythonEnv = pkgs.python3.withPackages (ps: [
    ps.websockets
  ]);

  matterScriptsDir = ./scripts;
  matterPresenceActionsScript = "${matterScriptsDir}/matter-presence-actions.py";
  matterSolarApiScript = "${matterScriptsDir}/matter-solar-api.py";

  # Presence rules should follow the Matter NodeLabel because labels are restored
  # onto the node after re-pairing, while unique IDs can churn.
  nodeKeyForName = name: "label:${name}";

  # Rule-driven automation. Add more objects to this list to extend behavior.
  presenceRules = [
    {
      name = "office-presence-light";
      source_keys = [
        (nodeKeyForName "Office Presence")
        (nodeKeyForName "Office Presence - Far")
      ];
      target_key = nodeKeyForName "Office Light";
      target_endpoint = 1;
      cluster_id = 6;
      on_command = "On";
      off_command = "Off";
      payload = {};
      # Turn on when either:
      # 1) room is dark by sensor luminance, OR
      # 2) current time is between sunset and next sunrise.
      # (all still gated by presence=true)
      on_eligibility_mode = "any";
      dark_when_lux_below = 20.0;
      require_luminance_for_on = true;
      on_active_solar_window = {
        mode = "sunset_to_sunrise";
        latitude_env = "MATTER_SITE_LATITUDE";
        longitude_env = "MATTER_SITE_LONGITUDE";
        timezone_env = "MATTER_SITE_TIMEZONE";
      };
      luminance_attribute_paths = [
        "1/1024/0"
        "2/1024/0"
        "0/1024/0"
      ];
      target_onoff_attribute_path = "1/6/0";
      # Optional override per rule.
      # presence_attribute_paths = [ "1/1030/0" ];
    }

    {
      name = "office-presence-floor-lamp";
      source_keys = [
        (nodeKeyForName "Office Presence")
        (nodeKeyForName "Office Presence - Far")
      ];
      target_key = nodeKeyForName "Office Floor Lamp";
      target_endpoint = 1;
      cluster_id = 6;
      on_command = "On";
      off_command = "Off";
      payload = {};
      target_onoff_attribute_path = "1/6/0";
    }

    {
      name = "mbr-bathroom-presence-main";
      # Shower presence also triggers bathroom logic.
      source_keys = [
        (nodeKeyForName "MBR Bathroom Toilet Presence")
        (nodeKeyForName "MBR Bathroom Main Presence")
        (nodeKeyForName "MBR Shower Presence")
      ];
      target_key = nodeKeyForName "MBR Bathroom Main";
      target_endpoint = 1;
      cluster_id = 6;
      on_command = "On";
      off_command = "Off";
      payload = {};
      # Unless 11:30pm-5:00am.
      on_active_windows = [{ start = "05:00"; end = "23:30"; }];
      target_onoff_attribute_path = "1/6/0";
    }

    {
      name = "mbr-bathroom-presence-mirror";
      # Shower presence also triggers bathroom logic.
      source_keys = [
        (nodeKeyForName "MBR Bathroom Toilet Presence")
        (nodeKeyForName "MBR Bathroom Main Presence")
        (nodeKeyForName "MBR Shower Presence")
      ];
      target_key = nodeKeyForName "MBR Bathroom Mirror";
      target_endpoint = 1;
      cluster_id = 6;
      on_command = "On";
      off_command = "Off";
      payload = {};
      # 7:00am-11:00am only.
      on_active_windows = [{ start = "07:00"; end = "11:00"; }];
      target_onoff_attribute_path = "1/6/0";
    }

    {
      name = "mbr-bathroom-presence-warm";
      # Shower presence also triggers bathroom logic.
      source_keys = [
        (nodeKeyForName "MBR Bathroom Toilet Presence")
        (nodeKeyForName "MBR Bathroom Main Presence")
        (nodeKeyForName "MBR Shower Presence")
      ];
      target_key = nodeKeyForName "MBR Bathroom Warm";
      target_endpoint = 1;
      cluster_id = 6;
      on_command = "On";
      off_command = "Off";
      payload = {};
      # 11:30pm-5:00am only.
      on_active_windows = [{ start = "23:30"; end = "05:00"; }];
      target_onoff_attribute_path = "1/6/0";
    }

    {
      name = "mbr-bathroom-toilet-light-day";
      source_keys = [ (nodeKeyForName "MBR Bathroom Toilet Presence") ];
      target_key = nodeKeyForName "MBR Bathroom Toilet Light";
      target_endpoint = 1;
      on_cluster_id = 8;
      cluster_id = 6;
      on_command = "MoveToLevelWithOnOff";
      off_command = "Off";
      on_payload = {
        level = 254;
        transitionTime = 0;
        optionsMask = 0;
        optionsOverride = 0;
      };
      payload = {};
      on_active_windows = [{ start = "05:00"; end = "23:30"; }];
      target_onoff_attribute_path = "1/6/0";
    }

    {
      name = "mbr-bathroom-toilet-light-warm";
      source_keys = [ (nodeKeyForName "MBR Bathroom Toilet Presence") ];
      target_key = nodeKeyForName "MBR Bathroom Toilet Light";
      target_endpoint = 1;
      on_cluster_id = 8;
      cluster_id = 6;
      on_command = "MoveToLevelWithOnOff";
      off_command = "Off";
      on_payload = {
        level = 64;
        transitionTime = 0;
        optionsMask = 0;
        optionsOverride = 0;
      };
      payload = {};
      on_active_windows = [{ start = "23:30"; end = "05:00"; }];
      target_onoff_attribute_path = "1/6/0";
    }

    {
      name = "mbr-bathroom-toilet-fan";
      source_keys = [ (nodeKeyForName "MBR Bathroom Toilet Presence") ];
      target_key = nodeKeyForName "MBR Bathroom Toilet Fan";
      target_endpoint = 1;
      cluster_id = 6;
      on_command = "On";
      off_command = "Off";
      payload = {};
      off_delay_sec = 5 * 60;
      off_delay_min_presence_sec = 2 * 60;
      target_onoff_attribute_path = "1/6/0";
    }

    {
      name = "mbr-shower-presence-light";
      source_keys = [ (nodeKeyForName "MBR Shower Presence") ];
      target_key = nodeKeyForName "MBR Shower";
      target_endpoint = 1;
      cluster_id = 6;
      on_command = "On";
      off_command = "Off";
      payload = {};
      target_onoff_attribute_path = "1/6/0";
    }

    {
      name = "mbr-presence2-bed-light";
      source_keys = [ (nodeKeyForName "MBR Presence 2") ];
      target_key = nodeKeyForName "MBR Bed Light";
      target_endpoint = 1;
      cluster_id = 6;
      on_command = "On";
      off_command = "Off";
      payload = {};
      target_onoff_attribute_path = "1/6/0";
    }

    {
      name = "pantry-presence-light";
      source_keys = [ (nodeKeyForName "Pantry Presence") ];
      target_key = nodeKeyForName "Pantry Light";
      target_endpoint = 1;
      cluster_id = 6;
      on_command = "On";
      off_command = "Off";
      payload = {};
      target_onoff_attribute_path = "1/6/0";
    }

    {
      name = "upstairs-bathroom-presence-light";
      source_keys = [ (nodeKeyForName "Upstairs Bathroom Presence") ];
      target_key = nodeKeyForName "Upstairs Bathroom Light";
      target_endpoint = 1;
      cluster_id = 6;
      on_command = "On";
      off_command = "Off";
      payload = {};
      target_onoff_attribute_path = "1/6/0";
    }
  ];

  presenceRulesJson = builtins.toJSON presenceRules;

  matterPresenceActionsTool = pkgs.writeShellApplication {
    name = "matter-presence-actions";
    runtimeInputs = [pythonEnv];
    text = ''
      export PYTHONPATH='${matterScriptsDir}':''${PYTHONPATH:-}
      export MATTER_PRESENCE_RULES_JSON='${presenceRulesJson}'
      exec ${pythonEnv}/bin/python3 ${matterPresenceActionsScript} "$@"
    '';
  };

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
    matterPresenceActionsTool
    matterSolarApiTool
  ];

  systemd.services.matter-presence-actions = {
    description = "Matter presence-triggered actions";
    wantedBy = [
      "multi-user.target"
    ];
    after = [
      "podman-matter-server.service"
      "podman-otbr.service"
      "otbr-ensure-dataset.service"
      "network-online.target"
    ];
    wants = [
      "podman-matter-server.service"
      "podman-otbr.service"
      "otbr-ensure-dataset.service"
      "network-online.target"
    ];
    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = "5s";
      EnvironmentFile = config.sops.secrets."matter-env".path;
      Environment = [
        "MATTER_PRESENCE_POLL_INTERVAL_SEC=0.5"
      ];
      ExecStartPre = "${pkgs.bash}/bin/bash -c 'for i in {1..60}; do (echo > /dev/tcp/127.0.0.1/5580) >/dev/null 2>&1 && exit 0; sleep 1; done; echo matter-server ws not ready >&2; exit 1'";
      ExecStart = "${matterPresenceActionsTool}/bin/matter-presence-actions";
    };
  };

  systemd.services.matter-solar-api = {
    description = "Local solar geometry API for Matter tools";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = "3s";
      EnvironmentFile = config.sops.secrets."matter-env".path;
      ExecStart = "${matterSolarApiTool}/bin/matter-solar-api";
    };
  };
}
