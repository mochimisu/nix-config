{ config, inputs, lib, pkgs, ... }:
let
  touchscreenVars = if builtins.hasAttr "touchscreen" config.variables then config.variables.touchscreen else {};
  enable = touchscreenVars.enable or false;
  enableScroll = touchscreenVars.enableScroll or true;
  onScreenKeyboard = touchscreenVars.onScreenKeyboard or false;
  enableHyprgrass = touchscreenVars.enableHyprgrass or onScreenKeyboard;
  lisgdDevice = touchscreenVars.device or "/dev/input/touchscreen";
  ydotoolSocket = touchscreenVars.ydotoolSocket or "/run/ydotoold.socket";
  hyprgrassBinds = (touchscreenVars.hyprgrassBinds or [])
    ++ lib.optionals onScreenKeyboard [
      ",swipe:4:u,exec,wvkbd-mobintl -L 300"
      ",swipe:4:d,exec,pkill wvkbd-mobintl"
    ];
  enableHyprgrassBinds = enableHyprgrass && hyprgrassBinds != [];
  lisgdScrollCmd = "${pkgs.ydotool}/bin/ydotool mousemove --wheel -- 0";
  lisgdScrollUp = "1,DU,*,*,P,${lisgdScrollCmd} -1";
  lisgdScrollDown = "1,UD,*,*,P,${lisgdScrollCmd} 1";
  lisgdCommand = "${pkgs.lisgd}/bin/lisgd -d ${lisgdDevice} -t 60 -T 20 -m 1200 -r 20 -g \"${lisgdScrollUp}\" -g \"${lisgdScrollDown}\"";
in {
  config = lib.mkIf (pkgs.stdenv.isLinux && enable) (lib.mkMerge [
    {
      home.sessionVariables = lib.mkIf enableScroll {
        YDOTOOL_SOCKET = ydotoolSocket;
      };

      home.packages = lib.optionals enableScroll [
        pkgs.lisgd
      ];

      systemd.user.services.lisgd = lib.mkIf enableScroll {
        Unit = {
          Description = "lisgd touchscreen gesture daemon";
          After = ["graphical-session.target"];
        };
        Service = {
          Environment = "YDOTOOL_SOCKET=${ydotoolSocket}";
          ExecStart = lisgdCommand;
          Restart = "on-failure";
        };
        Install = {
          WantedBy = ["graphical-session.target"];
        };
      };
    }
    (lib.mkIf enableHyprgrass {
      wayland.windowManager.hyprland.plugins = [
        inputs.hyprgrass.packages.${pkgs.system}.default
      ];

      wayland.windowManager.hyprland.extraConfig = ''
        plugin = ${inputs.hyprgrass.packages.${pkgs.system}.default}/lib/libhyprgrass.so
      '';
    })
    (lib.mkIf enableHyprgrassBinds {
      wayland.windowManager.hyprland.settings.plugin.touch_gestures.hyprgrass-bind = hyprgrassBinds;
    })
  ]);
}
