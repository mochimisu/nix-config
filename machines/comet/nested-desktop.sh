set -eu
: "${XDG_RUNTIME_DIR:?Launch through the graphical user manager}"
: "${DISPLAY:?The Valve Gamescope X11 session must be running}"

exec 9>"$XDG_RUNTIME_DIR/comet-hyprland.lock"
flock -n 9 || exit 0
outer_runtime="$XDG_RUNTIME_DIR"
state="$HOME/.local/state/comet-hyprland"
mkdir -p "$state"
chmod 700 "$state"
runtime="$(mktemp -d "$outer_runtime/h.XXXXXX")"
cleanup() {
  rm -f "$state/runtime"
  rm -rf -- "$runtime"
}
trap cleanup EXIT
printf '%s\n' "$runtime" > "$state/runtime"

# Import Home Manager variables only into this process and its children.
unset __HM_SESS_VARS_SOURCED
if [[ -r "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ]]; then
  # Home Manager environment fragments may reference unset optional variables.
  set +u
  # shellcheck disable=SC1091
  source "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
  set -u
fi
export COMET_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_RUNTIME_DIR="$runtime"
# Keep the Unix socket path below Linux's 108-byte limit.
# Only missing graphics dependencies belong here; never add all of /usr/lib.
export COMET_GRAPHICS_LIB="$runtime/native-graphics"
mkdir "$COMET_GRAPHICS_LIB"
for library in /usr/lib/libgallium-*.so \
  /usr/lib/libEGL_mesa.so.0 /usr/lib/libSPIRV-Tools.so \
  /usr/lib/libsensors.so.5 /usr/lib/libzstd.so.1 /usr/lib/libX11-xcb.so.1 \
  /usr/lib/libxcb-randr.so.0 /usr/lib/libxcb-dri3.so.0 \
  /usr/lib/libxcb-present.so.0 /usr/lib/libxcb-xfixes.so.0 /usr/lib/libxcb-sync.so.1 \
  /usr/lib/libxshmfence.so.1 /usr/lib/libvulkan.so.1 \
  /usr/lib/libdisplay-info.so.1 /usr/lib/libdbus-1.so.3 \
  /usr/lib/libcap.so.2 /usr/lib/libsystemd.so.0; do
  if [[ ! -e "$library" ]]; then
    echo "SteamOS graphics dependency missing: $library" >&2
    exit 1
  fi
  ln -s "$library" "$COMET_GRAPHICS_LIB/"
done
mkdir "$runtime/pulse" "$runtime/config"
for socket in pipewire-0 pipewire-0-manager; do
  if [[ -S "$outer_runtime/$socket" ]]; then
    ln -s "$outer_runtime/$socket" "$runtime/$socket"
  fi
done
if [[ -S "$outer_runtime/pulse/native" ]]; then
  ln -s "$outer_runtime/pulse/native" "$runtime/pulse/native"
fi
export PULSE_SERVER="unix:$outer_runtime/pulse/native"
export XDG_CONFIG_HOME="$runtime/config"
# Match Gamescope's actual desktop instead of seeding KWin with 1600x900.
width=1920
height=1080
screen="$(/usr/bin/xrandr --current 2>/dev/null || true)"
if [[ "$screen" =~ current[[:space:]]+([0-9]+)[[:space:]]+x[[:space:]]+([0-9]+) ]]; then
  width="${BASH_REMATCH[1]}"
  height="${BASH_REMATCH[2]}"
fi

# Use Valve's KWin and graphics stack, isolated from the shared user manager.
unset WAYLAND_DISPLAY LD_PRELOAD XDG_DESKTOP_PORTAL_DIR
unset QT_PLUGIN_PATH QML2_IMPORT_PATH QT_QPA_PLATFORM
export QT_QPA_PLATFORM=xcb
/usr/bin/dbus-run-session -- /usr/bin/kwin_wayland \
  --x11-display "$DISPLAY" --socket comet-bridge --width "$width" --height "$height" \
  --no-lockscreen --no-global-shortcuts --no-kactivities \
  --exit-with-session @child@ \
  > "$state/session.log" 2>&1
