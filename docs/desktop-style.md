# Desktop style ownership

The approved application and shell styles are shared defaults, selected by
capability in `home/theme/default.nix`, not by hostname. Typed options remain
independently overridable in `vars.nix`; their bare defaults are false when the
policy module is absent.

| Target | App colors | GTK/Qt integration | Mako appearance | Shell / phone / media | SDDM | GRUB / console |
| --- | --- | --- | --- | --- | --- | --- |
| Blackmoon, Oasis, Espresso, Glasscastle | yes | yes | yes | yes | yes | yes |
| Standalone `brandon` home | yes | yes | yes | no | no | no |
| Cove (SteamOS) | yes | no | no | no | no | no |
| Comet (nested ARM SteamOS) | yes | no | existing private Mako | no | no | no |
| Gaia / Darwin | no | no | no | no | no | no |

Comet's row describes configured policy; full evaluation/build requires an ARM
builder because Catppuccin imports a generated palette. It is not a runtime
certification. Cove and Comet explicitly opt out of native GTK/Qt integration,
shell styling, the phone and media feedback. Their SteamOS sessions and plugin
environments remain owned by SteamOS. Comet's software renderer has not been
validated for the launcher's shaders/video, so flat mode alone is insufficient.

Home defaults require a Linux GUI. App-local colors cover managed Kitty, Rofi
and Neovim. GTK/Qt integration additionally requires an existing GTK desktop and
excludes externally owned/nested sessions. Notifications require existing Mako;
this module never enables a notification daemon. Shell/phone defaults require
native managed Hyprland; media feedback additionally requires Mako. Standalone
Home Manager cannot own system greeters or bootloaders.

`desktop.nix` imports `system/desktop-style`: the greeter defaults on for existing
SDDM, and boot/console appearance for existing SDDM plus GRUB. Gaia does not import
the desktop module. No compositor, SDDM or bootloader is newly enabled by styling.
The greeter and boot label use each host's name. Touchscreen greeters load the
existing Qt Virtual Keyboard only when the host already enables it; the form
scrolls above the keyboard. Existing X11/Wayland selection, keyboard layout,
SDDM/PAM policy and touchscreen patches remain host-owned.

| Owner | Responsibility |
| --- | --- |
| `home/theme/apps.nix` | App-local colors and optional GTK/Qt integration |
| `home/theme/shell.nix` | Hyprland appearance/motion |
| `home/theme/notifications.nix` | Existing Mako appearance |
| `home/theme/media-feedback.nix` | Media feedback package and Mako categories |
| `home/theme/palettes.nix` | Charcoal app tokens and illustrated shell tokens |
| `home/apps/quickshell/phone-launcher` | Launcher rendering, IPC and service |
| `home/apps/quickshell/sidebar` | Shared sidebar, palette/media settings |
| `system/desktop-style` | Shared greeter and GRUB/console appearance |
| `machines/blackmoon/{home,sddm}` | Wallpaper, sensors, audio exclusions, displays and EDID rotation |

The two palettes intentionally differ. Legacy generated names (`blackmoon.rasi`,
`sekai-blackmoon`, `blackmoon-grub-theme`) stay stable for installed references;
they no longer determine host scope. The Acer Eww bar remains Blackmoon-only.
No monitor names, EDIDs, rotation, sensor names or audio exclusions are copied.
Hyprlock remains the existing separate shared lock configuration.

The launcher accepts an optional `variables.desktopStyle.launcher.wallpaperPackage`.
Blackmoon supplies its Skwd package. Other hosts get a neutral header; enabling
the phone does not install a wallpaper daemon or copy Blackmoon's media.

## Overrides and rollout

Disable individual Home Manager features with
`variables.desktopStyle.<apps|notifications|shell|launcher|mediaFeedback>.enable = false`.
Disable system appearance with `desktopStyle.greeter.enable = false` or
`desktopStyle.boot.enable = false`. Hardware policy remains in the host modules.

Run `python3 scripts/validate.py` and the [isolated desktop tests](../tests/desktop/README.md).
The host matrix test asserts native defaults, Gaia exclusion and Cove ownership.
Run its optional Comet assertion on an ARM-capable builder. Tests use private
displays and mocked actions, never real authentication or power operations.
Oasis's standalone Hyprland verifier has existing Hyprgrass registration errors;
check touch/plugin behavior in its real session after the user's normal rollout.

Changes are not deployed by building. After publishing/transferring the commit,
update Oasis's checkout and build `.#nixosConfigurations.oasis.config.system.build.toplevel`.
For a rollout that leaves the running session alone, use
`sudo nixos-rebuild boot --flake .#oasis`, then reboot when convenient. This applies
the system and Home Manager generation on the next boot. Inspect touch keyboard,
phone input, notification placement and GRUB on that hardware. Do not restart
SDDM during an active session. Existing generations remain available for rollback.

See [historical trial notes](history/blackmoon-style-trials-2026-10.md) for dated
experiments; current module files and this document define operational policy.

## Validation record — 2026-10-15

- Full Blackmoon and Oasis system builds passed without activation; Cove's Home
  Manager build passed. All native/Darwin policy assertions and bare-option tests
  passed. Export validation passed 13/14 targets; Comet remains blocked by its
  pre-existing ARM Catppuccin import-from-derivation dependency.
- Blackmoon's 70 managed home files and generated GRUB assets are byte-identical
  to the prior style generation. Oasis exports the expected app/GTK/Qt files,
  launcher service, styled sidebar/Mako and Hyprland motion. Cove changes only
  managed app colors plus the derived font-profile path.
- Isolated QML/Eww/input tests passed, including normal/compact greeters with and
  without Qt Virtual Keyboard. A second run with Oasis's patched keyboard package
  and compact style passed. No actual authentication or physical touch was tested.
- Blackmoon's generated Hyprland config passes its pinned verifier. Oasis's
  verifier still reports four existing `plugin.hyprgrass` registration keys;
  plugin behavior requires its real session. No monitor/EDID policy was changed.
- Nothing was deployed, pushed, restarted or rebooted by this work. Real boot,
  greeter authentication, touch/plugin behavior and notification placement remain
  rollout checks on the target hardware.

## Blackmoon dial greeter — updated 2026-11-07

Blackmoon alone uses a blue dial variant of the existing SDDM theme.
The original geometry reference was monochrome:
Reference: https://www.reddit.com/r/QuickShell/comments/1tb88nq/made_some_pretty_lockscreen_themes_for_quickshell/
The public video is 95.033 seconds long; the requested -0:22 frame is at
73.033 seconds elapsed. The frame was actually extracted and viewed. It has a
black background, faint radial minute markings, large white hour, rounded
minute/second capsule, spaced date text, and a right-side login area.

The current color reference is the blue dial of the [A. Lange & Söhne 1815,
220.037](https://www.alange-soehne.com/us-en/timepieces/1815/1815/1815-in-750-pink-gold-220-037).
The deep-blue surface (`#102038`) has a broad off-center radial gradient from
steel blue (`#243e5a`) at the upper left into midnight navy (`#080f20`), with
a quieter matching gradient in the time capsule. The login background is
transparent so the dial lighting continues behind it. These colors and white seconds railway notches
are an interpretation of the reference photograph, not a manufacturer color specification.

`system/desktop-style/greeter.nix` selects `DialStyle=true` and the blue palette
only for hostname `blackmoon`. `sddm/Main.qml` reuses the existing account,
password, session, keyboard and power controls. Other hosts retain the illustrated
palette. PAM, session launching, EDID rotation and Hyprlock are unchanged.

Deliberate approximation: the SDDM form stays expanded and readable, including
session/layout selectors, instead of the reference's almost invisible idle prompt
and top-edge actions. The login is centered, with the date to its right. Three
concentric wheels run from hours (00–23) inside to minutes and seconds outside.
Each wheel places its current index at three o’clock underneath its readout field;
all use the same wall-time snapshot sampled at display cadence by `FrameAnimation`.
Fractional hours, minutes and seconds produce continuous linear motion (one
revolution per 24 hours, hour and minute respectively), with no tick pauses, easing
or accumulated drift. Midnight wraps to an equivalent angle without a reverse sweep. Only the seconds wheel has notches and a double border;
hour and minute wheels keep a single border. Circle strokes are 2 px analytic
Qt Quick Shapes curves, avoiding polygonal edges during rotation; seconds
notches explicitly enable antialiasing. Ring labels share the corresponding
readout font (40/26/20 px on desktop, 32/24/18 px compact); the hour is moderately
larger than minutes. Hour labels use two-hour spacing, four-hour on compact
displays, to keep the larger type legible. The capsule includes the hour and uses fixed
field widths, centered text and tabular numerals. Narrow displays place the clock
above the scrollable form and reduce inner-wheel labels to avoid crowding.
All shapes are original QML; no upstream
code, fonts or wallpaper were downloaded into the theme.

Original validation: full Blackmoon system and isolated theme builds; private Xvfb QML
checks at 1920x1080, 3440x1440, 1280x800 and 800x600; existing remembered-user,
session, duplicate-submit, failure-clear and keyboard checks; legacy touchscreen
variant at 800x600. Authentication and power actions are mocked. Real login and
physical hardware remain next-boot checks. No activation or SDDM restart.

November 7 iteration: theme derivation built successfully; QML checks and rendered
previews passed at 3440×1440, 1920×1080, 1280×800 and 800×600, plus the
legacy touchscreen variant at 800×600. Added ring order/time-index, midnight
rollover (including constant angular speed across midnight and subsecond frame updates), fixed readout geometry and
centered-login checks. Tests ran through
`isolated-desktop-test` with private filesystem/network X11 sockets and read-only
host mounts; host X11 socket names/inodes were unchanged. No system activation
or SDDM restart was performed. Real PAM login remains a next-login check.

Apply with the normal rebuild, or stage for next boot without switching the
running desktop: `sudo nixos-rebuild boot --flake /home/brandon/stuff/nix-config#blackmoon`.
This stages the whole current checkout, including any other pending changes;
review those before deployment. Reboot only when convenient.
