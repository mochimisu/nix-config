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

## Center-out materialization experiment

Opening now selects `materialize-open.glsl`; the old `holographic-open.glsl`
source is retained unchanged and still generates the close effect. Duration is
400 ms. A clipped diamond/hexagonal pearl silhouette expands from the center,
revealing unchanged window pixels; sixteen independently timed angular shards
converge from positions beyond the four borders. The existing plugin clips all
drawing to the window, so external flight is not drawn over the desktop. No new
plugin, phone changes, or Chromium changes.

Validation: Home Manager build and generated GLSL validation passed; actual GLSL
rendered offscreen for terminal, wide and portrait proportions, with transparent
start and byte-exact original endpoint checks. Live Kitty probe at (150,150),
720x440, fullscreen=0 had the opening tag; captured live video visibly confirms
the expanding silhouette and converging shards. Config errors empty after cache
clear. The initial colored rectangular flash was fixed in the follow-up below.

Only the opening shader symlink was deployed to an HM-owned generated file.
Previous live shader: `/nix/store/4w3s2mnpbd7n88cbkvxqs7n5rq7j5bix-home-manager-files/.config/hypr/shaders/holographic-open.glsl`.
Immediate rollback: run `python3 /home/brandon/Documents/Codex/2026-10-14/task-2/materialize/rollback.py`.
Durable rollback: change the `mkShader` template selection in window-animation.nix
back to `pkgs.replaceVars ./holographic-open.glsl`, then rebuild.
Preview, live evidence, build log and rollback helper are in that workspace's
`materialize/` directory. Changes are uncommitted. The existing checkout was main;
no separate style branch existed, and no branch switch was performed.

### Startup-buffer guard and exterior-drawing boundary

The plugin renders intermediate targets at source texture size (Hooks.cpp,
runIntermediateStages). A one-pixel placeholder therefore samples the procedural
center once and stretches that colored result over the window. The opening
shader now returns zero RGBA while either texture dimension is below 2 pixels.
Recorded live guarded-probe.mp4 confirms the colored slab is gone and the
center-out reveal remains. GPU checks cover 1x1, 1x400 and 720x440 textures.
The native border/blur rectangle can still precede the real client buffer; it
is not rendered by this fragment shader and was not disabled globally.

Exterior flight is not implemented: runIntermediateStages allocates source-sized
FBOs, and hkGLDrawTex replaces only the texture before handing the original
element/box back to Hyprland. An opening fragment shader has no rasterized pixels
outside that box. A full exterior effect requires an expanded render pass with
matching damage, geometry, clipping/rounding and stacking treatment, or a separate
synchronized overlay. Neither has been added; no new plugin was installed.

The synthetic animated preview (no personal desktop content) was saved to Library:
`browser.gif`, library_file_id `libfile_071d3f9bc7c48191a6bfab8d81f32d45`,
file_id `file_00000000097c81f690a541562d64dbd7`.

### Five-point star refinement

Owner requested a star. Opening now uses a regular five-point polygon with inner
radius 0.45, pixel-isotropic aspect correction, derivative antialiasing and a
corner-derived final radius so the star fully reveals wide and portrait windows.
Timing, inward shards, placeholder-buffer suppression and close shader are
unchanged. HM build, GLSL validation and GPU renders for terminal/wide/portrait
passed, with transparent-start and exact-endpoint assertions. Recorded live
secondary-monitor probe confirms the star and no colored startup slab; config
errors remain empty. Only the opening link changed. No commits/pushes.

Previous center-out shader is saved as `materialize/pre-star.glsl`; its live HM
target is in `materialize/pre-star-live.txt`. Run
`python3 /home/brandon/Documents/Codex/2026-10-14/task-2/materialize/rollback-star.py`
to restore that live version. Original confetti rollback is still available.
Library preview: star-browser.gif, file_id file_0000000088a4820cba1a51eb7fbb1868,
library_file_id libfile_7293fb0224948191bcb406b0e584d904.

### Large content-carrying assembly pieces

Owner requested larger shapes that build the window. Ten broad angular sectors
now carry displaced samples of the actual window texture, instead of decorative
particles over an independent reveal. Their offset and slight rotation settle
into a regular five-point star before the star expands to the complete window.
Pearl/pastel faces become their carried content before landing; rims disappear
as the complementary sectors settle. Duration remains 400 ms. Startup-buffer
guard, antialiasing, exact final pixels, phone launcher and close shader retained.
Exterior flight is still clipped by the existing plugin.

HM build, generated GLSL validation and terminal/wide/portrait GPU renders passed
with transparent-start/exact-endpoint checks. Live 720x440 Kitty probe on DP-3
had the correct tag; assembly-live.mp4 confirms content-bearing sections joining
into the star and the clean final window. Configerrors empty and scoped HM
collision check passed. Only the opening shader link was deployed.

Prior approved star source/link are preserved in materialize/pre-assembly.glsl
and pre-assembly-live.txt. Run materialize/rollback-assembly.py for immediate
rollback to that live star version. Preview assembly-browser.gif is in Library:
file_00000000687081f5a00cefb5e4d4b4e7 / libfile_8d8d6c9b16188191a1a8408ecf57b685.
No commits or pushes.

### Fixed-size translation-only assembly

Owner explicitly rejected zoom and removed the star requirement. The opening
shader now tiles the complete window with twelve large triangles (six rectangular
cells split diagonally), translating actual full-size content directly into final
positions with a restrained stagger. No star, radial growth, scale, rotation or
independent reveal. Native windowsIn and fadeIn are disabled so Hyprland cannot
add its previous popin 82% zoom or opening fade. Close and other motion unchanged.
Startup-buffer guard retained; settled triangles restore exact original pixels.

HM build, generated GLSL and scoped Hyprland parser passed. Terminal/wide/portrait
GPU renders passed transparent-start and exact-endpoint checks. Actual live Kitty
recording verified translation-only assembly; 22 geometry samples all reported
(150,150), 720x440. Live configerrors empty. Shader plus only the two animation
flags were deployed in a scoped HM-owned files output; no unrelated generated Lua
changes applied. Phone launcher untouched. Existing clipping boundary remains.

Rollback of both live links: `python3 /home/brandon/Documents/Codex/2026-10-14/task-2/materialize/rollback-fixed.py`.
Prior source: materialize/pre-fixed.glsl. Current evidence: fixed-live.mp4,
fixed-live-geometry.json, fixed-verify.log and fixed-browser.gif. Library preview:
file_000000007ac881fd91c68c710f71a879 / libfile_008607d6b2ec81919754328dccfbe10c.
Changes uncommitted; no push.

### Smaller irregular assembly

Owner requested smaller, less uniform pieces with varied shapes, speeds and
rotations. Shared jittered vertices now partition a 5x4 (portrait 4x5) layout
into up to forty irregular triangles, with seeded merges creating quadrilaterals.
Each piece independently varies birth, duration, acceleration, travel distance,
heading, curved lateral travel and rotation (up to about 43 degrees). All choices
are deterministic from the opening seed; no frame-dependent noise. Actual window
content stays full-size and settles onto shared edges, with exact original pixels
after completion. 400 ms duration, no global zoom/star/reveal, startup guard,
phone and closing behavior remain intact. Exterior clipping unchanged.

HM build, GLSL validation and three-proportion renders passed. Same seed/time
produces byte-identical frames. RTX 4090 isolated GPU midpoint measurements
(median of 15 draws): 0.133 ms at 720x440, 0.782 ms at 1920x1080, 1.847 ms at
3440x1440; previous simple shader 0.012/0.065/0.150 ms. These exclude the rest
of compositor rendering. Bounds culling limits texture samples to nearby pieces.
Live recording confirms varied rotating pieces and clean final window; 22 samples
kept geometry at (150,150), 720x440. Configerrors empty; only shader link deployed.

Rollback: materialize/rollback-organic.py, using pre-organic-live.txt. Source
backup pre-organic.glsl. Preview organic-browser.gif saved to Library:
file_00000000b72081f5b74977f7c8d4d83a / libfile_51908b80cb208191bdff53fb9f2cd372.
Evidence: organic-live.mp4, organic-performance.json. No commits or pushes.

### Irregular assembly with landing accents

Owner likes the irregular assembly and requested subtle connection embellishments.
Each piece now emits one short local seam glint only after reaching its final
pose; about 30% also receive a tiny antialiased four-ray sparkle just inside that
joining edge. A 42 ms envelope limits accents to arrival, with a maximum 40 px
seam segment and 9 px sparkle footprint. Pearl/mint/lavender palette, no ambient
particles or full-surface flash. Alpha is unchanged and exact original pixels
return at completion. Motion, full-size geometry, startup fix, launcher and close
behavior remain unchanged; no new plugin or exterior drawing.

HM build, generated GLSL and three-proportion start/end tests passed. During
settling (progress 0.7), RTX4090 isolated GPU medians were 0.135/0.794/1.874 ms
at 720x440 / 1080p / 3440x1440, versus 0.134/0.790/1.863 ms before accents.
Same-seed frame repeatability passed. Recorded live opening verifies combined
assembly/landing accents and clean ending; configerrors empty, HM link check
passed. Only opening shader deployed. Rollback helper rollback-glitter.py restores
pre-glitter-live.txt; source backup pre-glitter.glsl.

Library combined preview glitter-browser.gif:
file_00000000707c81f5b4268240441a49bb / libfile_ae72b73e016881918560dd1125959ad1.
Evidence: glitter-live.mp4 and glitter-performance.json. No commits/pushes.

### Temporary translucency in flight

Flying pieces multiply premultiplied RGB and alpha together by an opacity ramp
from 0.38 to 1.0, using smoothstep(0.22, 0.94, age). Each piece restores the
sampled native alpha before landing; the final frame remains byte-exact source
RGBA. No permanent app opacity settings changed. Irregular geometry, rotation,
landing glints, fixed window size, close effect and phone launcher are unchanged.

HM build and GLSL validation passed. Opaque/native 60%-alpha content passed
transparent-start and exact-final checks at terminal, wide and portrait sizes.
Additional GPU checks for source alpha 0/153/255 at seven progress values confirmed
premultiplied RGB never exceeds alpha and output alpha never exceeds source alpha.
Live opaque and 60%-opacity Kitty probes confirmed transient translucency and
native final appearance; fixed 720x440 geometry, correct shader tags, configerrors
empty. Blur still follows compositor surface/rendering behavior: translucent
Kitty retained its blur; opaque clients do not gain equivalent background blur
merely from this shader. Original window clipping still applies.

Evidence: materialize/translucent-live-opaque.mp4 and translucent-live-kitty.mp4
(private local recordings), their geometry JSON, and safe synthetic comparison
translucent-comparison.gif. Library: file_00000000a46481f485d3ae0381ccc466 /
libfile_aeb48670d94881919390a0b297bf7343. Rollback: materialize/rollback-translucent.py
uses pre-translucent-live.txt; source backup pre-translucent.glsl. Only the opening
shader link was deployed. No commits/pushes.

### Actual Chromium verification and reboot persistence

The reported Chrome discrepancy was tested with actual native-Wayland Chromium
(class chromium-browser, xwayland=false), both a tiled new about:blank window and
a controlled floating 960x600 window. Correct shader tags were already present.
Recordings visibly show irregular assembly and backdrop visible through flying
pieces, followed by an opaque final browser. No browser flags, profile settings,
security settings, or permanent opacity workaround were required. A new tab does
not map a new compositor window and therefore cannot trigger this opening shader;
the user's original exact action remains unknown, so a new-window failure was
not reproduced. Test with a genuinely new window (Ctrl+N), not Ctrl+T or focusing
an existing browser window.

Hyprland source does contain opaque-region occlusion and optional blending
suppression: ElementRenderer.cpp disables blending only when window alpha is
full, rounding <= 0 and the window reports opaque. These are possible limits for
other paths, not a demonstrated blocker in the recorded rounded Chromium path.
Do not introduce a global 0.99 opacity workaround from this test.

During investigation Blackmoon rebooted independently. The plugin loaded, but
boot activation restored old shader files from 4w3s2mnp...-home-manager-files and
re-enabled native windowsIn/fadeIn. Restored only the intended opening shader
from 2p0cx21...-home-manager-files and the previously validated scoped Lua from
5sz8plhj...-home-manager-files; an exact comparison confirmed that Lua differs
only in those two opening flags. Repeated actual Chromium and Kitty probes after
restoration; both passed, 960x600 fixed geometry, configerrors empty. All disposable
windows and temporary rules were removed, existing sessions preserved. Launcher
and close behavior unchanged. Source changes persist in the repo, but a scoped
live-link trial is NOT reboot-persistent: the installed NixOS/Home Manager
boot generation still needs a reviewed deployment. Full activation was not run
because it includes unrelated pending configuration changes.

Actual browser recording over a controlled backdrop (not synthetic browser
content): materialize/real-browser-controlled.mp4. Matching Kitty evidence:
materialize/real-kitty-controlled.mp4. Shareable browser preview:
actual-chromium-assembly.gif, file_00000000307c81fd8a199783716995e8 /
libfile_22aae2e6f1e08191a5f40262d8e64719. Post-reboot old link targets saved in
materialize/post-reboot-before-links.json. No commits/pushes.

### Stronger translucency and test-harness correction (current)

Current flight opacity is 0.18 until normalized piece age 0.78, smoothly returning
to native alpha by 0.99. Duration, geometry, glints and final clean source pixels
are unchanged. Actual Chromium before/after recordings show the patterned backdrop
more clearly through moving pieces, with a stronger late transition to opaque;
Kitty retains native final transparency. Build/GLSL and three-aspect endpoint
checks passed. GPU tests at native alpha 0/153/255 verify premultiplied bounds,
exact final RGBA and no overlap inflation above the 18% flight plateau. Only the
opening shader was deployed; reboot persistence remains pending reviewed rebuild.
Rollback: materialize/rollback-strong-translucency.py with source backup
pre-strong-translucency.glsl and target pre-strong-translucency-live.txt.
Actual-browser comparison (1.5x playback duration; different per-window seeds):
chromium-strong-translucency-comparison.gif, file_000000007d0082308b5a76601a4e9c11 /
libfile_e94e2a86b7fc8191804ff13d58bdff10.

CRITICAL correction to earlier cleanup claims: probe-real-browser.py and
probe-real-kitty.py passed a bare address string to hl.dsp.window.close, whose
Lua API requires a table containing window. The string was silently ignored and
cleanup closed the active window instead. Prior assertions that existing sessions
were preserved are invalid. Exact affected windows were not logged. User reported
the impact and stopped live tests. All live probes are now disabled at entry;
the two malformed helpers were removed entirely. No live UI actions were taken
while fixing the harness after the user's permission to continue.

New owned_window_plan.py is offline-only and has no subprocess/desktop executor.
It requires dedicated unique app ID, PID/start time, window address/stable ID,
creation-time baseline exclusion, and exact current identity revalidation. It
rejects missing/ambiguous/shared/reused identities and generates table-shaped
selector data with execution disabled. Six unittest groups cover valid planning,
focus independence, missing/changed/duplicate identities, shared/preexisting
processes, malformed/injected fields, and untyped/tampered ownership. All passed.
This is NOT a live-ready cleanup runner: sequential read/close creates an address
reuse race. Any future live adapter needs isolated compositor routing and atomic
identity revalidation; never wire this planner directly to the user's compositor.
Existing recorded evidence suffices for the current visual evaluation.

### Matching close disassembly

Owner approved the stronger opening and requested a matching close. Both variants
now use materialize-open.glsl; closing is a compile-time branch with 240 ms duration.
The same irregular triangles/quads separate along seeded curved paths, rotate,
fade from native alpha toward 18%, then disappear. Departures stagger up to 11 ms;
small local departure glints are 55% of the opening accent strength. There is no
global scale or independent reveal. Default HyprWindowShade close replacement
(no overlay directive) holds snapshot geometry/alpha, so no native animation
settings were changed. Original-window clipping remains a plugin constraint.

Offline GPU checks passed for wide/terminal/portrait and native alpha 0/153/255:
exact native RGBA at close start, transparent finish, premultiplied bounds, and
byte-identical old/new opening output at nine progress samples. Generated GLSL
and Home Manager build passed. Only the close shader leaf link was deployed;
cache refresh returned ok and configerrors is empty. Opening live bytes unchanged.
NO desktop windows were opened, closed, focused or manipulated for this task.
Actual close playback/snapshot integration remains unverified; these checks are
offscreen rendering, not a claim of live compositor visual validation.

Preview matching-close-offline.gif is explicitly labeled OFFLINE RENDER and uses
synthetic opaque/60%-alpha textures side by side, with endpoint viewing holds.
Library: file_00000000c98c8230b14674e53d33c863 /
libfile_63e8481438448191989533d979b4fbba. Workspace render-matching-close.py holds
validation. rollback-matching-close.py restores pre-matching-close-live.txt;
pre-matching-close-materialize-open.glsl and pre-matching-close-window-animation.nix
preserve source rollback. Legacy live probes remain disabled. Reboot persistence
still requires reviewed rebuild; no whole-system activation or commits/pushes.

### Traveling seam glints and settling ripple

Approved opening embellishments: each short thin glint now travels from 12% to
88% along a joining edge during its landing pulse; opening glint strength is
reduced from 0.52 to 0.32 and outer boundary glints are excluded. A faint wave
originates at the latest-landing cell and crosses nearby settled seams, with
5.5% maximum color interpolation limited to an 8px seam neighborhood. It fades
before completion. No glass bevel or closing afterglow. Geometry, flight timing,
18%-native-opacity hold/ramp and matching 240ms close remain intact.

HM build and GLSL validation passed. Offscreen tests cover 960x600, 720x440 and
380x650 with native alpha 0/153/255: opening alpha matches the preceding shader at
41 progress samples, exact clean endpoints, premultiplied bounds; close rendering
is byte-identical at nine samples. Only opening shader live link changed; close
live file bytes unchanged. Cache refresh succeeded, configerrors empty. No live
window creation/closing/focus/manipulation or legacy probe runs. Actual compositor
playback remains unverified. Source rollback pre-seam-ripple.glsl; live rollback
rollback-seam-ripple.py uses pre-seam-ripple-open-live.txt. Reboot persistence
still awaits reviewed rebuild; no whole-system activation, commit or push.

Preview seam-ripple-offline.gif is a clearly labeled synthetic before/after,
slowed to 2x duration with endpoint holds. Library:
file_00000000369c81fbb47235bbb28446ab / libfile_577f9385c15c819183a8f8492bd1e419.

### Restrained downward close

Owner rejected the radial explosion; opening embellishments were not intensified.
Close alone now uses a short gravity-like downward drop: max min(height*0.08,48px),
side drift at most 5px, rotation capped at 0.045 radians and 3px edge displacement.
The previous trajectory reached 0.65–1.10 window diagonals in arbitrary directions.
Fade reaches zero at departure age 0.80, before completing the limited travel.
Duration remains 240ms. Explicit closing uv/window_rect rejection prevents fragment
output outside the logical window rectangle, including padded snapshot textures.
This bounds the shader itself; no claim is made about separate compositor effects.

Build/GLSL passed; offscreen wide/terminal/portrait alpha0/153/255 checks preserve
native initial RGBA, transparent end and premultiplied bounds. Opening byte-identical
at nine progress samples, installed opening file unchanged. A padded-snapshot test
confirmed zero output alpha outside window_rect at five progress samples. Only
close leaf installed; cache refresh ok/configerrors empty. No desktop window
creation/closing/focusing/manipulation. Actual compositor playback unverified.
Rollback: rollback-downward-close.py / pre-downward-close-live.txt; generated old
close saved as pre-downward-close.glsl. Preview downward-close-offline.gif is
synthetic before/after at about 3.3x duration plus endpoint holds:
file_00000000b89081fb802a57d45c91da06 / libfile_865ca13173f88191bfc8e3b996a261f4.
Persistence still pending reviewed rebuild; no whole-system activation or commits.

### Instant-close report: fade timing correction, integration not proven

Read-only live checks: plugin loaded; close shader tag present; global animations,
windowsOut and fadeOut enabled; close directive 0.24s; configerrors empty. Exact
configured Hyprland source xm2laz7... has snapshot creation in Window::unmapWindow
and WindowFadeout::create; plugin source tags that fadeout, holds done=false while
its timer runs, pins box/alpha once shaderLive, and damages the monitor. None of
this static evidence proves hooks/snapshot execution during the user's close.
No live closes or desktop manipulation were performed. No disabled setting was
found and no compositor animation settings were changed.

Verified shader defect: reversed opening alpha fell to 18% within roughly35–55ms,
while short downward movement was only a few pixels, then a second fade erased
it early. Close now keeps native opacity through departure0.12, smoothly reaches
18% by0.72, then fades to zero over0.65–0.98. Opening unchanged, duration240ms,
travel/rotation caps/window bounds unchanged. This fixes visible-travel timing;
it is NOT confirmation that a true snapshot/hook failure has been resolved.
User must test actual playback; if it still disappears instantly, further isolated
integration diagnostics are needed rather than more opacity tuning.

Build/GLSL and offline three-aspect alpha0/153/255 tests passed: exact initial
native RGBA/transparent final, premultiplied bounds, opening byte-identical at nine
samples. Only close link deployed/cache refreshed; live opening bytes unchanged.
Rollback rollback-close-visible.py uses pre-visible-close-live.txt; source backup
pre-close-visible-source.glsl. Labeled synthetic comparison close-visible-offline.gif
(about3.3x duration plus holds): file_00000000a33881f58a7f93b0f430e93f /
libfile_a69044c323248191af142ff92a36c860. Rebuild persistence pending; no full
activation/commits/pushes.

### Native outgoing lifetime alignment after continued truncation report

User reports visible start then disappearance before falling, shorter than240ms.
No further shader opacity changes. Read-only/source inspection establishes:
- native windowsOut/fadeOut were enabled at speed1.4 (140ms), default front-loaded
  easing; shader duration is0.24 seconds with elapsed/duration progress0→1;
- WindowFadeout::create initializes outgoing geometry/fade from those native leaves;
  done() requires zero alpha and completed animations; FadingOutState removes on done;
- plugin tags the snapshot, holds done false until its duration, pins box/alpha in
  draw, schedules monitor damage; real hook behavior remains unproven;
- source popin100% computes endSize=sourceSize and endPos=sourcePos.

Scoped integration fix aligns both native outgoing leaves to speed2.4/linear and
windowsOut popin100%. This removes the competing140ms native lifetime/fade/scale
schedule without disabling snapshot creation. Typed hl.animation calls succeeded;
read-back diff shows exactly windowsOut/fadeOut changed, opening preserved.
Scoped HM-owned Lua contains only those changes; declarative Nix evaluation matches.
Both shader files unchanged. configerrors empty. This is a source-backed mitigation
of competing native timing, not proof of the specific runtime hook failure/root cause.
User actual trial is still necessary.

A separate compositor with private runtime dir, no parent display/socket/session
bus, minimal explicit config and requested headless backend failed CBackend::create
before any test client; no live desktop fallback was attempted. Backend failure
and overlong private IPC path are logged in materialize/isolated-close/compositor.log.
Read of /proc/2589/maps was denied; no memory-map workaround used. No user windows
created/focused/closed/manipulated. No plugin hot swap or compositor restart.

Rollback helper rollback-outgoing-timing.py uses pre-outgoing-timing-live.txt,
checks current link identity before reverting, and restores only the two native
leaves. Source backup pre-outgoing-timing.nix. Before/after read-back JSON and
outgoing-source-evaluated.json are retained in materialize/. No new visual preview
because shader appearance is unchanged and runtime timing was not recorded.
Persistence still requires reviewed rebuild; no full activation/commit/push.

### Immediate fall, then fade

Owner requests faster visible downward motion after continued short-runtime report.
Close fragment departure delays are now zero. A separate ease-out cubic motion
clock finishes over86–106ms, while alpha remains native until100.8ms and the total
shader/native lifetime stays240ms. Numeric timeline fast-fall-timeline.json:
20ms47–55% drop,40ms76–85%,60ms92–97%,80ms99–100%; opacity100% through100ms,
92% at120ms,45% at160ms,16.5% at200ms,zero by240ms. These are shader values,
not a measurement of compositor playback. Distance/drift/rotation/bounds unchanged.

HM build/GLSL and offline wide/terminal/portrait alpha0/153/255 endpoint and
premultiplied tests passed. Opening byte-identical at nine samples and installed
opening bytes unchanged. Padded snapshot test has zero alpha outside window_rect
at five samples. Only close shader installed/cache refreshed; configerrors empty.
No live desktop window creation/focus/close/manipulation. Native outgoing240ms
linear settings retained. Runtime truncation remains unverified pending user trial.

Synthetic before/after fast-fall-offline.gif is slowed about3.3x plus endpoint holds:
file_00000000a6b481f5bd0cebaec583683e / libfile_8e4b4778e37c8191947f6a23d929d95e.
Rollback rollback-fast-fall.py / pre-fast-fall-close-live.txt; source backup
pre-fast-fall-source.glsl. No full activation/commits/pushes; persistence pending.


### Immediate-fall rollback and runtime investigation

The owner still saw fracture without visible fall and requested reverting the
last immediate-drop tweak. Source and live close shader now use the preceding
close revision. Opening and its accents are unchanged; the native outgoing
240 ms linear settings remain. Cache refresh and byte comparisons verified the
scoped rollback. No runtime fix is claimed. The source audit and proposed
approval-gated passive observation are saved in the task workspace as
`materialize/close-runtime-audit.md`. A private headless Cage parent started, but
nested Hyprland failed backend creation before any test client. No user window
was manipulated; loaded plugin binary identity and actual close-frame scheduling
remain unverified.


### Rotated-output close direction (live verified)

An explicitly authorized isolated-profile Chromium test on workspace 2 exposed
a coordinate error: DP-1 rotates the panel-oriented close snapshot, so texture-Y
travel appeared sideways. Three bounded recordings compared the original, a
rejected derivative approach, and the final mapping. The final recording shows
roughly 4–12 px of downward heading motion before it fades, versus 4–11 px of
sideways motion before the correction. Playback progresses over roughly 0.2 s;
this test did not establish an instant snapshot cutoff.

The shader maps screen down to texture +X for this host's 2560x1440 panel, which
`home/default.nix` configures at transform 1. The 3440x1440 unrotated panel retains
its prior output. The plugin exposes physical resolution but no monitor-transform
uniform: update this host-specific mapping if panel modes or rotations change.
The 240 ms declared/native timing, preceding opacity curve and restrained travel
remain. Opening/unrotated close byte comparisons, rotated endpoint/alpha checks,
GLSL and Home Manager build passed. Only the close leaf was deployed.

Test close used Browser.close over a dedicated CDP connection whose browser PID
was verified against the unique window, temporary profile and process start time.
No compositor close or focus dispatcher was used. No owned test windows remain.
Actual recordings and timestamp/heading measurements remain private in the task
workspace under materialize/live-close-*; they contain workspace-2 background
content and were not uploaded. The main monitor's runtime behavior and exact
loaded plugin binary remain unverified; reboot persistence still needs reviewed
system deployment.


### 200 ms visible fall

User confirmed the direction fix but wanted a perceptible 200 ms falling phase.
Close now spends 200 ms falling at native opacity, then fades over the final
40 ms of its 240 ms lifetime. Travel is 80–100% of min(height*0.13,72px),
with at most 3px sideways drift and the existing small rotation/bounds. The
rotated-panel mapping remains. Opening is unchanged.

The authorized workspace-2 Chromium recording measured approximately63px of
downward heading travel over roughly180–200ms, remaining strongly visible until
the final fade. These are video estimates, not instrumented GL timestamps.
The nominal120fps capture may duplicate frames. Offscreen nativealpha hold,
endpoints/premultiplication, unchanged opening, GLSL and HM build passed.
Only close shader deployed; source is represented here for a later rebuild.
No owned test windows remain, configerrors empty. Final recording is
materialize/live-close-b6f12c0843/workspace-2-200ms-fall.mp4 in the task workspace,
and was uploaded with explicit user approval to Library as
libfile_65caf5c9dffc819185e0a54407c50cc6. The earlier direction-only upload is
superseded. Monitor mapping dependency and pending reviewed system activation
still apply.


### Varied dramatic falling shards

Owner requested more varied and dramatic falling. Shards now release at seeded
0–18ms delays, finish at180–200ms, and use independent acceleration exponents
0.85–2.2. Ordinary drops are45–100% of min(height*0.16,90px); about20% use
90–100% of min(height*0.22,110px). For a500px window this is36–80px ordinarily
and99–110px for emphasized drops. Center drift stays within8px; rotations vary
up to0.17rad with edge displacement capped at18px. Original window bounds still
clip all output, preserving the limited footprint. Native opacity remains until
200ms, with the same final40ms fade and rotated-panel direction mapping.

Live authorized workspace2 recording confirms differentiated trajectories and
rotating separated pieces. Two text patches measure about60–69px downward near
the end, but correlation becomes unreliable across fractures/rotation; these
are selected feature measurements, not measured ranges for every shard. GPU
opening byte comparisons, native-alpha/endpoints/premultiplication and padded
window-bound checks passed; HM/GLSL passed. Opening livebytes unchanged, no
owned test windows remain, and configerrors empty. Only close shader installed.

Newest deliverable workspace-2-varied-shard-fall.mp4 is in Library as
libfile_5d7404c0d7c48191abf0e10a9cbce826. Local recording/metadata/feature tracks:
materialize/live-close-56ef9c43d7/ in the task workspace. It supersedes the
previous200ms uniform-fall clip. Source rollback pre-varied-fall.glsl and live
target pre-varied-fall-live.txt. Same monitor-configuration dependency and
pending reviewed system activation apply.


### Deeper drops with progressive transparency

Owner requested larger drops with fading during motion and full transparency
at completion. Ordinary drop is now55–100% of min(height*0.28,155px), with the
emphasized group using85–100% of min(height*0.38,200px). At500px height these are
77–140px and162–190px respectively. Existing seeded0–18ms departure, differing
acceleration,180–200ms completion, rotations and8px center-drift limit remain.
Fade begins per shard at36–67ms and smoothly reaches zero at240ms. The former
99%-progress cutoff is removed for close only; opening behavior is unchanged.

Actual authorized workspace2 recording confirms deeper divergent drops and
progressively fading shards, without an obvious endpoint pop. Selected heading
features move30–79px by video2.1167s; late correlation becomes unreliable as
alpha falls. Exact transparency and premultiplication are verified by GPU tests
through0.999 and1.0 progress, not inferred from video. Original-bound checks and
opening byte comparisons pass; shader/HM files build and GLSL checks pass.
No fullsystem rebuild/activation or commit/push. No owned test windows remain;
configerrors empty.

Newest clip workspace-2-deeper-fading-shards.mp4 is in Library as
libfile_8448cd76cae88191abb1b830b89b6562; local evidence is in task workspace
materialize/live-close-135c871bd2/. Rollback source pre-deeper-fade.glsl and
pre-deeper-fade-live.txt. Source is maintained in nix-config for later activation.
The fixed Blackmoon monitor mapping and main-monitor verification limitation
still apply.
