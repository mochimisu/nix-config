# Phone launcher trial

A small Project Sekai-inspired launcher using the existing Quickshell package and
its desktop-entry service. It runs on demand, independently of the sidebar.

From this checkout, try it without rebuilding or restarting the desktop:

```sh
qs -n -p "$PWD/home/apps/quickshell/phone-launcher"
```

Type to search application names, generic names, and keywords. Use Up/Down to move
between rows, Tab/Shift+Tab between applications, and Enter to launch. Left/Right
remain available for editing the search text. Escape clears search back to home, then exits; the close button always exits
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
(pitch 18°, yaw -30°, roll -4°). These are visual-fit parameters, not recovered
author settings. A thicker stepped chassis sits behind the unchanged screen.
The UI uses a count/status eyebrow, italic heading, pastel accent strip, inset
tile outlines, rounded search field and the existing installed-icon fallback.

Entry is a rigid 260ms lift from below the output. A shallow horizontal arc
coordinates yaw, pitch and roll as the phone settles toward the viewer. Exit slides down in 180ms. Scale is constant (0.94) and
opacity stays 1. The layer surface anchors to the output's top and bottom, so
its lower clipping edge is the actual screen edge. The resting position uses
projected lower-corner bounds to hide the rounded bottom below that edge, with
8px of extra crop. The footer and home indicator are removed; the app grid extends below the output and is cropped naturally. Its pointer input region
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

Updated validation: keyboard and transformed-click regressions pass at normal
and compact sizes; early repeated Escape still dismisses exactly once. Animated
geometry checks at 560×1080, 400×580 and 360×480 keep both lower rounded-edge
endpoints below the viewport while scale/opacity remain constant; flat mode
passes the same checks. Pixel bounds at 560×900 and 400×580 confirm no top/side
clipping and continuous bottom cropping once settled. These are offscreen
checks, not verification of the live compositor's output anchoring or focus.

The grid paints to the phone bottom without a footer strip. Its 110px bottom
scroll margin allows the last row to move clear of the output crop. Keyboard
navigation explicitly scrolls the selected row above that hidden area, keeping
clipped apps reachable. Last-row visibility and Enter launch pass at normal
and compact sizes; search, transformed clicks and rapid Escape still pass.

Screen-content styling now uses a compact count badge, inset search field with
a magnifier, coordinated mint/lilac/rose/cream tiles, fine white insets and a
slight raised edge. Icons are 36px with readable semibold labels. Keyboard
selection uses a thicker outline and small gold marker; pointer hover uses a
blue tint. No new widgets or settings integrations are added. The 260ms motion,
phone transform and bottom crop are unchanged. Search, transformed clicks,
compact last-row visibility/launch and early Escape passed offscreen regression
checks. The close-up is an untransformed component render; absent offscreen
platform icon themes still cause graceful initial-letter fallbacks.


## Home controls and search

The phone is now up to 400×720 logical pixels (about 12% larger), retaining the
approved perspective, bottom crop and 260ms rigid entrance. Empty input shows
home controls; typing keeps the first character and transitions to app results
in 140ms. Clearing input returns home. Escape clears a query first, then closes.
The home view scrolls on short screens, including its capture button.

Status.qml uses the same Quickshell Networking, Bluetooth and PipeWire services
as the sidebar. The header shows the local configured dusk wallpaper, actual
clock/date and receive/transmit byte rates from /proc/net/dev for connected
NetworkManager interfaces. The reference's corner arrows are transfer rates.
A first sample or unavailable backend shows an em dash/Unavailable, never mock
live data. Network and Bluetooth buttons dismiss the phone and open the existing
nm-connection-editor and blueman-manager. Speaker toggles mute and its slider
adjusts the default output from 0–100%. Screen capture dismisses the phone and
runs the existing ~/.config/hypr/screenshot.sh after a short compositor delay;
that script selects an area, saves it under ~/screenshots and copies it.

Tests: first keystroke (including during entrance), query/clear transitions,
Escape, mock control routing/mute/volume/capture, transformed app clicks,
compact last-row accessibility, and normal/compact geometry passed. The
sandbox cannot connect to desktop DBus or PipeWire, so live status updates,
audio writes, manager windows, screenshot execution and Wayland focus/masking
remain unverified. No connectivity, pairing, audio or screenshot side effects
were executed in testing. Preview screenshots show actual unavailable-service
states, with real local wallpaper/time; mocked state is confined to tests.

## Clean header and outside dismissal

Home now starts with the wallpaper/time/rate header; the notch, home title and
home search box are removed. Compact 64px control buttons sit immediately below
it. A focused home input item captures printable text (excluding Ctrl/Alt/Meta),
reveals search and transfers focus with the first character intact. It does not
intercept keys sent to a focused control. Clearing returns focus to home.

The layer surface now covers the entire focused output and consumes pointer
input. A background shield maps each press through the inverse phone transform
and tests rounded front/rear chassis bounds. Inside controls retain their normal
hit testing; outside presses dismiss. The shield waits for the pointer release
before allowing exit, preventing click-through even on a held dismissal press.
This replaces the earlier limited input-region behavior described above.

Offscreen tests passed first-character entry, focus isolation, query clearing,
compact controls, transformed app/control clicks, and outside press/release with
an underlying test MouseArea receiving zero clicks. Live compositor routing
across actual desktop apps and multiple outputs remains unverified.

The wallpaper header is fully opaque and flush with the screen's top and side
edges. A Canvas clips the source image only at the screen's rounded top corners;
there is no wash, image padding or header border. White text uses a fine dark
outline for contrast. Header expansion preserves the controls' previous size
and vertical position. Normal/compact home input/control tests and transformed
inside/outside-click tests pass; the real wallpaper render was inspected.
