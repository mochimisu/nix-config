{
  variables.keyboardLayout = "dvorak";
  imports = [
    ../../home/common-linux.nix
  ];

  wayland.windowManager.hyprland.settings = {
    monitors = {
      monitor = [
        "DP-1,2560x1440@144,-2560x0,1"
        "DP-3,3440x1440@144,0x0,1"
        "HDMI-A-1,480x1920@60,3440x1200,2,transform,1"
      ];
      workspace = [
        "1, monitor:DP-3, default:true"
        "2, monitor:DP-1, default:true"
        "3, monitor:DP-3, default:true"
        "10, monitor:HDMI-A-1, default:true"
      ];
      defaultwindows = {
        windowrulev2 = [
          "workspace 2 silent, class:^(steam)$"
          "workspace 2 silent, class:^(discord)$"
        ];
      };
    };

    input = {
      kb_layout = "us";
      kb_variant = "dvorak";
    };

    "exec-once" = [
      "discord"
      "steam"
      # todo moon profile
      "openrgb --profile /home/brandon/.config/OpenRGB/moon.orp"
    ];
  };
}
