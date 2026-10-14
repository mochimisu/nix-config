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

The phone now turns into a shallow perspective tilt over 420ms and turns away
on dismissal (180ms). QtQuick transforms apply to both drawing and input.
The panel reserves 50 logical pixels around the phone for the rotated edges;
its contents shrink on smaller outputs. Set `SEKAI_LAUNCHER_FLAT=1` before
running the same trial command to disable tilt and entrance/exit motion.

Offscreen validation covers transformed pointer selection as well as search,
keyboard navigation and launch signals. Actual compositor focus and output
placement still require a live trial. The animation preview uses offscreen
icons, which can fall back to initials when platform icon themes are unavailable.


The pose is fitted visually to the original video at 0:13, with its top leaning
right and its top edge rising right. A single mild-perspective matrix combines
pitch 25°, yaw -35° and roll -4° (5000px focal distance), replacing stacked
Rotation items that exaggerated perspective. These are visual-fit parameters,
not recovered author settings. The 356px phone width retains four app columns.
The entrance makes an 80° clockwise turn from a landscape-like pose, as observed
at approximately 8.9–9.1s. This launcher has no landscape settings page, so the
entrance is an adaptation, not a recreation of that page transition.

Reference: https://www.reddit.com/r/LinuxPorn/comments/1x36scr/project_sekai_inspired_rice/

Transformed clicks, keyboard search/navigation/Enter/Escape, compact layout and
flat fallback passed offscreen tests. Fifty-nine nonempty captured frames across
normal/compact entrance and exit passed pixel-bound checks. Live Wayland focus
and placement remain unverified.
