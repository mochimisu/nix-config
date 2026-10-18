# Blackmoon holographic window opening

Enabled October 17, 2026 at the owner's request: short, cool opening motion with a
holographic effect. Host-only Home Manager module:
`machines/blackmoon/home/window-animation.nix`; shader beside it.

- Opening: `popin 82%`, speed 2.2, small Bézier overshoot; fade-in speed 1.
- Shader: continuous top-to-bottom reveal with scattered pastel confetti, glints and bloom, 400 ms; no `time` uniform or idle effect.
- Closing: 300 ms downward dissolve with falling confetti; base `popin 94%`, speed 1.4.
- Fullscreen shader exclusion is the plugin default. Layers/phone are not tagged.

`pkgs/hyprwindowshade/package.nix` builds upstream HyprWindowShade revision
`a4c6b8af424a189072427c4c90ef2938e1b481d3`, the explicit upstream `hyprpm.toml`
pairing for Hyprland commit `efb50993780079460b0cbed1363e2166a2de1d9f` (0.56.2).
Revisit together with compositor upgrades. Home Manager expects the library name
`libHyprWindowShade.so`. Source: https://github.com/ManofJELLO/HyprWindowShade

Validation: package and Blackmoon Home Manager build passed; pinned Hyprland
`--verify-config` passed; nested NVIDIA Wayland session loaded the plugin and
rendered a recorded test-window opening. Live plugin load and configerrors passed.
Repository validation passed 13/14 outputs; Comet could not build its existing
ARM Catppuccin dependency without an aarch64 builder.

Applied live by linking only `hyprland.lua` and the shader into a scoped
`*-home-manager-files` output, rooted by
`~/.local/state/blackmoon-holographic-home-files`. Its Lua preserves the previously
live launcher wrapper path to avoid activating unrelated pending changes. The
generated Home Manager collision checker passed. No full activation/restart.

To disable durably, remove the `./window-animation.nix` import in Blackmoon's
home module and rebuild. Shared shell defaults then resume. For immediate rollback
of this trial, the preceding config target was
`/nix/store/iywzgl2wx1b1g6hlaal1159zazg93pnr-home-manager-files/.config/hypr/hyprland.lua`;
restore that symlink and reload Hyprland (removing the plugin config unloads it).

## Block assembly revision

The owner liked the scan but requested a flashier block/particle snap. The shader
now gathers a 3x3 neighborhood of displaced tiles, grows small fragments into
their window-content tile, and flashes edges as each lands. Random per-window
staggering completes within 280 ms, with exact original pixels at the endpoint.
HM build and nested NVIDIA recording passed; only the shader symlink was changed
live and the plugin shader cache explicitly cleared (Nix files share mtime 1).
To reload after store-backed shader changes: `hyprctl eval
'hl.plugin.HyprWindowShade.reloadshaders()'`. No compositor restart is needed.

## Directional cyan revision

The owner liked block assembly and requested bottom-to-top motion with bloom,
referencing Tron/Digimon. Row height now drives the stagger; fragments rise into
place with slight horizontal jitter. Cyan/ice-blue tile edges, analytic soft
halos and a narrow scan front follow the building rows. Duration remains 280 ms.
Glow is confined to the window surface and disappears completely at the endpoint.
GLSL validation and HM build passed; an isolated midpoint render verified direction
and glow on NVIDIA. The nested test Kitty marked itself maximized, so its normal
shader suppression was explicitly bypassed only in the test config. Production
fullscreen exclusion is unchanged. Applied shader-only and cleared shader cache;
live configerrors and HM collision check passed.

## Sekai cascade revision

The owner requested top-to-bottom direction and a more stylish match to the
Project Sekai reference already used by the shell:
https://www.reddit.com/r/LinuxPorn/comments/1x36scr/project_sekai_inspired_rice/ .
Inspected the saved original clip at 7 seconds and the prior reference comparison.
The new animation is a design interpretation of its pastel cards/teal outlines,
not a claim that the reference uses this exact window effect.

Tiles now fall with slight rotation, clipped corners, pearl inset rims and small
diamond sparkles. A soft diagonal sheen replaces the continuous cyan scan beam.
Colors are substituted directly from home/theme/sekai-palette.json using
pkgs.replaceVars in the host module; validate the **generated** GLSL, not its
placeholder-bearing source. No independent hard-coded palette. Duration stays
280 ms, fullscreen exclusion and clean endpoint stay intact. HM build, generated
GLSL validation, pinned Lua parser and isolated NVIDIA rendering passed. Only
the shader was deployed live, followed by cache clear and HM collision checks.

## Rounded randomized revision

Owner requested rounder, more anime-like tiles, more variation and bloom. Rounded
rectangle distance masks replace chamfers, with corner radii varied per tile and
filled back in as each tile settles. Independent seeded hashes vary initial size,
aspect, tilt, drift, arrival delay and settle duration separately from color.
Direction remains top-to-bottom and total duration 280 ms. Pearl cores and wider
pastel halos add bloom; sparse four-point glints join the diamond accents.
Generated GLSL validation, HM build and an isolated NVIDIA midpoint rendering
passed. Applied shader-only with HM-owned links, collision check, explicit shader
cache clear and clean live configerrors. Fullscreen exclusion remains unchanged.

## Fast arrival and card-depth revision

Owner requested a faster first phase, slower ending and more depth/stylization.
The shader maps elapsed progress through `1 - (1 - t)^1.65` while keeping 280 ms
total. Translation settles ahead of the independent pitch/yaw/roll follow-through.
Inverse perspective projection, a small shaded side wall, contact shadow, bevel
lighting and a moving pearl reflection give the fragments a 3D-card appearance
within the existing per-window shader. Shared palette, rounded random tiles,
bloom, downward direction and exact original endpoint are retained. Perspective
lookup culls samples outside the card footprint before crossing the projection
horizon. This is a shader illusion, not compositor-level 3D window geometry.

Validation: HM build and generated GLSL validator passed; isolated NVIDIA
midpoint and full-speed recording checked perspective and timing. Shader-only
live deployment, HM collision check, cache clear and live configerrors passed.

## Continuous confetti revision

Owner rejected the visible grid as clashing with the Sekai style. Window pixels
now reveal continuously behind a soft bowed/slanted downward veil. Thirty-four
independently seeded anchors supply rounded confetti, diamonds and star glints
around the moving edge, with varied sizes, drift, roll and foreshortening. Pearl
insets, directional rim lighting and pastel halos retain the soft card styling.
No tiled texture sampling or tessellation remains. Keeps 280 ms, fast arrival /
slow finish, shared palette, exact original endpoint and fullscreen exclusion.

HM build and generated GLSL validation passed. Nested NVIDIA full-speed recording
verified the continuous reveal and clean settling. A permanent paused-shader
preview showed an edge artifact absent from the actual opening recording. Applied
shader-only with the HM-owned link, collision check, explicit cache clear and
empty live configerrors.

## Timing refinement

Owner requested more time to appreciate the confetti and approved 400 ms. Only
the shader duration changes from 280 to 400 ms; the existing fast-start easing
reveals roughly three quarters of the window by 200 ms and reserves the rest
for the lower reveal and soft particle fade.

## Visible flight revision

Owner felt the 400 ms effect still looked static. Particle lifetime now uses
elapsed time independently of the fast reveal: each travels for 220 ms, with
128 px vertical displacement, a bowed lateral arc, sustained roll, and a visible
foreshortened flip. Short tapered pearl/pastel wakes emphasize direction. The
veil contour also moves subtly, and final cleanup follows elapsed time so it
does not erase the particle follow-through early. Total duration remains 400 ms.

HM build, generated GLSL validation and nested NVIDIA motion recording passed.
Applied shader-only; HM collision check, cache clear and live configerrors passed.

## Independent movement revision

Owner observed that particles still moved together. Each now has separate seeded
birth time, 112–200 ms lifetime, fade timing, heading, travel distance, bend,
wobble and acceleration. Roll direction/speed and flip phase/rate vary separately.
Particle fades no longer share the reveal's envelope; the continuous reveal
remains downward while confetti can drift in different directions. Total stays
400 ms, with an exact clean endpoint.

HM build, generated GLSL validation and nested NVIDIA motion recording passed.
Applied shader-only with HM collision check, cache clear and clean live config.

## Falling shapes revision

Owner liked independent motion and requested a downward falling bias plus more
shape variety. Vertical travel is now monotonic downward (85–180 px), with
independent speed/acceleration and sideways drift/flutter. Existing independent
starts, fades and tumbling remain. Shape selection now uses its own hash, separate
from size: rounded cards, diamonds, concave four-point sparkles, dots and rounded
slender strips. Duration stays 400 ms.

HM build, generated GLSL validation and nested NVIDIA motion recording passed.
Applied shader-only with HM collision check, cache clear and clean live config.

## Matching close effect

Owner requested a matching window-close animation. Shared GLSL template now
generates both open (400 ms) and close (300 ms) shaders via duration/closing
substitutions in window-animation.nix. Close dissolves the window top-to-bottom
with staggered falling shapes, pastel bloom and trails, ending at zero RGBA.
The open mode preserves its previous timing and appearance. A separate
`+shader_close:` window rule activates the snapshot effect; the plugin owns
snapshot duration and displaced-tile reflow timing.

Both generated shaders, HM build and generated/scoped Lua verification passed.
An isolated NVIDIA recording of actual app exit confirmed the close sequence
and fully transparent endpoint. Applied both shaders and only the added close
rule to the previously live Lua, preserving unrelated pending desktop changes.
HM collision check, reload/cache clear and live configerrors passed.

## Close snapshot coordinate fix

Owner could not see the close effect in normal use. Rules were present on live
clients, but the shader incorrectly used whole-monitor snapshot coordinates:
a small window received only a fraction of the sweep/particles. Earlier maximized
render testing masked this bug. Declare the plugin's `window_rect` uniform and
normalize effect coordinates to its sub-rectangle; continue sampling the texture
at the original v_texcoord. Particle pixel sizes use textureSize * window_rect.zw.
Open windows receive (0,0,1,1), preserving their effect.

HM build and both generated GLSL validators passed. Recorded an actual close of
a 320x220 floating window at (120,80), explicitly fullscreen_state 0 0; confirmed
visible full-window dissolve/confetti and clean disappearance. Shader-only live
deployment, collision check/cache clear/live configerrors passed.
