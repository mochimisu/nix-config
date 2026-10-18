# Blackmoon focus borders and workspace title card

Added October 17, 2026 at the owner's request. The title format is strictly the
uppercase hostname, ` // `, and the workspace number padded to two digits:
`BLACKMOON // 01`. No workspace names or descriptive subtitles.

## Focus border

The active border is static teal/lavender with borderangle disabled. Continuous
border particles were removed at the owner's request after a live sample measured
about 11% of one CPU core for the combined particle/card service. The particle
component, its 30 Hz movement timer, 5 Hz geometry polling and layer rule are
removed. Workspace cards and opening/closing effects remain enabled.

## Workspace title card

The Blackmoon-only `workspace-card` module is imported by `window-animation.nix`.
Its `sekai-workspace-card.service` runs a separate persistent Quickshell instance.
The QML consumes native Hyprland monitor/workspace state, without polling or
spawning commands for each switch. Each output owns a card and follows only its
own active workspace; IPC hydration and output reconnects update monitor bindings.
Initial startup hydration and special/negative workspace IDs do not show cards.

The hostname comes from NixOS `networking.hostName`, uppercased at build time;
text uses the numeric workspace ID, never its name. The card has a pearl face,
lavender backing, mint underline and small sparkles from the shared Sekai palette.
It enters in 230 ms, begins fading at 850 ms, and unmaps after another 170 ms.
Rapid switches cancel/restart the existing animation and replace its number.
Sparkles turn and twinkle once on entry, with the smaller sparkle delayed; the
shadow starts slightly wider/lower and settles over 380 ms. Sparkle motion ends
at 720 ms. Both reset on each show without idle loops. Narrow outputs scale the
card and reserve room for its decorative sparkles.

The layer reserves no desktop space, has an empty input region and requests no
keyboard focus. Its `no_anim` layer rule lets QML own the timing, avoiding an
extra compositor fade after unmapping. Hidden cards have no running animation.

## Validation and scoped deployment

Blackmoon HM build and generated/scoped Hyprland Lua parser checks pass. Nested NVIDIA rendering verified actual focus transitions, the
`BLACKMOON // 07` card, rapid switches ending at `BLACKMOON // 11`, and complete
unmapping after exit; QML logs were clean. Existing opening/closing shaders remain.

The scoped output rooted by `~/.local/state/blackmoon-desktop-cues-home-files`
contains the previously live Lua plus only the card layer rule, shaders, card QML, service unit and graphical-session target link. Home
symlinks point through this `*-home-manager-files` root, with the generated HM
collision checker run afterward. Only this new service and compositor rules are
loaded; unrelated pending wallpaper, launcher and desktop changes are not activated.

To disable the card, stop `sekai-workspace-card.service` and remove its module
import for a durable rollback. The native focus border styling is in window-animation.nix. The
opening/closing effects can remain independently enabled.

## Quiet-border and animated-card refinement

Owner requested lower-motion border focus feedback plus animated card sparkles
and shadow. Scoped follow-up removes the prior focus shader rule and installs
native border palette/easing, then replaces only card QML and restarts its service.
The old focus shader home symlink is removed. Follow-up GC root:
`~/.local/state/blackmoon-soft-cues-home-files`.

Refinement validated with nested native-border focus transitions and early/settled
card renders, including narrow-output fitting. Live focus shader tags are absent;
card service is active with clean QML logs and compositor config. Removing the
rule alone left dynamic tags on existing windows; a temporary negative-tag rule
cleared them, then a reload removed the temporary rule.

Slow-border refinement: HM build and generated/scoped Lua verification passed;
nested NVIDIA focus recording checked the slow border rotation. Scoped Lua-only
deployment is rooted by `~/.local/state/blackmoon-border-drift-home-files`; opening,
closing and workspace cards are unchanged.

## Continuous particle refinement

The owner explicitly rejected the 2.4 s once-on-focus rotating border as noisy;
the desired effect is continuous sparse geometry on the focused border. HM build,
generated/scoped Lua verification and nested NVIDIA QML tests passed. Two captures
2 s apart showed steady travel on the focused border only; focus changed the
selected window, and fullscreen/empty-workspace checks removed the particle layer.
QML logs were clean. Scoped Lua/QML deployment is rooted by
`~/.local/state/blackmoon-border-particles-home-files`; collision check, reload
and service restart passed. Workspace cards and opening/closing are preserved.

Visibility refinement: the first particles were too faint in normal use. Diamonds
are now 5 px, the glint 10 px, both at 85% opacity with a localized mint/pearl
halo. Three particles and the steady 20 px/s travel remain. HM build, nested
render/focus/fullscreen/empty-workspace checks and QML logs passed. QML-only live
deployment is rooted by
`~/.local/state/blackmoon-border-particles-visibility-home-files`; collision
check and service restart passed.

Density refinement: owner could still spot only one particle at a time. The border
now distributes 8–18 shapes according to perimeter (roughly one per 300 logical
px before the caps), with slightly varied spacing and a glint every third shape.
Speed, size, brightness and glow are unchanged.

Fine-particle refinement: owner requested smaller, many more, independently moving
shapes. Density now targets one per 100 logical px, bounded to 24–72. Stable
per-index speed and scale variation keeps focus changes from rerolling particles;
the shared elapsed-distance clock does not wrap and cause differing-speed jumps.
Halos shrink with each shape.
HM build and nested rendering/focus/fullscreen/empty-workspace checks passed with
clean QML logs. Deployed QML only via the same visibility root; collision check
and service restart passed.

## Particle retirement

Owner requested removal after reviewing CPU cost. Removed the QML component,
its instantiation/install declaration and layer rule; static focus borders,
workspace cards and window open/close remain. HM build and generated/scoped Lua
verification passed. Scoped shell.qml/Lua deployment is rooted by
`~/.local/state/blackmoon-no-particles-home-files`; removed the old particle
home symlink, passed collision checks, reloaded Hyprland and restarted the card
service. No particle layer remains and QML logs are clean. A subsequent 8-second
sample measured about 0.6% of one CPU core for the remaining card service,
compared with the earlier 11% sample (not a controlled GPU/frame-time benchmark).
