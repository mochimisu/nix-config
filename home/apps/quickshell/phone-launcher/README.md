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
