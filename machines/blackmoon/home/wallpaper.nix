{ config, lib, pkgs, skwdSuite, ... }:
let
  suite = skwdSuite;
  wallpaper = "${config.home.homeDirectory}/stuff/nix-config/untracked-assets/cat-in-the-swamp-moewalls-com.mp4";
  cacheDir = "${config.xdg.cacheHome}/skwd-wall-v2";
  configDir = "${config.xdg.configHome}/skwd-wall-v2";
  seed = pkgs.writeShellApplication {
    name = "blackmoon-skwd-config";
    runtimeInputs = [ pkgs.coreutils pkgs.jq ];
    text = ''
      umask 077
      mkdir -p ${lib.escapeShellArg configDir}
      settings=${lib.escapeShellArg "${configDir}/config.json"}
      if [[ -e "$settings" ]]; then
        # Keep the pre-migration configuration once; do not overwrite GUI choices
        # unrelated to the Nix-owned playback and theming policy.
        if [[ ! -e "$settings.before-nix" ]]; then
          cp -p "$settings" "$settings.before-nix"
        fi
      else
        printf '{}\n' > "$settings"
      fi
      tmp=$(mktemp "$settings.XXXXXX")
      trap 'rm -f "$tmp"' EXIT
      jq --arg directory ${lib.escapeShellArg "${config.home.homeDirectory}/stuff/nix-config/untracked-assets"} '
        . * {
          paths: {wallpaper: $directory, videoWallpaper: $directory},
          paper: {wallpaperLayer: "bottom", videoEngine: "default"},
          display: {fillMode: "fill"},
          wallpaperMute: true,
          restoreOnStartup: false,
          playback: {fullscreen: false, maximized: false},
          theme: {policy: "off"}
        }
      ' "$settings" > "$tmp"
      mv "$tmp" "$settings"
      # Upstream's default restore copies the last wallpaper to unassigned outputs.
      # This host owns DP-3 and DP-1; preserve their independent selections.
      outputs=${lib.escapeShellArg "${cacheDir}/outputs.json"}
      if [[ -f "$outputs" ]]; then
        [[ -e "$outputs.before-nix" ]] || cp -p "$outputs" "$outputs.before-nix"
        tmp=$(mktemp "$outputs.XXXXXX")
        jq 'with_entries(select(.key == "DP-3" or .key == "DP-1"))' "$outputs" > "$tmp"
        mv "$tmp" "$outputs"
      fi
    '';
  };
  runner = pkgs.writeShellApplication {
    name = "blackmoon-cat-wallpaper";
    runtimeInputs = [ suite pkgs.coreutils pkgs.jq config.wayland.windowManager.hyprland.package ];
    text = ''
      wallpaper=${lib.escapeShellArg wallpaper}
      # Start only when the existing asset and target output are available.
      until [[ -f "$wallpaper" ]] && hyprctl -j monitors 2>/dev/null | jq -e 'any(.[]; .name == "DP-3")' >/dev/null; do
        sleep 1
      done
      outputs=${lib.escapeShellArg "${cacheDir}/outputs.json"}
      skwd-walld &
      daemon_pid=$!
      trap 'kill "$daemon_pid" 2>/dev/null || true' EXIT
      trap 'exit 0' INT TERM
      ready=0
      for _ in $(seq 1 30); do
        kill -0 "$daemon_pid" 2>/dev/null || exit 1
        if skwd-helm current --json > "$RUNTIME_DIRECTORY/outputs.json" 2>/dev/null; then
          ready=1
          break
        fi
        sleep 1
      done
      [[ "$ready" == 1 ]] || exit 1
      # Restore each configured connected output, never the all-output fallback.
      # Snapshot before apply, since the daemon writes its output cache on apply.
      saved_outputs="{}"
      [[ ! -f "$outputs" ]] || saved_outputs=$(cat "$outputs")
      for output in DP-3 DP-1; do
        hyprctl -j monitors | jq -e --arg output "$output" 'any(.[]; .name == $output)' >/dev/null || continue
        selected=$(printf '%s' "$saved_outputs" | jq -r --arg output "$output" '.[$output] | if .type == "we" then "we:" + .we_id else .path // empty end')
        [[ -n "$selected" ]] || selected="$wallpaper"
        if ! skwd-helm apply "$selected" --output "$output" --mute; then
          skwd-helm apply "$wallpaper" --output "$output" --mute
        fi
        skwd-helm mute --output "$output"
      done
      previous=""
      while kill -0 "$daemon_pid" 2>/dev/null; do
        monitor=$(hyprctl -j monitors | jq -r '.[] | select(.name == "DP-3") | .id')
        state=resume
        if [[ ! -f "$wallpaper" || -z "$monitor" ]]; then
          # Restart cleans the whole renderer cgroup and waits, exposing Hyprpaper.
          exit 1
        fi
        if hyprctl -j clients | jq -e --argjson monitor "$monitor" '
          any(.[]; .mapped == true and .monitor == $monitor
            and ((.fullscreen // 0) != 0)
            and ((.class // "" | ascii_downcase) != "kitty")
            and ((.initialClass // "" | ascii_downcase) != "kitty"))
        ' >/dev/null; then
          state=pause
        fi
        # Skwd pauses decoding in place, avoiding a decoder restart every time.
        # The control API pauses both animated outputs; retain DP-3 fullscreen policy.
        if [[ "$state" != "$previous" ]]; then
          skwd-helm "$state"
          previous="$state"
        fi
        sleep 1
      done
      wait "$daemon_pid"
      exit 1
    '';
  };
in {
  home.packages = [ suite ];
  systemd.user.services.blackmoon-cat-wallpaper = {
    Unit = {
      Description = "Blackmoon Skwd animated wallpaper";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
      Conflicts = [ "skwd-walld.service" ];
    };
    Service = {
      Type = "exec";
      ExecStartPre = "${seed}/bin/blackmoon-skwd-config";
      ExecStart = "${runner}/bin/blackmoon-cat-wallpaper";
      RuntimeDirectory = "blackmoon-cat-wallpaper";
      KillMode = "control-group";
      TimeoutStopSec = "5s";
      Restart = "on-failure";
      RestartSec = "2s";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
