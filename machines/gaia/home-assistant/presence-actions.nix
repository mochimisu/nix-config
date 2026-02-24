{pkgs, lib, ...}: let
  pythonEnv = pkgs.python3.withPackages (ps: [
    ps.websockets
  ]);

  matterScriptsDir = ./scripts;
  matterPresenceActionsScript = "${matterScriptsDir}/matter-presence-actions.py";
  matterSolarApiScript = "${matterScriptsDir}/matter-solar-api.py";

  # Rule-driven automation. Add more objects to this list to extend behavior.
  presenceRules = [
    {
      name = "office-presence-light";
      source_keys = ["unique_id:26ADD8F211F1A97A"]; # Office Presence (MS605)
      target_key = "unique_id:14285507501172f6ff50bbcd35a43879"; # Office Light
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
      manual_override_sec = 1800; # 30 minutes
      target_onoff_attribute_path = "1/6/0";
      # Optional override per rule.
      # presence_attribute_paths = [ "1/1030/0" ];
    }

    {
      name = "mbr-bathroom-presence-main";
      # Shower presence also triggers bathroom logic.
      source_keys = [
        "unique_id:3EBD38F2CC110F47" # MBR Bathroom Presence
        "unique_id:78FFD38C8E551431" # MBR Shower Presence
      ];
      target_key = "unique_id:ac274f08f79b750e30dc485f96fdee2f"; # MBR Bathroom Main
      target_endpoint = 1;
      cluster_id = 6;
      on_command = "On";
      off_command = "Off";
      payload = {};
      # Unless 11:30pm-5:00am.
      on_active_windows = [{ start = "05:00"; end = "23:30"; }];
      manual_override_sec = 1800; # 30 minutes
      target_onoff_attribute_path = "1/6/0";
    }

    {
      name = "mbr-bathroom-presence-mirror";
      # Shower presence also triggers bathroom logic.
      source_keys = [
        "unique_id:3EBD38F2CC110F47" # MBR Bathroom Presence
        "unique_id:78FFD38C8E551431" # MBR Shower Presence
      ];
      target_key = "unique_id:3817c88523e9263acbddedf321283ad5"; # MBR Bathroom Mirror
      target_endpoint = 1;
      cluster_id = 6;
      on_command = "On";
      off_command = "Off";
      payload = {};
      # 7:00am-11:00am only.
      on_active_windows = [{ start = "07:00"; end = "11:00"; }];
      manual_override_sec = 1800; # 30 minutes
      target_onoff_attribute_path = "1/6/0";
    }

    {
      name = "mbr-bathroom-presence-warm";
      # Shower presence also triggers bathroom logic.
      source_keys = [
        "unique_id:3EBD38F2CC110F47" # MBR Bathroom Presence
        "unique_id:78FFD38C8E551431" # MBR Shower Presence
      ];
      target_key = "unique_id:0383480d4f0476afb1007333283762d6"; # MBR Bathroom Warm
      target_endpoint = 1;
      cluster_id = 6;
      on_command = "On";
      off_command = "Off";
      payload = {};
      # 11:30pm-5:00am only.
      on_active_windows = [{ start = "23:30"; end = "05:00"; }];
      manual_override_sec = 1800; # 30 minutes
      target_onoff_attribute_path = "1/6/0";
    }

    {
      name = "mbr-shower-presence-light";
      source_keys = ["unique_id:78FFD38C8E551431"]; # MBR Shower Presence
      target_key = "unique_id:f9da66c66a1a093459550ac0d11d9e98"; # MBR Shower
      target_endpoint = 1;
      cluster_id = 6;
      on_command = "On";
      off_command = "Off";
      payload = {};
      manual_override_sec = 1800; # 30 minutes
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
      "network-online.target"
    ];
    wants = [
      "podman-matter-server.service"
      "network-online.target"
    ];
    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = "5s";
      EnvironmentFile = "-/etc/secret/matter-reconcile.env";
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
      EnvironmentFile = "-/etc/secret/matter-reconcile.env";
      ExecStart = "${matterSolarApiTool}/bin/matter-solar-api";
    };
  };
}
