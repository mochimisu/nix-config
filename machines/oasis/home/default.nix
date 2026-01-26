{
  config,
  pkgs,
  inputs,
  ...
}: {
  variables.keyboardLayout = "dvorak";
  variables.hyprpanel = {
    cpuTempSensor = "/sys/devices/pci0000:00/0000:00:08.1/0000:c4:00.0/hwmon/hwmon9/temp1_input";
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
  wayland.windowManager.hyprland.settings = {
    monitors = {
      monitor = [
        "eDP-1,2560x1600@180,0x0,1.25"
        # XReal glasses, 2048=2560/1.25
        "DP-1,1920x1080@120,2048x0,1"
      ];
    };

    bind = [
      "$mod, F2, exec, ~/.config/hypr/xreal-toggle.sh"
    ];

    "exec-once" = [
      "mangohud steam -silent"
      "iio-hyprland"
      "protonvpn-app"
    ];
    plugin = {
      touch_gestures = {
        hyprgrass-bind = [
          ",swipe:4:u,exec,wvkbd-mobintl -L 300"
          ",swipe:4:d,exec,pkill wvkbd-mobintl"
        ];
      };
    };
  };

  wayland.windowManager.hyprland.plugins = [
    inputs.hyprgrass.packages.${pkgs.system}.default
  ];

  wayland.windowManager.hyprland.extraConfig = ''
    plugin = ${inputs.hyprgrass.packages.${pkgs.system}.default}/lib/libhyprgrass.so
  '';

  imports = [
    ../../../home/common-linux.nix
    ./fastfetch.nix
  ];

  home.sessionVariables = {
    YDOTOOL_SOCKET = "/run/ydotoold.socket";
  };

  home.packages = with pkgs; [
    lisgd
  ];

  systemd.user.services.lisgd = {
    Unit = {
      Description = "lisgd touchscreen gesture daemon";
      After = ["graphical-session.target"];
    };
    Service = {
      Environment = "YDOTOOL_SOCKET=/run/ydotoold.socket";
      ExecStart = "${pkgs.lisgd}/bin/lisgd -d /dev/input/touchscreen -t 60 -T 20 -m 1200 -r 20 -g \"1,DU,*,*,P,ydotool mousemove --wheel -- 0 -1\" -g \"1,UD,*,*,P,ydotool mousemove --wheel -- 0 1\"";
      Restart = "on-failure";
    };
    Install = {
      WantedBy = ["graphical-session.target"];
    };
  };


  # custom full remapped keyboard
  wayland.windowManager.hyprland.settings.input = {
    kb_layout = "custom";
    kb_variant = "dvorak-custom";
  };

  home.file.".config/hypr/xreal-toggle.sh" = {
    executable = true;
    text = ''
      #!/usr/bin/env sh
      set -eu

      STATE_FILE="''${XDG_RUNTIME_DIR:-/tmp}/xreal-main-active"

      if [ -f "''${STATE_FILE}" ]; then
        hyprctl --batch "keyword monitor eDP-1,2560x1600@180,0x0,1.25; keyword monitor DP-1,1920x1080@120,2048x0,1"
        rm -f "''${STATE_FILE}"
        exit 0
      fi

      hyprctl --batch "keyword monitor DP-1,1920x1080@120,0x0,1; keyword monitor eDP-1,2560x1600@180,1920x0,1.25"
      touch "''${STATE_FILE}"
    '';
  };
}
