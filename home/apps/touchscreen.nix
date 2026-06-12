{ config, lib, pkgs, ... }:
let
  touchscreenVars = if builtins.hasAttr "touchscreen" config.variables then config.variables.touchscreen else {};
  enable = touchscreenVars.enable or false;
  enableScroll = touchscreenVars.enableScroll or true;
  onScreenKeyboard = touchscreenVars.onScreenKeyboard or false;
  enableHyprgrass = touchscreenVars.enableHyprgrass or onScreenKeyboard;
  enableHyprgrassWorkspaceSwipe = touchscreenVars.enableHyprgrassWorkspaceSwipe or true;
  lisgdDevice = touchscreenVars.device or "/dev/input/touchscreen";
  ydotoolSocket = touchscreenVars.ydotoolSocket or "/run/ydotoold.socket";
  defaultHyprgrassBinds = [
    ",swipe:3:u,togglefloating"
    ",swipe:3:d,fullscreen,1"
    ",longpress:4,killactive"
  ];
  hyprgrassBinds = defaultHyprgrassBinds
    ++ (touchscreenVars.hyprgrassBinds or [])
    ++ lib.optionals onScreenKeyboard [
      ",swipe:4:u,exec,${wvkbdStartScript}"
      ",swipe:4:d,exec,${wvkbdStopScript}"
    ];
  hyprgrassBindm = touchscreenVars.hyprgrassBindm or [
    ",longpress:2,movewindow"
    ",longpress:3,resizewindow"
  ];
  enableHyprgrassBinds = enableHyprgrass && hyprgrassBinds != [];
  enableHyprgrassBindm = enableHyprgrass && hyprgrassBindm != [];
  enableHyprgrassWorkspaceGestures = enableHyprgrass && enableHyprgrassWorkspaceSwipe;
  enableHyprgrassLuaConfig = enableHyprgrassBinds || enableHyprgrassBindm || enableHyprgrassWorkspaceGestures;
  hyprgrassPackage = pkgs.hyprlandPlugins.hyprgrass;
  hyprgrassPluginPath = "${hyprgrassPackage}/lib/libhyprgrass.so";
  wvkbdStartScript = "${config.home.homeDirectory}/.config/hypr/wvkbd-mobintl-start.sh";
  wvkbdStopScript = "${config.home.homeDirectory}/.config/hypr/wvkbd-mobintl-stop.sh";
  splitCsv = value: lib.splitString "," value;
  luaString = builtins.toJSON;
  hyprgrassDirectionToLua = direction:
    luaString ({
      l = "left";
      r = "right";
      u = "up";
      d = "down";
      i = "pinchin";
      o = "pinchout";
    }.${direction} or direction);
  hyprgrassPatternToLua = gesture: let
    parts = lib.splitString ":" gesture;
    kind = lib.elemAt parts 0;
  in
    if kind == "swipe"
    then "{ kind = \"swipe\", fingers = ${lib.elemAt parts 1}, direction = ${hyprgrassDirectionToLua (lib.elemAt parts 2)} }"
    else if kind == "edge"
    then "{ kind = \"edge\", origin = ${hyprgrassDirectionToLua (lib.elemAt parts 1)}, direction = ${hyprgrassDirectionToLua (lib.elemAt parts 2)} }"
    else if kind == "longpress"
    then "{ kind = \"longpress\", fingers = ${lib.elemAt parts 1} }"
    else if kind == "tap"
    then "{ kind = \"tap\", fingers = ${lib.elemAt parts 1} }"
    else if kind == "pinch"
    then "{ kind = \"pinch\", fingers = ${lib.elemAt parts 1}, direction = ${hyprgrassDirectionToLua (lib.elemAt parts 2)} }"
    else luaString gesture;
  hyprlandDispatcherToLua = dispatcher: arg:
    if dispatcher == "exec"
    then "hl.dsp.exec_cmd(${luaString arg})"
    else if dispatcher == "togglefloating"
    then "hl.dsp.window.float({ action = \"toggle\" })"
    else if dispatcher == "fullscreen"
    then "hl.dsp.window.fullscreen()"
    else if dispatcher == "killactive"
    then "hl.dsp.window.close()"
    else "hl.dsp.exec_cmd(${luaString "hyprctl dispatch ${dispatcher}${lib.optionalString (arg != "") " ${arg}"}"})";
  hyprgrassBindToLua = value: let
    parts = splitCsv value;
    mod = lib.elemAt parts 0;
    gesture = lib.elemAt parts 1;
    dispatcher = lib.elemAt parts 2;
    arg = lib.concatStringsSep "," (lib.drop 3 parts);
    action = hyprlandDispatcherToLua dispatcher arg;
  in ''
    hl.plugin.hyprgrass.bind {
      pattern = ${hyprgrassPatternToLua gesture},
      ${lib.optionalString (mod != "") "mod = ${luaString mod},"}
      action = ${action},
    }
  '';
  hyprgrassBindmToLua = value: let
    parts = splitCsv value;
    mod = lib.elemAt parts 0;
    gesture = lib.elemAt parts 1;
    dispatcher = lib.elemAt parts 2;
    action =
      if dispatcher == "movewindow"
      then "hl.dsp.window.drag()"
      else if dispatcher == "resizewindow"
      then "hl.dsp.window.resize()"
      else "function() hl.exec_cmd(${luaString "hyprctl dispatch ${dispatcher}"}) end";
  in ''
    hl.plugin.hyprgrass.bind {
      pattern = ${hyprgrassPatternToLua gesture},
      ${lib.optionalString (mod != "") "mod = ${luaString mod},"}
      action = ${action},
      mouse = true,
    }
  '';
  hyprgrassLuaConfig = ''
    -- Hyprgrass Lua API.
    hl.plugin.load(${luaString hyprgrassPluginPath})

    if hl.plugin and hl.plugin.hyprgrass and hl.plugin.hyprgrass.bind then
    ${lib.concatMapStrings hyprgrassBindToLua hyprgrassBinds}
    ${lib.concatMapStrings hyprgrassBindmToLua hyprgrassBindm}
    end

    ${lib.optionalString enableHyprgrassWorkspaceGestures ''
      if hl.plugin and hl.plugin.hyprgrass and hl.plugin.hyprgrass.gesture then
        hl.plugin.hyprgrass.gesture {
          pattern = { kind = "swipe", fingers = 3, direction = "horizontal" },
          action = "workspace",
        }
      end
    ''}
  '';
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

      home.file.".config/hypr/wvkbd-mobintl-start.sh" = lib.mkIf onScreenKeyboard {
        executable = true;
        text = ''
          #!/usr/bin/env sh
          set -eu

          lock="''${XDG_RUNTIME_DIR:-/tmp}/wvkbd-mobintl.lock"
          ${pkgs.util-linux}/bin/flock -n "$lock" sh -c '
            ${pkgs.procps}/bin/pgrep -x wvkbd-mobintl >/dev/null && exit 0
            exec ${pkgs.wvkbd}/bin/wvkbd-mobintl -H 600 -L 600
          '
        '';
      };

      home.file.".config/hypr/wvkbd-mobintl-stop.sh" = lib.mkIf onScreenKeyboard {
        executable = true;
        text = ''
          #!/usr/bin/env sh
          set -eu

          ${pkgs.procps}/bin/pkill -x wvkbd-mobintl || true
        '';
      };
    }
    (lib.mkIf enableHyprgrassLuaConfig {
      wayland.windowManager.hyprland.extraConfig = hyprgrassLuaConfig;
    })
  ]);
}
