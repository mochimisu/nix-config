# Blackmoon desktop styling

This pass extends the approved phone launcher's restrained mint, lavender and
pink accents to the existing desktop. `home/theme/sekai-palette.json` is the
single small palette consumed by the Blackmoon Hyprland/Mako module and the
Quickshell sidebar's Nix template. It is not a new shell or theme service.

## Scope

- Hyprland: 2px teal/lavender active borders, quiet inactive borders, 12px
  rounding, 4px inner/6px outer gaps, and low-opacity teal shadows. Shorter
  window/fade/workspace transitions replace the slow default movement; there
  is no looping border animation. Blur and layout policy stay unchanged.
- Existing sidebar: separate rounded, outlined cream modules for workspaces,
  title, tray, status and clock; dark teal text, mint active workspace pills,
  lavender inactive pills, and pink urgent states. Width, exclusive zone,
  status visibility, scripts, service subscriptions and interaction handlers
  are unchanged.
- Existing control/audio popups: cream surfaces, teal outlines, lavender
  buttons, mint selected states, pink caution states and a small three-color
  header rule. Rounded buttons have dark outlines and light inset edges,
  larger padding and stronger typography. No controls or new widgets are introduced.
  The rail remains 22px wide; on short screens the rail and popup contents scroll
  while retaining usable control sizes.
- Mako: opaque cream normal/low notifications, teal/lavender borders, and pink
  critical notifications with dark text. The existing output, anchor, font,
  notification ownership and behavior remain in place.

The style module is imported only by Blackmoon. Other hosts receive an empty
sidebar palette and retain the previous values. Phone launcher files, wallpaper
selection, lock/authentication configuration and service setup are not changed
by the sidebar pass. The subsequent [SDDM and media-card pass](../sddm/README.md)
adds a Blackmoon-only greeter appearance and Mako-based media feedback.

## Verification and previews

Blackmoon system derivation evaluation passed without building/activating the
system. Oasis appearance evaluation retained its original settings. Actual
sidebar and control popup QML rendered on an isolated RTX 4090/Xvfb display
with explicitly seeded sample state and disabled helper processes. The
non-themed popup matched the previous rendering apart from <=1/255 rounding
in 37 color channels; live status/tray values can vary between renders.
The modular refinement passed mocked click/geometry tests at 850px, 420px and
220px heights, including all ten control actions, workspace selection, audio
selection, and scrolling to the last of 40 audio outputs. These tests exercise
actual QML handlers with side effects replaced by recorded calls.
Helper functions, click handlers and tray long-press handlers were compared
against the parent commit and are unchanged. Main text/background pairs meet
4.5:1 contrast; warning text on pink is about 4.96:1.

A full headless/nested Hyprland preview could not initialize its Aquamarine
backend in this environment. The available software Cage compositor does not
implement layer-shell, so it cannot display Mako. Notification settings were
evaluated and passed Mako configuration loading up to the missing compositor
protocol; native notification and window decoration appearance still need a
real compositor check. The supplied comparison shows actual Quickshell
components, not a claimed full-desktop screenshot.

## Deployment boundary

Nothing from this styling pass has been applied live. The existing runtime
Super+Space phone binding remains intact. Future deployment must install this
branch's generated sidebar and Mako configurations, apply the Blackmoon
Hyprland appearance settings, and restart/reload those UI components. Keep
application/service changes outside that deployment.

A full Hyprland config reload currently restores the installed main-branch
configuration, including Rofi on Super+Space. Install this branch's launcher
wrapper and declarative binding as part of any later persistent deployment,
or reapply its existing runtime override after a scoped appearance update.
The branch remains isolated: no main merge, push, broad rebuild or activation
was performed.
