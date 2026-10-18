{ config, lib, pkgs, skwdSuite, ... }:
let
  suite = skwdSuite;
  wallpaper = "${config.home.homeDirectory}/stuff/nix-config/untracked-assets/snowfall-in-forest-motionbgs-4k.mp4";
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
      # Seed both outputs from declared policy, never from mutable picker history.
      mkdir -p ${lib.escapeShellArg cacheDir}
      outputs=${lib.escapeShellArg "${cacheDir}/outputs.json"}
      tmp=$(mktemp "$outputs.XXXXXX")
      jq -n --arg path ${lib.escapeShellArg wallpaper} '
        {"DP-3": {type: "video", path: $path, mute: true, volume: 100, we_id: ""},
         "DP-1": {type: "video", path: $path, mute: true, volume: 100, we_id: ""}}
      ' > "$tmp"
      mv "$tmp" "$outputs"
    '';
  };
  runner = pkgs.writeShellApplication {
    name = "blackmoon-wallpaper";
    runtimeInputs = [ suite pkgs.coreutils pkgs.jq config.wayland.windowManager.hyprland.package ];
    text = ''
      wallpaper=${lib.escapeShellArg wallpaper}
      # Media remains local runtime state; missing media exposes Hyprpaper.
      until [[ -f "$wallpaper" ]]; do sleep 1; done
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
      declare -A restored=()
      previous=""
      while kill -0 "$daemon_pid" 2>/dev/null; do
        [[ -f "$wallpaper" ]] || exit 1
        # Output disappearance is normal (sleep/hotplug), not a daemon failure.
        # Reconcile both returning outputs and stale picker/cache selections.
        if ! monitors=$(hyprctl -j monitors) || ! current=$(skwd-helm current --json); then
          sleep 1
          continue
        fi
        for output in DP-3 DP-1; do
          if ! jq -e --arg output "$output" 'any(.[]; .name == $output)' <<< "$monitors" >/dev/null; then
            unset 'restored[$output]'
            continue
          fi
          if [[ -z "''${restored[$output]:-}" ]] || ! jq -e --arg output "$output" --arg path "$wallpaper" '
            any(.outputs[]; .name == $output and .path == $path and .type == "video" and .mute == true)
          ' <<< "$current" >/dev/null; then
            # A disconnect during apply is retried after the next output query.
            skwd-helm apply "$wallpaper" --output "$output" --mute || continue
            restored[$output]=1
            previous=""
          fi
        done
        monitor=$(jq -r '.[] | select(.name == "DP-3") | .id' <<< "$monitors")
        state=resume
        if [[ -n "$monitor" ]] && hyprctl -j clients | jq -e --argjson monitor "$monitor" '
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
          if skwd-helm "$state"; then previous="$state"; fi
        fi
        sleep 1
      done
      wait "$daemon_pid"
      exit 1
    '';
  };
in {
  home.packages = [ suite ];
  systemd.user.services.blackmoon-wallpaper = {
    Unit = {
      Description = "Blackmoon Skwd animated wallpaper";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
      Conflicts = [ "skwd-walld.service" "blackmoon-cat-wallpaper.service" ];
    };
    Service = {
      Type = "exec";
      ExecStartPre = "${seed}/bin/blackmoon-skwd-config";
      ExecStart = "${runner}/bin/blackmoon-wallpaper";
      RuntimeDirectory = "blackmoon-wallpaper";
      KillMode = "control-group";
      TimeoutStopSec = "5s";
      Restart = "on-failure";
      RestartSec = "2s";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
