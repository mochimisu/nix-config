{
  pkgs,
  config,
  lib,
  ...
}: let
  moonWallpaper = builtins.fetchurl {
    url = "https://w.wallhaven.cc/full/l8/wallhaven-l8mlyy.jpg";
    sha256 = "sha256:1571r0sz1qfz9xdqqkbpzfx8wx22azrhmsmdj14km427qcyiiap6";
  };
  lua = lib.generators.mkLuaInline;
  catWallpaperPath = "${config.home.homeDirectory}/stuff/nix-config/untracked-assets/cat-in-the-swamp-moewalls-com.mp4";
  catWallpaperService = pkgs.writeShellScript "blackmoon-cat-wallpaper" ''
    set -eu

    wallpaper_pid=""

    stop_wallpaper() {
      if [ -n "$wallpaper_pid" ] && kill -0 "$wallpaper_pid" 2>/dev/null; then
        kill "$wallpaper_pid" 2>/dev/null || true
        i=0
        while [ "$i" -lt 20 ] && kill -0 "$wallpaper_pid" 2>/dev/null; do
          i=$((i + 1))
          ${pkgs.coreutils}/bin/sleep 0.1
        done
        if kill -0 "$wallpaper_pid" 2>/dev/null; then
          kill -KILL "$wallpaper_pid" 2>/dev/null || true
        fi
        wait "$wallpaper_pid" 2>/dev/null || true
      fi
      wallpaper_pid=""
    }

    start_wallpaper() {
      if [ -n "$wallpaper_pid" ] && kill -0 "$wallpaper_pid" 2>/dev/null; then
        return
      fi
      ${pkgs.mpvpaper}/bin/mpvpaper -l bottom -o "no-audio loop really-quiet panscan=1 hwdec=auto" DP-3 "${catWallpaperPath}" &
      wallpaper_pid="$!"
    }

    trap stop_wallpaper EXIT INT TERM

    i=0
    while true; do
      if [ -e "${catWallpaperPath}" ] && ${config.wayland.windowManager.hyprland.package}/bin/hyprctl monitors 2>/dev/null | ${pkgs.gnugrep}/bin/grep -q '^Monitor DP-3 '; then
        break
      fi
      i=$((i + 1))
      if [ "$i" -eq 1 ] || [ $((i % 30)) -eq 0 ]; then
        echo "waiting for DP-3 and ${catWallpaperPath}" >&2
      fi
      ${pkgs.coreutils}/bin/sleep 1
    done

    unavailable_count=0
    while true; do
      dp3_id="$(${config.wayland.windowManager.hyprland.package}/bin/hyprctl -j monitors | ${pkgs.jq}/bin/jq -r '.[] | select(.name == "DP-3") | .id' | ${pkgs.coreutils}/bin/head -n1)"
      if [ ! -e "${catWallpaperPath}" ] || [ -z "$dp3_id" ]; then
        stop_wallpaper
        unavailable_count=$((unavailable_count + 1))
        if [ "$unavailable_count" -eq 1 ] || [ $((unavailable_count % 30)) -eq 0 ]; then
          echo "waiting for DP-3 and ${catWallpaperPath}" >&2
        fi
        ${pkgs.coreutils}/bin/sleep 1
        continue
      fi
      unavailable_count=0

      fullscreen_on_dp3=0
      if ${config.wayland.windowManager.hyprland.package}/bin/hyprctl -j clients | ${pkgs.jq}/bin/jq -e --argjson monitor "$dp3_id" '
        any(.[]; .mapped == true and .monitor == $monitor and ((.fullscreen // 0) != 0))
      ' >/dev/null; then
        fullscreen_on_dp3=1
      fi

      if [ "$fullscreen_on_dp3" -eq 1 ]; then
        stop_wallpaper
      else
        start_wallpaper
      fi

      ${pkgs.coreutils}/bin/sleep 1
    done
  '';
in {
  variables.keyboardLayout = "dvorak";
  variables.hyprpanel = {
    hiddenMonitors = ["0"];
    cpuTempSensor = "/dev/highflow_next/temp1_input";
  };
  variables.ewwPttStateFile = "${config.home.homeDirectory}/.local/state/hypr-ptt/state";
  home.file.".config/hypr/moon.jpg".source = moonWallpaper;
  variables.hyprpaper-config = ''
    wallpaper {
      monitor = DP-3
      path = ${config.home.homeDirectory}/.config/hypr/moon.jpg
    }
  '';

  imports = [
    ../../../home/common-linux.nix
    ./eww-sysmon.nix
    ./fastfetch.nix
  ];

  home.packages = with pkgs; [
    wlr-randr
    nvidia-vaapi-driver
    mpvpaper
  ];

  programs.kitty.settings.auto_reload_config = -1;

  systemd.user.services.steam-autostart = {
    Unit = {
      Description = "Start Steam silently";
      After = ["graphical-session.target"];
      PartOf = ["graphical-session.target"];
    };

    Service = {
      Type = "exec";
      ExecStart = "/run/current-system/sw/bin/steam -silent";
    };

    Install.WantedBy = ["graphical-session.target"];
  };

  systemd.user.services.blackmoon-cat-wallpaper = {
    Unit = {
      Description = "Blackmoon animated cat wallpaper";
      After = ["hyprland-session.target"];
      PartOf = ["hyprland-session.target"];
    };

    Service = {
      Type = "exec";
      ExecStart = "${catWallpaperService}";
      Restart = "on-failure";
      RestartSec = "2s";
    };

    Install.WantedBy = ["hyprland-session.target"];
  };

  home.shellAliases = {
  };

  wayland.windowManager.hyprland.settings = {
    monitor = [
      {
        output = "DP-1";
        mode = "2560x1440@120";
        position = "3440x-560";
        scale = 1;
        transform = 1;
      }
      {
        output = "DP-3";
        mode = "3440x1440@175";
        position = "0x0";
        scale = 1;
      }
    ];

    workspace_rule = [
      {
        workspace = "1";
        monitor = "DP-3";
        default = true;
      }
      {
        workspace = "2";
        monitor = "DP-1";
        default = true;
      }
      {
        workspace = "3";
        monitor = "DP-3";
        default = true;
      }
    ];

    window_rule = [
      {
        name = "discord-workspace";
        match.class = "^(discord)$";
        workspace = "2 silent";
      }
      # Endfield's launcher sometimes restores stale XWayland coordinates off-screen.
      {
        name = "endfield-launcher-center";
        match = {
          class = "^(steam_app_.*)$";
          title = "^(GRYPHLINK)$";
        };
        center = true;
      }
      {
        name = "monster-hunter-render-unfocused";
        match.class = "^(Monster Hunter Wilds)$";
        render_unfocused = true;
      }
      {
        name = "ffxiv-monitor";
        match.class = "^(ffxiv_dx11.exe)$";
        monitor = "DP-3 tile";
      }
    ];

    config.input = {
      kb_layout = "us,us";
      kb_variant = "dvorak,";
    };

    on = [
      {
        _args = [
          "hyprland.start"
          (lua ''
            function()
              hl.exec_cmd("discord")
              hl.exec_cmd("wlr-randr --output DP-3 --primary")
              hl.exec_cmd("DISPLAY=:1 xrandr --output DP-3 --primary")
              hl.exec_cmd("openrgb --profile /home/brandon/.config/OpenRGB/moon.orp")
              hl.exec_cmd("~/.config/hypr/endfield-launcher-fix.sh")
            end
          '')
        ];
      }
    ];

    env = [
      # NVIDIA VA-API decode path.
      {_args = ["LIBVA_DRIVER_NAME" "nvidia"];}
      {_args = ["XDG_SESSION_TYPE" "wayland"];}
      # Force GBM NVIDIA backend for Wayland.
      {_args = ["GBM_BACKEND" "nvidia-drm"];}
      {_args = ["__GLX_VENDOR_LIBRARY_NAME" "nvidia"];}
      {_args = ["NVD_BACKEND" "direct"];}
      {_args = ["NIXOS_OZONE_WL" "1"];}
      # Enable HDR WSI path for Vulkan clients.
      {_args = ["ENABLE_HDR_WSI" "1"];}
      # Enable HDR metadata path for DXVK titles.
      {_args = ["DXVK_HDR" "1"];}
      # Enable HDR for vkd3d-proton (D3D12) titles.
      {_args = ["VKD3D_CONFIG" "hdr"];}
    ];

    config.opengl.nvidia_anti_flicker = 0;

    config.render = {
      # Enable color-management pipeline required for HDR output.
      cm_enabled = false;
      # Auto-enable HDR when the app advertises HDR output.
      cm_auto_hdr = 0;
    };

    config.misc = {
      # VRR can introduce microstutter on NVIDIA; disable to test.
      vrr = 0;
    };
    config.cursor = {
      default_monitor = "DP-3";
    };
    bind = [
      {_args = [(lua "mod .. \" + F2\"") (lua "hl.dsp.exec_cmd(\"~/.config/hypr/gamemode2.sh\")")];}
      {_args = [(lua "mod .. \" + F3\"") (lua "hl.dsp.exec_cmd(\"~/.config/hypr/toggle-ptt.sh\")")];}
      {_args = [(lua "mod .. \" + F6\"") (lua "hl.dsp.exec_cmd(\"~/.config/hypr/toggle-hdr.sh\")")];}
      {_args = ["mouse:275" (lua "hl.dsp.exec_cmd(\"~/.config/hypr/ptt-mouse.sh press\")")];}
      {_args = ["mouse:275" (lua "hl.dsp.exec_cmd(\"~/.config/hypr/ptt-mouse.sh release\")") {release = true;}];}
    ];
  };
  home.file.".config/hypr/gamemode2.sh" = {
    executable = true;
    text = ''
      HYPRGAMEMODE=$(hyprctl getoption animations:enabled | awk 'NR==1{print $2}')
      if [ "$HYPRGAMEMODE" = 1 ] ; then
          hyprctl eval 'hl.config({
            animations = { enabled = false },
            decoration = {
              blur = { enabled = false },
              rounding = 0,
              shadow = { enabled = false },
            },
            general = {
              border_size = 1,
              gaps_in = 0,
              gaps_out = 0,
            },
          })'
          hyprctl eval 'hl.monitor({ output = "DP-1", mode = "2560x1440@120", position = "3440x-560", scale = 1, transform = 1 })'
          hyprctl eval 'hl.monitor({ output = "DP-3", mode = "3440x1440@175", position = "0x0", scale = 1 })'
          exit
      fi
      hyprctl reload
    '';
  };
  home.file.".config/hypr/endfield-launcher-fix.sh" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      socket="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr/''${HYPRLAND_INSTANCE_SIGNATURE:?}/.socket2.sock"

      move_visible_launchers() {
        clients="$(hyprctl -j clients)"
        monitors="$(hyprctl -j monitors)"

        jq -r --argjson monitors "$monitors" '
          .[]
          | select((.class | startswith("steam_app_")) and .title == "GRYPHLINK")
          | . as $client
          | select(
              [
                $monitors[]
                | select(.disabled == false)
                | select(
                    .x <= $client.at[0]
                    and .y <= $client.at[1]
                    and (.x + .width) >= ($client.at[0] + $client.size[0])
                    and (.y + .height) >= ($client.at[1] + $client.size[1])
                  )
              ]
              | length == 0
            )
          | .address
        ' <<<"$clients" | while read -r addr; do
          [ -n "$addr" ] || continue
          # The launcher re-applies stale geometry a few times after mapping, so
          # keep forcing it back to the visible area briefly.
          for _ in $(seq 1 30); do
            hyprctl dispatch "hl.dsp.window.move({x = 100, y = 100, relative = false, window = \"address:$addr\"})" >/dev/null
            sleep 0.1
          done
        done
      }

      move_visible_launchers

      if ! command -v socat >/dev/null 2>&1; then
        while true; do
          move_visible_launchers
          sleep 1
        done
      fi

      socat -U - UNIX-CONNECT:"$socket" | while IFS= read -r _; do
        move_visible_launchers
      done
    '';
  };
  home.file.".local/bin/fix-endfield-launcher" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      addr="$(
        hyprctl -j clients |
          jq -r '
            .[]
            | select((.class | startswith("steam_app_")) and .title == "GRYPHLINK")
            | .address
          ' |
          tail -n 1
      )"

      if [ -z "$addr" ]; then
        echo "No GRYPHLINK window found." >&2
        exit 1
      fi

      for _ in $(seq 1 30); do
        hyprctl dispatch "hl.dsp.window.move({x = 100, y = 100, relative = false, window = \"address:$addr\"})" >/dev/null
        sleep 0.1
      done
    '';
  };

  home.file.".config/hypr/toggle-hdr.sh" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      state_file="''${XDG_STATE_HOME:-$HOME/.local/state}/hypr/hdr-enabled"
      mkdir -p "''${state_file%/*}"

      cm_enabled=$(hyprctl getoption render:cm_enabled | awk 'NR==1{print $2}')
      monitor_cm=$(
        hyprctl -j monitors |
          jq -r '.[] | select(.name == "DP-3") | .colorManagementPreset // "unknown"' |
          tail -n 1
      )

      if [ "$monitor_cm" = "hdr" ] || [ "''${cm_enabled:-0}" = "1" ]; then
        printf "0" > "$state_file"
        hyprctl eval 'hl.config({ render = { cm_enabled = false, cm_auto_hdr = 0 } })'
        hyprctl eval 'hl.monitor({
          output = "DP-3",
          mode = "3440x1440@175",
          position = "0x0",
          scale = 1,
        })'
      else
        printf "1" > "$state_file"
        hyprctl eval 'hl.config({ render = { cm_enabled = true, cm_auto_hdr = 0 } })'
        hyprctl eval 'hl.monitor({
          output = "DP-3",
          mode = "3440x1440@175",
          position = "0x0",
          scale = 1,
          bitdepth = 10,
          cm = "hdr",
          sdrbrightness = 1.20,
        })'
      fi
    '';
  };
  home.file.".config/hypr/ptt-mouse.sh" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      state_file="''${XDG_STATE_HOME:-$HOME/.local/state}/hypr-ptt/state"

      state="enabled"
      if [ -f "$state_file" ]; then
        state=$(tr -d '[:space:]' <"$state_file")
      fi

      if [ "$state" != "enabled" ]; then
        exit 0
      fi

      case "''${1:-}" in
        press)
          pactl set-source-mute @DEFAULT_SOURCE@ 0
          ;;
        release)
          pactl set-source-mute @DEFAULT_SOURCE@ 1
          ;;
      esac
    '';
  };
  home.file.".config/hypr/toggle-ptt.sh" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      state_file="''${XDG_STATE_HOME:-$HOME/.local/state}/hypr-ptt/state"
      mkdir -p "$(dirname "$state_file")"

      current="enabled"
      if [ -f "$state_file" ]; then
        current=$(tr -d '[:space:]' <"$state_file")
      fi

      if [ "$current" = "enabled" ]; then
        echo "disabled" >"$state_file"
        pactl set-source-mute @DEFAULT_SOURCE@ 0
      else
        echo "enabled" >"$state_file"
      fi
    '';
  };

  # additional waybar modules
  variables.waybarModulesLeft = [
    "temperature#gpu"
    "temperature#water"
  ];
  variables.waybarSettings = {
    "temperature#gpu" = {
      "hwmon-path-abs" = "/sys/devices/pci0000:00/0000:00:1d.0/0000:72:00.0/nvme/nvme1";
      "input-filename" = "temp1_input";
      "critical-threshold" = 80;
      "format-critical" = "{temperatureC}°C {icon}";
      format = "{temperatureC}°C {icon}";
      "format-icons" = ["🖥"];
    };

    "temperature#water" = {
      "hwmon-path-abs" = "/sys/devices/pci0000:00/0000:00:14.0/usb1/1-10/1-10.2/1-10.2.4/1-10.2.4:1.1/0003:0C70:F012.000B/hwmon";
      "input-filename" = "temp1_input";
      "critical-threshold" = 40;
      "format-critical" = "{temperatureC}°C {icon}";
      format = "{temperatureC}°C {icon}";
      "format-icons" = ["󰖌"];
    };
  };
  variables.waybarBattery = "ps-controller-battery-58:10:31:1d:a2:43";

  # eww sidebar settings
  variables.ewwSidebarScreens = [
    "DP-3"
    "DP-1"
  ];

  # dunst/mako settings, show on DP-1
  services.dunst.settings.global = {
    monitor = "DP-1";
    follow = lib.mkForce "none";
  };
  services.mako.settings = {
    output = "DP-1";
  };
}
