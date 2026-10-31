# Blackmoon notification kirakira rendering

Blackmoon keeps Mako 1.11.0 as its notification owner. `home/theme/kirakira/notifications.nix` selects the shared opt-in package in `pkgs/mako-kirakira`. The package applies a version-guarded Cairo rendering patch; it does not replace the notification service, introduce another bar, or change the shared sidebar.

## Installed refinement — October 27, 21:38 UTC request

The user requested more embellishment, less uniform motion and greater sparkle distance (Sentinel_cbb4de910f688191be055645d64d271d). The durable patch now emits 28 deterministic, notification-seeded sparkles per card, with varied sizes, rotations, speeds, delays and lifetimes; asymmetric outward curves reach 42 logical pixels. Four delayed corner glints add layered white flashes to teal/lavender/warm-white stars. The readable card retains its short 280 ms, 12px entrance and 180 ms, 8px exit. Entrance decorations finish within 780 ms; exit decorations within 560 ms. No idle animation is scheduled.

Rendering reserves at least 64px side corridors and 24px top/between/bottom space. Stars remain outside readable card interiors; exiting snapshots and glints are clipped away from surviving card rectangles, preventing old text from showing through translucent fills. Mode changes cancel all lingering snapshots immediately, including already-closed notifications. At most eight clipped snapshots and 224 stars per surface exist; excess cards render normally. Effects request frames at most every 20 ms while active. Surface destruction cancels the timer and frees snapshots; scale changes invalidate snapshots.

**Refinement activated October 27 at 21:53 UTC after fresh approval** (Sentinel_1b502ccb5c548191b26da1aa82bf83cb). Only Mako was restarted, clearing the approved outstanding notifications. The sole Mako process and notification D-Bus owner are PID 126765, running `/nix/store/iz3rd2m9sxfym1l0xp05wx2apw235axr-mako-1.11.0/bin/mako`. Full host package evaluation resolves to this exact executable. Default mode was retained; the live idle check recorded zero CPU ticks over two seconds. The existing sidebar remains PID 2696, with no duplicate bar. The build is rooted at `blackmoon:/home/brandon/Documents/Codex/2026-10-26/task-3/notifications-work/refined-final-result`.

The exact refined build passes the private lifecycle/action suite at 1× and 2×. `tests/notifications/check_pixels.py DIRECTORY [--scale 2]` additionally verifies blank DND/finished-exit frames and unchanged surviving text during stacked exits. All 66 preview source frames fit their reserved surface bounds (observed painted x 344–790, y 9–110 inside an 800×600 private display). No live desktop input or visible test notification was used for the refinement.

Mako still owns delivery, replacement IDs, actions, critical urgency, grouping, history, DND, timeouts and input. Its native callbacks are unchanged. Input hotspots follow the small entrance translation; closing snapshots have no actions/input regions. Notifications still present but hidden by criteria (including DND) are removed immediately without an exit echo. Invisible volume-forwarding notifications never acquire a snapshot; the existing volume overlay and its hooks are untouched. The overflow summary retains Mako's normal rendering.

## Verified

- Exact durable patched package builds successfully with Mako's warnings-as-errors configuration.
- Private headless Sway and a private D-Bus session: entrance/middle/settled/exit frames inspected, stacking and critical border preserved; replacement returns the same ID; a mocked action is invoked; DND hides and restores; expiry removes notifications; a 16-notification burst clears correctly.
- 1× and 2× logical scaling pass. Idle test measured zero CPU ticks over one second after effects ended. This is a bounded check, not a comprehensive benchmark.
- Tests use synthetic notifications only, deny the system bus, disable Xwayland and stop their private compositor/daemon afterward. No live screenshots, input automation, extra bars or compositor/session restart were used for this notification task.
- Current Mako has no hover-specific animation in its renderer. Existing pointer/action processing is unchanged; physical hover/action testing on the user's desktop was intentionally not performed.

Run `tests/notifications/test_kirakira.py --mako /path/to/patched/bin/mako --sway /path/to/sway --output /tmp/kirakira-results [--scale 2]` with `notify-send`, `grim` and `dbus-run-session` on PATH. The script establishes its own private bus and headless display; do not replace it with tests on the running desktop.

## Scoped deployment and rollback

The persistent service override is Home Manager-owned at `~/.config/systemd/user/mako.service.d/90-blackmoon-kirakira.conf`, linked through `/nix/store/phni6acg5i43xy70bc7vqc9rsxyfq6zi-home-manager-files`. GC roots for both the refined package and files live under `~/.local/state/sekai-notifications/`. The imported host module declares the same override. No runtime override remains, and no full generation switch or unrelated sidebar deployment was performed.

Full host evaluation of `services.mako.package.outPath` matches the running refined package. Full managed-file evaluation previously encountered an unrelated Catppuccin palette import-from-derivation with builds explicitly disabled; no unrelated build was triggered. The narrowly deployed drop-in follows the notification module's declared text. The deployment script retains guarded recovery to version 1 if service startup fails.

The guarded live rollback script is `blackmoon:/home/brandon/Documents/Codex/2026-10-26/task-3/notifications-work/rollback-mako.sh --restart-authorized`; it removes only this exact owned drop-in, reloads the user manager and restarts Mako. Restarting clears current in-memory notifications/history, so obtain approval again if there is new outstanding work. Durable opt-out sets `variables.desktopStyle.kirakira.notifications.enable = false` in the host home module; never reset the dirty host module wholesale. No commit or push was made.

Synthetic preview updated in place: Library `libfile_74f445e4347c81918a735c195c2ddf49`, `/Blackmoon-kirakira-notifications.gif`, **version 1**, file ID `file_000000002f0081fd9706969debcc9b1c`, 205373 bytes. The GIF is 480×150, with 40 stored frames coalesced from 66 private-rendered source frames. It contains no live notification or desktop content. Local verification inspected decoded frames, bounds and Library upload identity. Refinement test evidence lives in `notifications-work/refined-final-evidence` and `refined-final-evidence-scale2`; the earlier evidence directories describe the earlier version 1.


October 28 shared-policy migration: [common-gui kirakira defaults](shared-kirakira.md). The patched binary and renderer are unchanged. Migration itself performs no live activation.
