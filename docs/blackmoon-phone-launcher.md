# Blackmoon phone launcher

The persistent launcher resolves `hyprctl -j cursorpos` against the current
monitor rectangles on every show. `context.py` accounts for scale, negative
origins, and rotated/flipped outputs. It does not use keyboard-focused output.
Canceled or superseded show requests cannot reopen the launcher from an older
query. Missing/disconnected pointer outputs leave it hidden rather than choosing
a stale monitor.

The same query reads `skwd-helm current --json` and uses the selected output's
current image/video URI. At validation both DP-1 and DP-3 selected
`snowfall-in-forest-motionbgs-4k.mp4`. The phone runs its own muted looping decoder
of that file; it is not frame-synchronized with the desktop renderer. Playback
pauses while the launcher is hidden and resumes on show. Skwd is queried again
on the next show, so later desktop selections are followed. Unavailable Skwd or
unsupported Wallpaper Engine scenes get a neutral header, not the old dusk JPEG.

The header's media and rounded alpha mask are rendered at 3x density with a
transparent gutter and smooth mask coverage. Clock/status text remains separate
curve-rendered geometry, avoiding whole-header text blur. The Quickshell wrapper
includes Qt Multimedia's QML imports and decoder plugins. The sidebar center
window title is white on the wallpaper, with no card fill or border.

The service uses `KillMode=process`: applications launched from the phone can
inherit its service group, and a launcher-only restart must preserve them.

Validation: pointer geometry unit tests passed; an offscreen RTX 4090/OpenGL
fixture rendered the animated header and verified advance/pause/resume. Live
show/hide tests selected DP-3, DP-1, DP-3, DP-1 (including the portrait output's
negative-Y area), with the same daemon PID. The test restored original pointer
and focus. Home Manager built, Hyprland parser passed, and scoped file deployment
passed Home Manager's link-collision check. No boot/greeter rotation changed.
