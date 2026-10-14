# Phone launcher trial

A small Project Sekai-inspired launcher using the existing Quickshell package and
its desktop-entry service. It runs on demand, independently of the sidebar.

From this checkout, try it without rebuilding or restarting the desktop:

```sh
qs -n -p "$PWD/home/apps/quickshell/phone-launcher"
```

Type to search application names, generic names, and keywords. Use Up/Down to move
between rows, Tab/Shift+Tab between applications, and Enter to launch. Left/Right
remain available for editing the search text. Escape or the close button exits
the launcher process. Missing icons display the application's initial.

The Nix module is enabled only for Blackmoon. After a future normal activation,
`sekai-launcher` or Super+Alt+Space opens it. The existing Rofi shortcuts remain
unchanged. No activation is required for the command above.

The panel selects the focused Hyprland monitor and caps its size to that output's
logical dimensions. It uses four columns, or three in a narrow panel. The trial
does not change wallpaper, the sidebar, login, or locking.

Validation: rendered with the pinned Quickshell 0.3.1; offscreen Qt key events
verified initial search focus, filtering/empty results, selection, Enter and
Escape, and safe desktop-entry execution. Repeated runs and 392×640 / 300×480
layouts passed. Blackmoon Nix evaluation and the declared QML outputs passed.
Live layer-shell focus, monitor placement and compositor scaling still need a
desktop trial: the isolated headless compositor could not initialize its backend.


The launcher keeps the reference-inspired portrait pose with mild perspective
(pitch 25°, yaw -35°, roll -4°). These are visual-fit parameters, not recovered
author settings. A thicker stepped chassis sits behind the unchanged screen.
The UI uses a count/status eyebrow, italic heading, pastel accent strip, inset
tile outlines, rounded search field and the existing installed-icon fallback.

Entry is a rigid 460ms upward translation from below the output, with only 7°
of settling rotation. Exit slides down in 320ms. Scale is constant (0.94) and
opacity stays 1. The layer surface anchors to the output's top and bottom, so
its lower clipping edge is the actual screen edge. Its pointer input region
is empty during travel and limited to the phone area after settling. Escape
works during entry, repeated close requests are ignored, and launching waits
until exit completes. The compositor keyboard grab lasts until process exit.

Set `SEKAI_LAUNCHER_FLAT=1` for an immediate flat presentation with no travel,
rotation or chassis depth. Search, app selection and Rofi fallback remain.

Reference: https://www.reddit.com/r/LinuxPorn/comments/1x36scr/project_sekai_inspired_rice/

Offscreen verification covers keyboard controls, transformed clicks, compact
layout, flat mode and repeated early Escape. Pixel checks across 64 nonempty
normal/compact frames found no top/side clipping; only the intended bottom-edge
crossing occurs during travel. Native Wayland focus, output anchoring and input
mask behavior still require a live trial; offscreen Qt cannot verify those.
