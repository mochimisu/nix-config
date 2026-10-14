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
      # This host owns only DP-3; retain its choice and leave the others to Hyprpaper.
      outputs=${lib.escapeShellArg "${cacheDir}/outputs.json"}
      if [[ -f "$outputs" ]]; then
        [[ -e "$outputs.before-nix" ]] || cp -p "$outputs" "$outputs.before-nix"
        tmp=$(mktemp "$outputs.XXXXXX")
        jq 'with_entries(select(.key == "DP-3"))' "$outputs" > "$tmp"
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
      selected="$wallpaper"
      outputs=${lib.escapeShellArg "${cacheDir}/outputs.json"}
      if [[ -f "$outputs" ]]; then
        saved=$(jq -r '.["DP-3"] | if .type == "we" then "we:" + .we_id else .path // empty end' "$outputs")
        [[ -z "$saved" ]] || selected="$saved"
      fi
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
      # Restore just DP-3, never the upstream all-output fallback.
      if ! skwd-helm apply "$selected" --output DP-3 --mute; then
        skwd-helm apply "$wallpaper" --output DP-3 --mute
      fi
      skwd-helm mute --output DP-3
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
        # The control API pauses all animated outputs; this host starts only DP-3.
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
