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

## Refresh pacing and app details (2026-10-18)

The launcher wrapper selects Qt's threaded render loop and elapsed-time animation
clock (`QSG_RENDER_LOOP=threaded`, `QSG_USE_SIMPLE_ANIMATION_DRIVER=1`) unless
explicitly overridden. Software rendering is excluded. The elapsed-time clock
preserves the existing 260/180 ms motion on mixed-refresh outputs. It does not
force a display mode, disable vsync, reduce the 3× media mask or rasterize text.
[Qt's render-loop documentation](https://doc.qt.io/qt-6/qtquick-visualcanvas-scenegraph.html)
describes the basic loop's ~16 ms timer and the elapsed-time alternative.

On Blackmoon, Hyprland reported DP-3 at 174.963 Hz and DP-1 at 119.998 Hz. Qt logs
confirmed the default basic loop. A noninteractive full-phone benchmark with the
existing 4K snow video header measured these animation callback intervals:

| Output / loop | Mean | Median | 95th percentile | Mean update rate |
| --- | --- | --- | --- | --- |
| DP-3 / basic | 16.00 ms | 15.99 ms | 23.90 ms | 62.5/s |
| DP-3 / threaded + elapsed time | 6.30 ms | 5.81 ms | 11.36 ms | 158.7/s |
| DP-1 / threaded + elapsed time | 8.46 ms | 8.59 ms | 14.17 ms | 118.2/s |

These measure QML animation callbacks during repeated phone movement, not final
scanout or perfect frame delivery. The remaining tail includes missed refreshes;
video frames retain their own source cadence. `tests/desktop/frame-probe.qml`
retains the manual benchmark: set `PROBE_OUTPUT`, optionally `PROBE_WALLPAPER`
(a video file URI), and the render variables, then run it through the launcher's
Qt Multimedia wrapper. It displays a phone for six seconds with an empty input
region and no keyboard focus; it neither launches applications nor changes media
selection. Compare loops on the same output/workload.

A sole search result or a case-insensitive exact app-name match now opens a
centered detail card with a larger icon, name, optional generic description and
comment, and an Open button. Short viewports use a compact card; longer content
scrolls. Enter still opens the selected app, Escape clears search before dismissing,
and arrow/Tab navigation can leave an exact-match card for other ranked results.
Ranking, pointer-output resolution, geometry, curve-rendered text and home media
are unchanged. Empty/no-result queries never retain a stale detail card.

The sidebar normalizes only `nm-applet`'s tray image when an established wired or
wireless link exists. Blackmoon had connected Ethernet plus a secondary Wi-Fi
adapter in `connecting (configuring)`; nm-applet emitted `nm-stage02-connecting01`
for that secondary attempt. Its menu/actions remain intact, and when no link is
established the original connecting/disconnected icon is retained. No network
settings or interfaces were changed; a secondary adapter may continue retrying.

Blackmoon and Oasis Home Manager builds and isolated keyboard/detail/network tests
passed. Only the launcher QML/service and sidebar QML were deployed on Blackmoon,
with Home Manager-owned links and a launcher/sidebar restart. The launcher remains
hidden after startup; existing apps in its cgroup are preserved by KillMode=process.
Snowy wallpaper and HDR edits remain separately owned and uncommitted.

## Phone lift tuning (2026-10-17, Los Angeles)

User feedback found the cubic arrival and hooked path too floaty. Opening now uses
a 160 ms sine ease-in/out, a direct upward lift with 18 px lateral drift, and a
monotonic pitch/roll turn. The settled pose and scale are unchanged. Closing uses
180 ms quadratic acceleration; threaded rendering and elapsed-time pacing remain.
Both 300 ms and 230 ms felt too slow; subsequent user feedback shortened opening to 160 ms.

## Reference animation matching

Re-inspection of the original 1920×1080, 30 fps Reddit clip shows the first
entrance at approximately 4.3–4.8 s: a front-loaded lift reaches its resting
height in about 200 ms, overshoots slightly, then settles. Its top edge starts
flatter and rotates toward the final angle. The exit around 13.6–13.85 s
accelerates downward while rotating back. This supersedes the experimental
300/230/160 ms sine timing: speed alone did not reproduce the motion.

The fitted approximation uses 500 ms OutBack (overshoot 1.4), 32 px lateral
drift, and roll from +8° to −4°; exit is 240 ms InQuad with dismissal at 260 ms.
This is a visual reconstruction, not recovered author code. Final pose, scale,
opaque rendering and high-refresh pacing remain unchanged.
Source: https://www.reddit.com/r/LinuxPorn/comments/1x36scr/project_sekai_inspired_rice/

### Independent wrist follow-through

The first reference fit was rejected as insufficiently stylish. A rendered
before/after frame comparison showed its axes were still locked to vertical
travel and its long-edge lean was too weak. Pitch is now 30°, the rotation pivot
is at 90% of phone height, and a separate 560 ms angular follow-through reveals
the side edge as the hand turns (yaw −16° to −30°, roll +12° to −4°). The upward
lift remains 500 ms with its fast first 200 ms. The lower chassis stays deeper
below the output edge so overshoot does not make the phone float free. Controls
become available near arrival rather than waiting for the final angular settle.
These are visual fitting choices, not verified original implementation values.
The entrance starts just below the projected screen edge, removing invisible
travel before the first visible frame.

### Anime-style accent and fast dismissal

User accepted the wrist-pivot direction as better and requested more anime-style
exaggeration plus a much faster exit. Entrance now has a 420 ms lift and a 500 ms
wrist follow-through with stronger yaw/roll overshoot and three brief mint/white
motion strokes. Strokes disappear before arrival and are absent in flat mode.
Exit takes 100 ms, with dispatch/dismissal at 120 ms (held pointer releases remain
guarded). The keyboard fixture checks Escape dismissal within 180 ms.

Follow-up: user requested a 300 ms entrance. Both lift and wrist now finish
in 300 ms, preserving their separate easing/overshoot and the 100 ms exit.

Follow-up: user clarified that the reference shakes during ascent and has less
landing bounce. Lift/wrist OutBack overshoot is reduced to 0.55/0.7. A separate
220 ms clock drives two small damped lateral/roll oscillations, zero at both
ends and disabled on close, suspend, and flat mode. Entrance remains 300 ms;
exit remains 100 ms.

### Scoped restart verification correction

The user reported no visible change after the shake deployment. The source link
was current, but `qs list --all` showed an older standalone `-d` launcher and
the user service had become inactive: `-n` exited on the existing instance.
An immediate `systemctl is-active` result was a transient startup state, not
proof that the displayed launcher reloaded.

For subsequent scoped deployments, hold `$XDG_RUNTIME_DIR/sekai-launcher-toggle.lock`
across stop/link replacement/start, inspect the actual phone-launcher instance,
and stop only that exact Quickshell PID if it is outside the service. Wait for
its exit before starting the unit. Verify IPC readiness and that the unit's
MainPID matches the sole phone-launcher instance and remains running afterward.
Do not kill the service cgroup or apps launched from it. This recovery was applied
and the current launcher now runs as the service-owned instance.

Resting-pose correction: user clarified that the animation looks fine but the
final tilt is too aggressive. Resting yaw/pitch/roll is now −24°/18°/−3°
(previously −30°/30°/−4°). Relative wrist excursion, shake, easing and 300/100 ms
timing stay unchanged. Projection-derived anchoring uses the corrected pose.
