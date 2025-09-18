{ config, lib, pkgs, ... }:

let
  inherit (lib) mkIf hasPrefix;

  variables = config.variables or {};
  astalBar = variables.astalBar or {};
  waybarSettings = variables.waybarSettings or {};
  waybarModulesLeft = variables.waybarModulesLeft or [];

  firstIcon = icons:
    if icons == null then null
    else if builtins.isList icons && builtins.length icons > 0 then builtins.elemAt icons 0
    else if builtins.isAttrs icons && builtins.hasAttr "default" icons then icons.default
    else if builtins.isString icons then icons
    else null;

  defaultCpuSensor = {
    id = "temperature#cpu";
    icon = "";
    path = "/sys/devices/platform/coretemp.0/hwmon";
    input = "temp1_input";
    critical = 80;
    format = "{temperatureC}°C {icon}";
    label = "CPU";
  };

  cpuSettings = if builtins.hasAttr "temperature#cpu" waybarSettings then waybarSettings."temperature#cpu" else {};

  cpuSensor = {
    inherit (defaultCpuSensor) id label;
    icon = let candidate = firstIcon (cpuSettings."format-icons" or null); in if candidate != null then candidate else defaultCpuSensor.icon;
    path = cpuSettings."hwmon-path-abs" or defaultCpuSensor.path;
    input = cpuSettings."input-filename" or defaultCpuSensor.input;
    critical = cpuSettings."critical-threshold" or defaultCpuSensor.critical;
    format = cpuSettings.format or defaultCpuSensor.format;
  };

  temperatureNames = builtins.filter (name: hasPrefix "temperature#" name) waybarModulesLeft;

  extraSensors = builtins.filter (sensor: sensor != null) (map (name:
    if builtins.hasAttr name waybarSettings then
      let
        settings = waybarSettings.${name};
        icon = let candidate = firstIcon (settings."format-icons" or null); in if candidate != null then candidate else "";
        path = settings."hwmon-path-abs" or "";
      in
        if path == "" then null else {
          id = name;
          label = name;
          icon = icon;
          path = path;
          input = settings."input-filename" or "temp1_input";
          critical = settings."critical-threshold" or null;
          format = settings.format or "{temperatureC}°C {icon}";
        }
    else null) temperatureNames);

  configuredSensors = astalBar.extraSensors or [];

  sensors = builtins.filter (sensor: sensor.path != null && sensor.path != "") ([cpuSensor] ++ extraSensors ++ configuredSensors);

  toggleApp = pkgs.writeShellScriptBin "toggle-app" ''
    #!/usr/bin/env bash

    if [ -z "$1" ]; then
      echo "Usage: toggle-app <application_name>"
      exit 1
    fi

    APP_NAME="$1"
    KILL_PATTERN="''${2:-$1}"

    if pgrep "$KILL_PATTERN" > /dev/null; then
      pkill "$KILL_PATTERN"
    else
      "$APP_NAME" &>/dev/null &
    fi
  '';

  barConfig = {
    toggleAppPath = "${toggleApp}/bin/toggle-app";
    hyprland = {
      workspaceIcons = {
        default = "";
        active = "";
        urgent = "";
      };
      excludeOutputs = astalBar.excludeOutputs or ["HDMI-A-1"];
    };
    sensors = sensors;
    memory = {
      icon = "";
    };
    audio = {
      icons = {
        muted = "";
        low = "";
        medium = "";
        high = "";
      };
      onClick = "pwvucontrol";
    };
    bluetooth = {
      icon = "";
      onClick = {
        app = "blueman-manager";
        kill = "blueman-manage";
      };
    };
    clock = {
      format = "%I:%M %p";
      onClick = "karlender";
    };
    network = {
      icons = {
        wifi = "";
        ethernet = "";
        linked = "(No IP)";
        disconnected = "D/C ⚠";
      };
    };
    battery = {
      device = if builtins.hasAttr "waybarBattery" variables then variables.waybarBattery else "BAT0";
      icons = ["" "" "" "" ""];
      chargingIcon = "";
    };
    tray = {
      iconSize = 18;
    };
  };

  barConfigJson = pkgs.writeText "astal-bar-config.json" (builtins.toJSON barConfig);
  barConfigScript = pkgs.writeText "astal-bar-config.mjs" (builtins.readFile ./config.mjs);
  barStyle = pkgs.writeText "astal-bar-style.css" (builtins.readFile ./style.css);

  # Wrap ags so the GObject introspection stack can see GTK4 when Astal loads.
  agsWithGtk4 = pkgs.writeShellScriptBin "ags" ''
    export GI_TYPELIB_PATH="${pkgs.gtk4}/lib/girepository-1.0:${pkgs.libadwaita}/lib/girepository-1.0:${pkgs.graphene}/lib/girepository-1.0:${pkgs.astal.hyprland}/lib/girepository-1.0''${GI_TYPELIB_PATH:+:$GI_TYPELIB_PATH}"
    export LD_LIBRARY_PATH="${pkgs.gtk4}/lib:${pkgs.libadwaita}/lib:${pkgs.graphene}/lib:${pkgs.astal.hyprland}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    export XDG_DATA_DIRS="${pkgs.libadwaita}/share:${pkgs.gtk4}/share''${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"
    exec ${pkgs.ags}/bin/ags "$@"
  '';
in
{
  home.packages = mkIf pkgs.stdenv.isLinux [
    agsWithGtk4
    toggleApp
    pkgs.pwvucontrol
    pkgs.karlender
  ];

  home.file.".config/ags/bar.json".source = barConfigJson;
  home.file.".config/ags/config.mjs".source = barConfigScript;
  home.file.".config/ags/style.css".source = barStyle;

  wayland.windowManager.hyprland.settings = {
    "exec-once" = lib.mkAfter [
      "ags --config ~/.config/ags/config.mjs"
    ];
    layerrule = lib.mkAfter [
      "blur, ^(astal-bar)$"
    ];
  };
}
