# Shared kirakira defaults

`common-gui.nix` supplies `variables.desktopStyle.kirakira.enable = lib.mkDefault true`
to its Home Manager users. `home/theme/kirakira` derives compatible per-effect
defaults and reuses the existing renderer/assets. Current common-gui hosts are
Blackmoon, Glasscastle, Espresso and Oasis. Gaia and standalone Home Manager
configurations do not inherit this opt-in.

The three effects are sidebar/tray menus, the bounded Quickshell volume sparkle
overlay, and the existing patched Mako entrance/exit animation. Menus and volume
require a native Linux Hyprland home and their corresponding existing shell/media
features. Notification animation requires an existing styled Mako owner. No extra
notification owner or bar is introduced. Base app/shell/phone styling already had
shared capability defaults; those defaults are unchanged. Blackmoon's separate
HyprWindowShade shader/workspace-card trial remains host-specific, as do monitor
geometry, audio exclusions, wallpaper providers and hardware configuration.

Ordinary assignments in a host Home Manager module override the defaults:

```nix
variables.desktopStyle.kirakira.enable = false; # opt out of the complete set
# Or, independently:
variables.desktopStyle.kirakira.volume.enable = false;
variables.desktopStyle.kirakira.menus.enable = false;
variables.desktopStyle.kirakira.notifications.enable = false;
```

`services.mako.package` also remains normally overridable. The explicit service
drop-in follows the resolved package. Its legacy `90-blackmoon-kirakira.conf`
filename is retained on all hosts so existing managed Blackmoon deployments are
replaced rather than left with an overriding stale command.

## Verification and activation

Focused Nix policy evaluation passes all four hosts, whole-set and per-effect
ordinary overrides, custom Mako package selection, and the non-GUI exclusion.
`tests/desktop/kirakira-policy.nix` takes `{flake}` and returns the asserted results.
Before/after monitor geometry, sidebar output selection and audio filters match.
Rendered sidebar and volume files build for all four hosts, including Glasscastle.
The three native popup grabs remain in generated menus, without the competing
Hyprland grab. The sidebar fixtures pass normal, compact and unthemed layouts.
The phone early-input changes are preserved. Volume QML/particle code and its
notification forwarding helper were moved unchanged; all hosts resolve the same
previously tested Mako package `/nix/store/iz3rd2m9sxfym1l0xp05wx2apw235axr-mako-1.11.0`.

Generated-file evaluation initially required the Catppuccin palette derivation;
realizing that dependency and allowing its import resolved the affected-host checks.
An extra standalone Comet check is blocked by its ARM Catppuccin palette derivation
(`/nix/store/8gzsns5r4gf6i4ypbmqvq14yj5rcyjjs-catppuccin-palette-0-unstable-2026-03-21.drv`):
Blackmoon is x86_64 and no ARM builder was used. Comet does not import common-gui;
its complete configuration evaluation is not claimed. Cove standalone exclusion
was verified. No full NixOS/Home Manager generation build, fleet activation, live UI
reload, compositor restart, commit or push was performed for this migration.
Blackmoon's already-running effects remain untouched; other hosts are prepared,
not activated. Apply through each host's normal reviewed NixOS/Home Manager
activation when desired. Mako replacement can clear notifications, so schedule
that activation accordingly. These checks do not establish live renderer behavior
on other machines or a successful full-system build.
