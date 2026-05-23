{lib, ...}: let
  lua = lib.generators.mkLuaInline;
in {
  wayland.windowManager.hyprland.settings = {
    bind = [
      # Switch workspaces with mod + [0-9]
      {_args = [(lua "mod .. \" + 1\"") (lua "hl.dsp.focus({ workspace = 1 })")];}
      {_args = [(lua "mod .. \" + 2\"") (lua "hl.dsp.focus({ workspace = 2 })")];}
      {_args = [(lua "mod .. \" + 3\"") (lua "hl.dsp.focus({ workspace = 3 })")];}
      {_args = [(lua "mod .. \" + 4\"") (lua "hl.dsp.focus({ workspace = 4 })")];}
      {_args = [(lua "mod .. \" + 5\"") (lua "hl.dsp.focus({ workspace = 5 })")];}
      {_args = [(lua "mod .. \" + 6\"") (lua "hl.dsp.focus({ workspace = 6 })")];}
      {_args = [(lua "mod .. \" + 7\"") (lua "hl.dsp.focus({ workspace = 7 })")];}
      {_args = [(lua "mod .. \" + 8\"") (lua "hl.dsp.focus({ workspace = 8 })")];}
      {_args = [(lua "mod .. \" + 9\"") (lua "hl.dsp.focus({ workspace = 9 })")];}
      {_args = [(lua "mod .. \" + 0\"") (lua "hl.dsp.focus({ workspace = 10 })")];}

      # Move active window to a workspace with mod + SHIFT + [0-9]
      {_args = [(lua "mod .. \" + SHIFT + 1\"") (lua "hl.dsp.window.move({ workspace = 1 })")];}
      {_args = [(lua "mod .. \" + SHIFT + 2\"") (lua "hl.dsp.window.move({ workspace = 2 })")];}
      {_args = [(lua "mod .. \" + SHIFT + 3\"") (lua "hl.dsp.window.move({ workspace = 3 })")];}
      {_args = [(lua "mod .. \" + SHIFT + 4\"") (lua "hl.dsp.window.move({ workspace = 4 })")];}
      {_args = [(lua "mod .. \" + SHIFT + 5\"") (lua "hl.dsp.window.move({ workspace = 5 })")];}
      {_args = [(lua "mod .. \" + SHIFT + 6\"") (lua "hl.dsp.window.move({ workspace = 6 })")];}
      {_args = [(lua "mod .. \" + SHIFT + 7\"") (lua "hl.dsp.window.move({ workspace = 7 })")];}
      {_args = [(lua "mod .. \" + SHIFT + 8\"") (lua "hl.dsp.window.move({ workspace = 8 })")];}
      {_args = [(lua "mod .. \" + SHIFT + 9\"") (lua "hl.dsp.window.move({ workspace = 9 })")];}
      {_args = [(lua "mod .. \" + SHIFT + 0\"") (lua "hl.dsp.window.move({ workspace = 10 })")];}
      {_args = [(lua "mod .. \" + CONTROL + 4\"") (lua "hl.dsp.exec_cmd(\"~/.config/hypr/screenshot.sh\")")];}
      {_args = [(lua "mod .. \" + F4\"") (lua "hl.dsp.exec_cmd(\"~/.config/hypr/screenshot.sh\")")];}

      # Example special workspace (scratchpad)
      {_args = [(lua "mod .. \" + S\"") (lua "hl.dsp.workspace.toggle_special(\"magic\")")];}
      {_args = [(lua "mod .. \" + SHIFT + S\"") (lua "hl.dsp.window.move({ workspace = \"special:magic\" })")];}

      {_args = [(lua "mod .. \" + mouse_down\"") (lua "hl.dsp.focus({ workspace = \"e+1\" })")];}
      {_args = [(lua "mod .. \" + mouse_up\"") (lua "hl.dsp.focus({ workspace = \"e-1\" })")];}
      {_args = ["SHIFT + mouse_down" (lua "hl.dsp.focus({ direction = \"down\" })")];}
      {_args = ["SHIFT + mouse_up" (lua "hl.dsp.focus({ direction = \"up\" })")];}
      {_args = [(lua "mod .. \" + SHIFT + mouse_down\"") (lua "hl.dsp.window.move({ direction = \"down\" })")];}
      {_args = [(lua "mod .. \" + SHIFT + mouse_up\"") (lua "hl.dsp.window.move({ direction = \"up\" })")];}

      # fullscreen toggle
      {_args = [(lua "mod .. \" + return\"") (lua "hl.dsp.window.fullscreen()")];}

      # float
      {_args = [(lua "mod .. \" + f\"") (lua "hl.dsp.window.float({ action = \"toggle\" })")];}

      #lock
      {_args = [(lua "mod .. \" + L\"") (lua "hl.dsp.exec_cmd(\"hyprlock\")")];}

      # launcher
      {_args = [(lua "mod .. \" + space\"") (lua "hl.dsp.exec_cmd(menu)")];}
      {_args = [(lua "mod .. \" + SHIFT + space\"") (lua "hl.dsp.exec_cmd(menuAll)")];}

      # will switch to a submap called resize
      # bind = $mod CONTROL, R, submap, resize

      # will start a submap called "resize"
      # submap=resize

      # sets repeatable binds for resizing the active window
      # binde=,right,resizeactive,40 0
      # binde=,left,resizeactive,-40 0
      # binde=,up,resizeactive,0 -40
      # binde=,down,resizeactive,0 40

      # use reset to go back to the global submap
      # bind=,escape,submap,reset

      # will reset the submap, meaning end the current one and return to the global one
      # submap=reset

      # keybinds further down will be global again...

      {_args = [(lua "mod .. \" + F1\"") (lua "hl.dsp.exec_cmd(\"~/.config/hypr/gamemode.sh\")")];}
      {_args = [(lua "mod .. \" + F5\"") (lua "hl.dsp.exec_cmd(\"~/.config/hypr/keyboard-toggle.sh\")")];}

      {_args = ["XF86MonBrightnessDown" (lua "hl.dsp.exec_cmd(\"brightnessctl set 5%-\")")];}
      {_args = ["XF86MonBrightnessUp" (lua "hl.dsp.exec_cmd(\"brightnessctl set +5%\")")];}
      {_args = ["XF86AudioLowerVolume" (lua "hl.dsp.exec_cmd(\"wpctl set-volume @DEFAULT_SINK@ 5%-\")")];}
      {_args = ["XF86AudioRaiseVolume" (lua "hl.dsp.exec_cmd(\"wpctl set-volume @DEFAULT_SINK@ 5%+\")")];}
      {_args = ["XF86AudioMute" (lua "hl.dsp.exec_cmd(\"wpctl set-mute @DEFAULT_SINK@ toggle\")")];}
      {_args = ["XF86KbdLightOnOff" (lua "hl.dsp.exec_cmd('brightnessctl --device *kbd_backlight* set +1')")];}
      {_args = ["SHIFT + XF86KbdLightOnOff" (lua "hl.dsp.exec_cmd('brightnessctl --device *kbd_backlight* set 1-')")];}
      # Move/resize windows with mod + LMB/RMB and dragging
      {_args = [(lua "mod .. \" + mouse:272\"") (lua "hl.dsp.window.drag()") {mouse = true;}];}
      {_args = [(lua "mod .. \" + mouse:273\"") (lua "hl.dsp.window.resize()") {mouse = true;}];}
    ];
  };

  home.file.".config/hypr/gamemode.sh" = {
    executable = true;
    text = ''
      #!/usr/bin/env sh
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
          exit
      fi
      hyprctl reload
    '';
  };

  home.file.".config/hypr/screenshot.sh" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash

      dir="$HOME/screenshots"
      mkdir -p "$dir"

      geometry="$(slurp)" || exit 0

      timestamp="$(date +%Y-%m-%d_%H-%M-%S)"
      file="$dir/$timestamp.png"

      grim -g "$geometry" - | tee "$file" | wl-copy
    '';
  };

  home.file.".config/hypr/keyboard-toggle.sh" = {
    executable = true;
    text = ''
      #!/usr/bin/env sh
      set -eu

      state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/hypr"
      state_file="''${state_dir}/keyboard-toggle"
      mkdir -p "''${state_dir}"

      get_opt() {
        hyprctl getoption "$1" | awk 'NR==1 {
          if (match($0, /[=:] /)) { print substr($0, RSTART+RLENGTH); exit }
          print $2
        }'
      }

      trim() {
        printf '%s' "$1" | tr -d '[:space:]'
      }

      normalize_variant() {
        case "$1" in
          ""|"null"|"none")
            printf ","
            ;;
          *)
            printf "%s" "$1"
            ;;
        esac
      }

      current_layout="$(trim "$(get_opt input:kb_layout)")"
      current_variant="$(normalize_variant "$(trim "$(get_opt input:kb_variant)")")"

      qwerty_layout="us,us"
      qwerty_variant=","

      is_qwerty=0
      case "$current_layout" in
        us|us,us)
          case "$current_variant" in
            ""|",") is_qwerty=1 ;;
          esac
          ;;
      esac

      if [ "$is_qwerty" -eq 1 ]; then
        saved_layout=""
        saved_variant=""
        if [ -f "$state_file" ]; then
          saved_layout="$(awk -F= '/^layout=/{print $2}' "$state_file")"
          saved_variant="$(awk -F= '/^variant=/{print $2}' "$state_file")"
        fi

        if [ -z "$saved_layout" ]; then
          saved_layout="us,us"
          saved_variant="dvorak,"
        fi

        # Switch back to the saved layout/variant.
        hyprctl eval "hl.config({
          input = {
            kb_layout = \"''${saved_layout}\",
            kb_variant = \"''${saved_variant}\",
          },
        })"
      else
        printf 'layout=%s\nvariant=%s\n' "$current_layout" "$current_variant" > "$state_file"

        # Switch to qwerty; clear variant first to avoid mismatched custom variants.
        hyprctl eval "hl.config({
          input = {
            kb_variant = \"''${qwerty_variant}\",
            kb_layout = \"''${qwerty_layout}\",
          },
        })"
      fi
    '';
  };
}
