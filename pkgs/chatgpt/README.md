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

Build with `nix build .#chatgpt`. The packaged launcher supports two opt-in
window controls, reviewed against ChatGPT 26.1013.40934:

```sh
chatgpt --start-minimized --disable-mini
```

`--start-minimized` starts the main window **hidden in the background**. This
works without a compositor minimize protocol (including Hyprland). Launch
ChatGPT again to show the window. Explicit deep links, recovery dialogs and
other user actions may still open windows; this is a startup preference.

`--disable-mini` prevents the Mini/pet avatar overlay from being created,
including startup restoration, prewarming and explicit open requests. Its
saved pet preference is preserved. Features that require this overlay, such
as its quick chat/voice surface, cannot display while disabled. This does not
disable the separate main-window, Spotlight or computer-use indicators.

For desktop-menu launches and persistent defaults, create
`~/.config/chatgpt-nix/window-options.json` (or beneath `$XDG_CONFIG_HOME`):

```json
{
  "startMinimized": true,
  "disableMini": true
}
```

Precedence: command-line flags > environment > config file > default false.
Environment variables are `CHATGPT_START_MINIMIZED` and `CHATGPT_DISABLE_MINI`,
each accepting `0` or `1`. The inverse flags `--show-window` and `--enable-mini`
override persistent defaults. Unknown arguments and arguments after `--` are
passed through. Invalid config produces an error rather than silently ignoring
it. The config is JSON, never shell code.

Settings are read at process launch. Quit all ChatGPT processes and restart to
change Mini policy; a second invocation only activates the existing instance.
The package alone does not install a config file. This repository’s shared
`home/apps/chatgpt.nix` sets `startMinimized = true` and `disableMini = true` for graphical Linux hosts
and starts ChatGPT at desktop login: a graphical-session user service on NixOS,
or an XDG autostart entry on SteamOS. Headless Gaia and macOS are excluded;
this patched package is Linux-only. Mini/pets are disabled by default. Use `--enable-mini` or
`CHATGPT_DISABLE_MINI=0` on a fresh launch to override that policy.
After building, use `./result/bin/chatgpt` to test, or activate the normal NixOS
configuration to update the system launcher.

## Maintenance

`window-controls.py` patches only exact, count-checked lifecycle anchors in the
main bundle. Hidden startup uses the upstream background creation path, avoids
its fallback show timer, skips both initial reveal sites and progress windows,
and defers renderer-driven primary-window presentation until explicitly shown.
It does not change the second-instance restore/show/focus path.

`patch-bundled-copy.py` applies both permission and window patches in one ASAR
rewrite, preserving other members and recomputing main-module integrity. Builds
run permission tests, launcher precedence/validation tests, actual patched
startup and overlay method checks, and JavaScript syntax validation. A changed
upstream anchor fails the build and requires review; do not weaken the guards.
