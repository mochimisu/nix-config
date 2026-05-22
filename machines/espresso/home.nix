{
  lib,
  ...
}: {
  variables.keyboardLayout = "qwerty";
  variables.hyprpanel = {
    cpuTempSensor = "/sys/devices/pci0000:00/0000:00:08.1/0000:63:00.0/hwmon/hwmon6/temp1_input";
  };
  variables.ewwSidebarFontSize = "18px";
  variables.ewwSidebarIconSize = "24";
  variables.touchscreen = {
    enable = true;
    enableHyprgrass = true;
    enableScroll = true;
    onScreenKeyboard = false;
  };
  wayland.windowManager.hyprland.settings = {
    monitor = [
      {
        output = "eDP-1";
        mode = "preferred";
        position = "0x0";
        scale = 1.6;
        transform = 3;
      }
    ];
    config.input = {
      touchdevice = {
        transform = 3;
      };
    };
    on = [
      {
        _args = [
          "hyprland.start"
          (lib.generators.mkLuaInline ''
            function()
              hl.exec_cmd("mangohud steam")
            end
          '')
        ];
      }
    ];
    gesture = [
      {
        fingers = 3;
        direction = "left";
        action = lib.generators.mkLuaInline ''function() hl.dispatch(hl.dsp.focus({ workspace = "e-1" })) end'';
      }
      {
        fingers = 3;
        direction = "right";
        action = lib.generators.mkLuaInline ''function() hl.dispatch(hl.dsp.focus({ workspace = "e+1" })) end'';
      }
    ];
  };
  imports = [
    ../../home/common-linux.nix
    ../../home/apps/touchscreen.nix
  ];
  home.shellAliases = {
  };
}
