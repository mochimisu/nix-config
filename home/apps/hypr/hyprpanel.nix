{ pkgs, lib, config, ... } : 

let
  hiddenMonitors = if builtins.hasAttr "hyprpanelHiddenMonitors" config.variables then config.variables.hyprpanelHiddenMonitors else [];
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
  hyprpanelConfig = {
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
    "menus.dashboard.powermenu.avatar.image" = "/home/brandon/Downloads/868700.jpeg";
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
    "bar.customModules.cpuTemp.sensor" = "/sys/devices/pci0000:00/0000:00:14.0/usb1/1-10/1-10.2/1-10.2.4/1-10.2.4:1.1/0003:0C70:F012.0009/hwmon/hwmon8/temp1_input";
    "bar.workspaces.show_icons" = false;
    "bar.workspaces.show_numbered" = true;
    "bar.workspaces.showWsIcons" = false;
    "bar.workspaces.numbered_active_indicator" = "highlight";
    "menus.transition" = "crossfade";
    "tear" = true;
  };
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
