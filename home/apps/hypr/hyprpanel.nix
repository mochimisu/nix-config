{ pkgs, lib, config, ... } : 

let
  hyprpanelVars = if builtins.hasAttr "hyprpanel" config.variables then config.variables.hyprpanel else {};
  hiddenMonitors = if builtins.hasAttr "hyprpanelHiddenMonitors" hyprpanelVars then config.variables.hyprpanelHiddenMonitors else [];
  defaultLayout = {
    name = "*";
    value = {
      left = [ "dashboard" "workspaces" "cpu" "cputemp" ];
      middle = [ "windowtitle" ];
      right = [ "media" "systray" "network" "bluetooth" "notifications" "volume" "clock" "battery" ];
    };
  };
  hiddenLayouts = map (monitor: {
    name = monitor;
    value = {
      left = [];
      middle = [];
      right = [];
    };
  }) hiddenMonitors;
  combinedLayouts = lib.listToAttrs ( hiddenLayouts ++ [ defaultLayout ]);
  cpuTempAttr = if builtins.hasAttr "cpuTempSensor" hyprpanelVars then {
    "bar.customModules.cpuTemp.sensor" = hyprpanelVars.cpuTempSensor;
  } else {};
  avatar = builtins.fetchurl {
    url = "https://avatars.githubusercontent.com/u/868700?v=4";
    sha256 = "sha256:0v186vc1l2z1fxm5lyf0lfqf1fkw18kv4945vay7clpryj2a4vh3";
  };
  hyprpanelConfig = lib.recursiveUpdate {
    "bar.customModules.updates.pollingInterval" = 1440000;
    "theme.font.size" = "1rem";
    "theme.font.weight" = 500;
    "theme.bar.floating" = false;
    "theme.bar.buttons.enableBorders" = false;
    "theme.bar.border.width" = "0.15em";
    "menus.volume.raiseMaximumVolume" = true;
    "menus.clock.time.hideSeconds" = true;
    "menus.clock.weather.unit" = "imperial";
    "menus.bluetooth.showBattery" = true;
    "menus.dashboard.powermenu.avatar.image" = avatar;
    "notifications.position" = "top right";
    "notifications.monitor" = 1;
    "notifications.active_monitor" = false;
    "menus.dashboard.stats.enable_gpu" = false;
    "menus.dashboard.shortcuts.enabled" = false;
    "bar.launcher.icon" = "󰣇";
    "theme.bar.margin_sides" = "0.5em";
    "theme.bar.outer_spacing" = "0";
    "bar.launcher.autoDetectIcon" = true;
    "theme.bar.buttons.dashboard.enableBorder" = false;
    "theme.bar.buttons.bluetooth.enableBorder" = false;
    "theme.bar.buttons.network.enableBorder" = false;
    "theme.bar.buttons.systray.enableBorder" = false;
    "theme.bar.buttons.clock.enableBorder" = false;
    "theme.bar.buttons.modules.cpu.enableBorder" = false;
    "menus.bluetooth.batteryState" = "connected";
    "bar.layouts" = combinedLayouts;
    "bar.media.truncation" = true;
    "bar.media.show_label" = true;
    "bar.clock.format" = "%I:%M %p";
    "bar.clock.showIcon" = false;
    "bar.workspaces.show_icons" = false;
    "bar.workspaces.show_numbered" = true;
    "bar.workspaces.showWsIcons" = false;
    "bar.workspaces.numbered_active_indicator" = "highlight";
    "menus.transition" = "crossfade";
    "tear" = true;
  } cpuTempAttr;
  in
{
  home.packages = with pkgs; [
    hyprpanel
  ];
  wayland.windowManager.hyprland = {
    settings = {
      "exec-once" = [
        "hyprpanel"
      ];
    };
  };

  home.file.".cache/ags/hyprpanel/options.json".source = pkgs.writeText "hyprpanel/options.json" (builtins.toJSON hyprpanelConfig);
}
