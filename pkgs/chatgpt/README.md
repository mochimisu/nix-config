# ChatGPT Linux package

## Bundled Node compatibility

The package pins patchelf 0.15.2 for ELF fixups. With 26.1023.51421,
patchelf 0.19.2 produces overlapping load segments in the bundled Node
24.22.1 executable. It segfaults inside glibc's `dl_main` before JavaScript
runs, causing remote task creation to return
`DesktopTaskWorkspaceUnavailableError` even for an existing home directory.
The same upstream executable patched with 0.15.2 starts successfully.

An install check runs the actual bundled Node after all fixup hooks and tests
the crypto and networking imports used by workspace preparation. Keep this
check when updating the patcher; successful dependency resolution alone does
not establish that the executable starts. The check needs no desktop session.

## Window controls

Build with `nix build .#chatgpt`. The packaged launcher supports hidden startup:

```sh
chatgpt --start-minimized
```

`--start-minimized` starts the main window **hidden in the background**. This
works without a compositor minimize protocol (including Hyprland). Launch
ChatGPT again to show the window. Explicit deep links, recovery dialogs and
other user actions may still open windows; this is a startup preference.

Mini and pet visibility now use the app's native Show pet / Hide pet controls
and saved preference. The Nix patch no longer blocks overlay creation, prewarming,
or presentation. This preserves native Mini, quick-chat and voice functionality.
The removal and new bootstrap-chunk compatibility were build-validated against
26.1103.32239, including native overlay visibility, hidden startup, permission
tests and the shipped Node install check. No live app restart was performed.

For desktop-menu launches and persistent defaults, create
`~/.config/chatgpt-nix/window-options.json` (or beneath `$XDG_CONFIG_HOME`):

```json
{
  "startMinimized": true
}
```

Precedence: command-line flags > environment > config file > default false.
`CHATGPT_START_MINIMIZED` accepts `0` or `1`; `--show-window` overrides hidden
startup. Unknown arguments and arguments after `--` are passed through. Invalid
config produces an error. The config is JSON, never shell code.

For migration, the retired boolean `disableMini` setting and `--disable-mini` /
`--enable-mini` flags are accepted as no-ops, and `CHATGPT_DISABLE_MINI` is removed
from the child environment. This lets the new package launch with an older Home
Manager config while leaving visibility entirely to the app.

Settings are read at process launch. A running older app retains its patch until
fully quit and relaunched. This repository's shared `home/apps/chatgpt.nix` sets
only `startMinimized = true` for graphical Linux hosts and starts ChatGPT at login:
a graphical-session user service on NixOS, or XDG autostart on SteamOS. Headless
Gaia and macOS are excluded; this patched package is Linux-only.
After building, use `./result/bin/chatgpt` to test, or activate the normal NixOS
configuration to update the system launcher.

## Maintenance

Run `nix run .#update-chatgpt` from the repo root to refresh the app version and
both architecture hashes. The updater identifies the version by the adjacent
`pname = "chatgpt"` field; dependency versions such as `patchelfCompat` must not
be selected or rewritten. Run `python3 pkgs/chatgpt/test-update.py` for offline
regression checks. `nix-up` runs the updater from the current checkout through
`nix run .#update-chatgpt`, so updater repairs do not require another rebuild.
Shells with the older store-pinned alias need a one-time alias refresh (or Home
Manager activation and a new shell); use the direct command until then.

On 2026-11-07, 26.1103.32239 moved the application entry point to
`.vite/build/early-bootstrap.js` and split its code into webpack chunks. The
reviewed runtime lives in `early-bootstrap-920-a204a41244c4b913.js`. The patcher
requires that exact member, the complete executor helper, a SHA256 of the full
inline customization function, and exact startup anchor counts. Changed upstream
code must be reviewed again rather than widening these matches. The new visualize
customizer can remove `skills/live`; existing directory permission preparation
covers this without making additional files writable.

The x64 package build passed with no unresolved ELF dependencies and a successful
bundled-Node check. All 19,927 packed ASAR members were compared: only the reviewed
runtime chunk changed, all output integrity values verified, and unpacked/link
metadata was preserved. ARM64 and live GUI behavior have not been tested.

`window-controls.py` patches only exact, count-checked lifecycle anchors in the
reviewed runtime chunk. Hidden startup uses the upstream background creation path, avoids
its fallback show timer, skips both initial reveal sites and progress windows,
and defers renderer-driven primary-window presentation until explicitly shown.
It does not change the second-instance restore/show/focus path.

`patch-bundled-copy.py` applies both permission and window patches in one ASAR
rewrite, preserving other members and recomputing runtime-chunk integrity. Builds
run permission tests, launcher precedence/validation tests, actual patched
hidden-startup and native-overlay method checks, and JavaScript syntax validation. A changed
upstream anchor fails the build and requires review; do not weaken the guards.
