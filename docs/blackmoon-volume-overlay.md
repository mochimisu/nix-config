# Blackmoon volume overlay — 2026-10-26

Implemented in `home/theme/kirakira/volume-overlay/{default.nix,notify.py,shell.qml}`. As of October 28, compatible homes on hosts importing `common-gui.nix` enable it by default; see [shared kirakira policy](shared-kirakira.md). Existing media client, keybindings and audio control are unchanged. Mako's normal-volume category hook forwards each notification, including synchronous replacements, to a small Quickshell service; audio-error messages remain in Mako.

The dark existing app palette uses teal/lavender/warm-white four-point stars. The card sits 38 logical pixels above the usable bottom edge. The hook queries the focused output and its reserved bottom inset on each notification; Qt handles scale and rotation. No fixed connector assumption. Empty input region and no keyboard focus. 24 particles per event, maximum 72, lifetime 760ms; repaint timer stops with zero particles. Card holds 1600ms after each event, fades for 160ms, then unmaps.

## Validation

- Python syntax and Nix module parse pass. Existing media client: all six tests pass.
- Actual QML load succeeds without warnings; active `sekai-volume-overlay.service`.
- Synthetic Mako notifications 45% → 50% → 45% → muted incremented serial on every replacement, with particle counts 24/48/72/72.
- Twenty rapid synthetic IPC events stayed at the 72-particle ceiling.
- Particles cleared while the card was still visible; timeout unmapped the surface.
- DP-3 3440×1440 and rotated DP-1 logical 1440×2560 tested. Portrait bottom reserved area 112px was honored. Both actual outputs are scale 1; fractional-scale behavior follows Qt logical geometry but was not tested by changing the user's display settings.
- Original and final actual volume both 0.55. Focused application unchanged. No actual volume changes were made.
- Screenshots and 3.6s animation captured under `/home/brandon/Documents/Codex/2026-10-26/task-2/evidence/`; validation and source hashes included there.

## Scoped activation and limitation

No NixOS/Home Manager switch. Only overlay service added/enabled and Mako configuration reloaded. Running files are under `/nix/store/hk578n8s3b7cyvanmcnl72wcqi8kxja2-home-manager-files`, linked through home-manager-files paths to preserve collision detection. The store directory is protected by the indirect GC root `~/.local/state/sekai-volume-overlay/home-files`. These were rendered from durable sources using installed tool paths. Running QML exactly equals durable QML after palette substitution: SHA256 `6acd1908d78e6602bae15111d18e5106a4e9fd949d269a7be25138023243af1b`.

A full flake evaluation/build was not completed: existing user lock changes triggered unrelated uncached toolchain source derivations. The attempts were stopped; collected exit logs additionally show a pre-existing TinyCC source hash mismatch cascading into catppuccin-palette evaluation (expected `sha256-MRuqq3TKcfIahtUWdhAcYhqDiGPkAjS8UTMsDE+/jGU=`, received `sha256-ZAL32EP904E+TLyLluC8j+hjep7Xnbj4znbrvf/CUOw=`). Nix ignored a non-trusted post-build-hook override; no system activation occurred. The selected UI files were instead added to the store without a build. Do not claim the full flake build passed or that the general Home Manager generation was switched.

## Rollback

Run `/home/brandon/Documents/Codex/2026-10-26/task-2/rollback-volume-overlay.sh` as Brandon to stop/disable only this service, restore the prior Mako symlink, reload Mako, and remove only the overlay home links. Review the old Mako path if subsequent unrelated Mako changes have occurred. Durable opt-out after the shared migration: set `variables.desktopStyle.kirakira.volume.enable = false` in the host home module; do not reset other dirty files or AGENTS.md. No commit was made; new module files are staged for flake visibility.
