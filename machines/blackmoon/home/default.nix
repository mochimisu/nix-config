{ pkgs, ... }:
{
  variables.keyboardLayout = "dvorak";
  imports = [
    ../../../home/common-linux.nix
    ./conky.nix
  ];

  home.packages = with pkgs; [
    wlr-randr
    nvidia-vaapi-driver
  ];

  wayland.windowManager.hyprland.settings = {
    monitors = {
      monitor = [
        "DP-1,2560x1440@120,-2560x0,1"
        "DP-3,3440x1440@175,0x0,1"
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
          "workspace 2 silent, class:^(vesktop)$"
        ];
      };
    };

    input = {
      kb_layout = "us";
      kb_variant = "dvorak";
    };

    "exec-once" = [
      "vesktop"
      # set DP-1 as primary
      "wlr-randr --output DP-1 --primary"
      # todo moon profile
      "openrgb --profile /home/brandon/.config/OpenRGB/moon.orp"
    ];

    # nvidia stuff, move to shared
    nvidia = {
      env = [
        "LIBVA_DRIVER_NAME,nvidia"
        "XDG_SESSION_TYPE,wayland"
        "GBM_BACKEND,nvidia-drm"
        "__GLX_VENDOR_LIBRARY_NAME,nvidia"
        "NVD_BACKEND,direct"
        "NIXOS_OZONE_WL=1"
      ];
    };

    debug = {
      # whole screen is re-rendered every frame, but reduces flickering
      damage_tracking = 0;
    };

    opengl = {
      nvidia_anti_flicker = 0;
      force_introspection = 2;
    };
    render = {
      # both needed to be disabled to prevent stutter frames in ff14
      explicit_sync = 0;
      explicit_sync_kms = 0;
    };
    misc = {
      # potentially reducing flicker in electron apps
      # vrr = "0";
      # vfr = "0" means every single frame is rendered, not great
      # but allows nvidia_anti_flicker to be set to 0
      vfr = 0;
    };
    cursor = {
      default_monitor = "DP-1";
    };
    bind = [
      "$mod, F2, exec, ~/.config/hypr/gamemode2.sh"
    ];
  };
  home.file.".config/hypr/gamemode2.sh" = {
    executable = true;
    text = ''
  HYPRGAMEMODE=$(hyprctl getoption animations:enabled | awk 'NR==1{print $2}')
  if [ "$HYPRGAMEMODE" = 1 ] ; then
      hyprctl --batch "\
          keyword animations:enabled 0;\
          keyword decoration:drop_shadow 0;\
          keyword decoration:blur:enabled 0;\
          keyword general:gaps_in 0;\
          keyword general:gaps_out 0;\
          keyword general:border_size 1;\
          keyword decoration:rounding 0;\
          keyword monitor DP-1,2560x1440@120,-3000x0,1;\
          keyword monitor DP-3,3440x1440@175,0x0,1;\
          keyword monitor HDMI-A-1,480x1920@60,4000x1200,2,transform,1"
      exit
  fi
  hyprctl reload
  '';
  };
    
}
