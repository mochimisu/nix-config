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
