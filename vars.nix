# Shared policy vocabulary for NixOS and Home Manager. App-owned settings remain
# extensible only where they intentionally pass through to an upstream format.
{config, lib, ...}: let
  inherit (lib) mkOption types;
  option = type: default: description: mkOption {inherit type default description;};
  str = option types.str;
  bool = option types.bool;
  strings = option (types.listOf types.str);
  settings = option (types.attrsOf types.anything);
in {
  options.variables = {
    isGui = bool true "Enable graphical Home Manager settings.";
    nestedDesktop = bool false "Run desktop settings inside an existing host session.";
    desktopStyle = {
      kirakira = {
        enable = bool false "Default kirakira embellishments for compatible GUI homes.";
        menus.enable = bool false "Use kirakira sidebar and tray menus.";
        volume.enable = bool false "Use the bounded volume sparkle overlay.";
        notifications.enable = bool false "Use animated Mako notification stars.";
      };
      apps = {
        enable = bool false "Use the shared charcoal style for managed applications.";
        desktopIntegration.enable = bool false "Manage GTK/Qt desktop integration; disabled on externally owned desktops.";
      };
      notifications.enable = bool false "Style an already-owned Mako notification server.";
      shell.enable = bool false "Use the illustrated shell style and motion.";
      launcher = {
        enable = bool false "Use the phone launcher in a native Hyprland session.";
        wallpaperPackage = option (types.nullOr types.package) null "Optional Skwd package for the launcher wallpaper context.";
      };
      mediaFeedback.enable = bool false "Use Mako volume and brightness feedback.";
    };
    gitIdentity = bool true "Install the shared Git author identity.";
    keyboardLayout = option (types.enum ["qwerty" "dvorak"]) "qwerty" "Hyprland keyboard binding layout.";
    obsidianVaultPath = option (types.nullOr types.str) null "Vault path; null uses the home-relative default.";
    hyprpaper-config = option types.lines "" "Additional Hyprpaper configuration.";
    hyprpanel = {
      hiddenMonitors = strings [] "Monitors omitted from Hyprpanel.";
      cpuTempSensor = str "/dev/hwmon_aquaflow_water_temp_sensor/temp1_input" "CPU temperature sensor path.";
    };
    kitty = {
      sshBackground = str "" "SSH background override; empty uses host-derived color.";
      sshForeground = str "" "SSH foreground override; empty uses the default.";
    };
    mangohud = {
      cpuTemp = bool true "Display CPU temperature in MangoHud.";
      extraConfig = option types.lines "" "Additional MangoHud settings.";
    };
    rofi.useX11 = bool false "Use the X11 Rofi package.";
    ewwPttStateFile = str "" "Push-to-talk state file; empty hides the indicator.";
    ewwSidebarScreens = strings ["0"] "Sidebar output names or indices.";
    ewwSidebarFontSize = str "13px" "Sidebar CSS font size.";
    ewwSidebarIconSize = str "16" "Sidebar icon size.";
    quickshellSidebar = {
      blockedAudioDescriptions = strings [] "Host-specific audio devices excluded from the sidebar.";
      workspaceHeight = str "18" "Workspace button height in QML.";
      workspaceSpacing = str "2" "Workspace button spacing in QML.";
    };
    waybarModulesLeft = strings [] "Additional left Waybar modules.";
    waybarBattery = str "BAT0" "Waybar battery device.";
    waybarSettings = settings {} "Additional upstream Waybar module settings.";
    touchscreen = {
      enable = bool false "Enable Home Manager touchscreen support.";
      enableScroll = bool true "Enable touch scrolling.";
      onScreenKeyboard = bool false "Enable the on-screen keyboard.";
      enableHyprgrass = bool config.variables.touchscreen.onScreenKeyboard "Enable Hyprgrass gestures.";
      enableHyprgrassWorkspaceSwipe = bool true "Enable touchscreen workspace swipes.";
      device = str "/dev/input/touchscreen" "Touchscreen input device.";
      ydotoolSocket = str "/run/ydotoold.socket" "Ydotool daemon socket.";
      hyprgrassBinds = strings [] "Extra Hyprgrass gesture bindings.";
      hyprgrassBindm = strings [",longpress:2,movewindow" ",longpress:3,resizewindow"] "Hyprgrass mouse bindings.";
      hyprgrassConfig = settings {
        sensitivity = 4.0;
        long_press_delay = 400;
        resize_on_border_long_press = true;
        edge_margin = 10;
      } "Upstream Hyprgrass settings.";
      hyprlandGesturesConfig = settings {
        workspace_swipe_touch = true;
        workspace_swipe_cancel_ratio = 0.15;
      } "Upstream Hyprland gesture settings.";
      sddmKeyboard = bool false "Enable the patched SDDM virtual keyboard.";
      sddmKeyboardMaxWidth = option types.ints.positive 1440 "Maximum SDDM keyboard width.";
      sddmKeyboardLayout = option (types.nullOr (types.enum ["qwerty" "dvorak-custom"])) null "SDDM layout; null follows the system keymap.";
    };
  };
  config._module.args.variables = config.variables;
}
