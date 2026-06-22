{
  config,
  lib,
  pkgs,
  ...
}: let
  lua = lib.generators.mkLuaInline;
  xrealLua = action:
    lua ''
      function()
        local main_output = "eDP-1"
        local xreal_output = "DP-1"

        local function xreal_connected()
          return hl.get_monitor(xreal_output) ~= nil
        end

        local function main_on()
          hl.monitor({
            output = main_output,
            mode = "2560x1600@180",
            position = "0x0",
            scale = 1.25,
          })
        end

        local function both_on()
          main_on()
          hl.monitor({
            output = xreal_output,
            mode = "1920x1080@120",
            position = "2048x0",
            scale = 1,
          })
        end

        local function glasses_only()
          hl.monitor({
            output = xreal_output,
            mode = "1920x1080@120",
            position = "0x0",
            scale = 1,
          })
          hl.monitor({
            output = main_output,
            disabled = true,
          })
        end

        local action = "${action}"

        if not xreal_connected() then
          _G.oasis_xreal_glasses_only = false
          main_on()
          return
        end

        if action == "toggle" then
          _G.oasis_xreal_glasses_only = not _G.oasis_xreal_glasses_only
        end

        if _G.oasis_xreal_glasses_only then
          glasses_only()
        else
          both_on()
        end
      end
    '';
in {
  variables.keyboardLayout = "dvorak";
  variables.hyprpanel = {
    cpuTempSensor = "/sys/devices/pci0000:00/0000:00:08.1/0000:c4:00.0/hwmon/hwmon9/temp1_input";
  };
  variables.mangohud = {
    cpuTemp = false;
    extraConfig = ''
      custom_text=CPU
      exec=${pkgs.gawk}/bin/awk '{ printf "%dC", $1 / 1000 }' /sys/devices/pci0000:00/0000:00:08.1/0000:c4:00.0/hwmon/hwmon9/temp1_input
    '';
  };
  variables.rofi = {
    useX11 = true;
  };
  variables.hyprpaper-config = ''
    wallpaper {
      monitor = DP-2
      path = ${config.home.homeDirectory}/.config/hypr/black.png
    }
  '';
  variables.ewwSidebarFontSize = "24px";
  variables.ewwSidebarIconSize = "32";
  variables.ewwSidebarScreens = [
    "eDP-1"
    "DP-1"
  ];
  variables.touchscreen = {
    enable = true;
    enableHyprgrass = true;
    enableScroll = true;
    onScreenKeyboard = true;
    hyprgrassBinds = [
      ",tap:3,exec,${config.home.homeDirectory}/.config/hypr/three-finger-double-tap.sh"
    ];
  };
  wayland.windowManager.hyprland.settings = {
    monitor = [
      {
        output = "eDP-1";
        mode = "2560x1600@180";
        position = "0x0";
        scale = 1.25;
      }
      {
        output = "DP-1";
        mode = "1920x1080@120";
        # XReal glasses, 2048=2560/1.25
        position = "2048x0";
        scale = 1;
      }
    ];

    bind = [
      {
        _args = [
          (lib.generators.mkLuaInline "mod .. \" + F2\"")
          (xrealLua "toggle")
        ];
      }
    ];

    on = [
      {
        _args = [
          "hyprland.start"
          (lib.generators.mkLuaInline ''
            function()
              hl.exec_cmd("steam -silent")
              _G.oasis_xreal_glasses_only = false
            end
          '')
        ];
      }
      {
        _args = [
          "monitor.added"
          (xrealLua "sync")
        ];
      }
      {
        _args = [
          "monitor.removed"
          (xrealLua "sync")
        ];
      }
    ];
  };

  imports = [
    ../../../home/common-linux.nix
    ../../../home/apps/touchscreen.nix
    ./fastfetch.nix
  ];

  # custom full remapped keyboard
  wayland.windowManager.hyprland.settings.config.input = {
    kb_layout = "custom";
    kb_variant = "dvorak-custom";
  };

  home.file.".config/hypr/three-finger-double-tap.sh" = {
    executable = true;
    text = ''
      #!/usr/bin/env sh
      set -eu

      STATE_FILE="''${XDG_RUNTIME_DIR:-/tmp}/hyprgrass-3tap"
      LOCK_FILE="''${XDG_RUNTIME_DIR:-/tmp}/hyprgrass-3tap.lock"
      exec 9>"$LOCK_FILE"
      ${pkgs.util-linux}/bin/flock 9

      now="$(${pkgs.coreutils}/bin/date +%s%3N)"
      min_delta=120
      max_delta=350
      action_cooldown=500
      last=0
      last_action=0

      if [ -f "$STATE_FILE" ]; then
        read -r last last_action < "$STATE_FILE" || true
      fi

      if [ "$((now - last_action))" -lt "$action_cooldown" ]; then
        exit 0
      fi

      delta=$((now - last))
      if [ "$delta" -ge "$min_delta" ] && [ "$delta" -le "$max_delta" ]; then
        printf '0 %s\n' "$now" > "$STATE_FILE"
        kitty >/dev/null 2>&1 &
        exit 0
      fi

      printf '%s %s\n' "$now" "$last_action" > "$STATE_FILE"
    '';
  };
}
