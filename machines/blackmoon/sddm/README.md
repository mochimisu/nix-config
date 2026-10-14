# Blackmoon greeter and media cards

This branch opts Blackmoon into `sekai-blackmoon`, a small Qt 6 SDDM theme.
The background is wallpaper-free: a cream surface, clipped/slanted pastel
bands and an open lavender ring are drawn directly in QML. The clock uses
individually tilted mint/lavender numerals with thick dark outlines, pale inset
edges and an offset silhouette. Outlined capsules, offset lavender card layers,
a slanted pink underline and chunky buttons echo the saved reference frame
without copying its wallpaper or introducing a new rendering dependency. No image asset, wallpaper setting
or Home Manager wallpaper dependency is included in the SDDM theme. The palette
comes from `home/theme/sekai-palette.json`.

The existing SDDM 0.21.0 Qt 6 package and X11 display-server selection remain.
Only the theme selection/package changes: PAM, account policy, autologin,
session discovery, authentication and security configuration are untouched.
The theme passes the selected session index to SDDM, displays failure/info
messages, clears a failed password, prevents duplicate submissions, exposes
keyboard layout and Caps Lock state, and keeps standard SDDM power actions
when the greeter reports them available. It uses keyboard-focus outlines,
accessible names and 40px+ controls; compact screens scroll focused controls
into view. The password always remains masked.

## Account selection and test mode

The theme uses SDDM's `userModel` instead of a hardcoded account: choose the
remembered name when available, otherwise `lastIndex` (or the first listed
account). Start with the account summary and password focus; “Change” opens
the account list, and “Other user…” permits a manual/directory account. With
no listed users, manual username entry remains available. A remembered account
not in the visible list is preserved. Account changes clear any entered password.

SDDM 0.21.0's test mode uses the real local account model, not dummy users.
`lastUser` comes from the SDDM account's `state.conf`; the ordinary-user preview
cannot traverse this host's protected `/var/lib/sddm` directory, so its remembered
name is empty. The previous theme used only that string and thus showed a blank
username. The normal greeter can use its own remembered state. The new model
fallback also makes an unremembered/first-run preview useful. `RememberLastUser`
remains at SDDM's existing default (true); no config override, autologin or
permission change is made.

Verified against installed Catppuccin/Maldives initialization and upstream
[0.21.0 UserModel](https://github.com/sddm/sddm/blob/v0.21.0/src/greeter/UserModel.cpp),
[GreeterApp](https://github.com/sddm/sddm/blob/v0.21.0/src/greeter/GreeterApp.cpp), and
[configuration defaults](https://github.com/sddm/sddm/blob/v0.21.0/src/common/Configuration.h).
Tests cover first listed user, remembered second user, switching accounts,
empty model/manual input, remembered unlisted account, failed login clearing,
and password focus at normal/compact sizes. Test-mode previews have no daemon
socket and do not authenticate a real session.

## Media cards

`home/theme/media-osd` is a short-lived client of the existing Mako server,
not another daemon. Blackmoon's five volume/brightness media bindings and
sidebar controls call it. Volume steps remain 5%, capped at the sidebar's
existing 150%; the displayed percentage may exceed 100 while the progress
fill caps at 100. Mute is explicit. Concurrent key presses are serialized and
Mako's synchronous hint replaces each category's previous card. Transient OSDs
expire after 1.6 seconds and do not enter notification history.

Brightness explicitly targets the backlight class, avoiding keyboard LEDs.
Blackmoon had no `/sys/class/backlight` entries during inspection; its cards
therefore report that no supported backlight exists. DDC monitor control is
not added. No volume, mute or brightness state was changed during testing.
The phone launcher's own slider remains unchanged.

Mako retains notification ownership, normal notification anchoring on DP-1,
application actions and urgency behavior. Cards use dark teal outlines,
cream/pastel surfaces, 32px icons, bold headings and padded rounded corners.
The OSD includes local outlined SVG icons and Mako's supported value fill;
Mako does not implement entry animation or the sidebar's nested inset border.
No notification-stack replacement is included.

The stronger graphic refinement changes the visual components and spacing;
session/login handlers remain unchanged. Controls retain 40px+ targets, obvious
keyboard focus and compact scrolling. Blackmoon evaluation, the focused theme
build, mocked greeter behavior tests and actual SDDM test-mode previews passed
at 1280×800 and 800×600. The visual reference is the previously inspected
Project Sekai rice video frame, especially its tilted outlined clock, inset
module rims and capsule controls. The slanted bands and offset layers are an
interpretation for the wallpaper-free login composition.

## Validation and deployment

- Blackmoon system derivation evaluates; focused theme and OSD packages build.
- Six mocked shell tests cover volume/mute, brightness success/failure,
  amplified volume, invalid actions and rapid key repeats.
- Actual SDDM test-mode previews run on private Xvfb displays at 1280×800 and
  800×600, with no credential entry. The session dropdown was opened there.
- Separate mocked QML tests check selected-session forwarding, duplicate
  submission prevention, failure clearing/focus, layout selection and compact
  focus visibility. They do not claim authentication end-to-end coverage.
- The generated Mako configuration passes parsing, then stops at the absent
  private Wayland display. Native Mako appearance/placement remains unverified:
  the available isolated compositor lacks layer-shell and nested Hyprland
  could not initialize. No synthetic image is presented as a Mako screenshot.

Nothing here is activated live. To deploy later, install this branch's theme,
OSD package, sidebar source, media bindings and Mako config. Reload Mako and
restart the sidebar as part of an approved scoped deployment. SDDM should pick
up its new theme at a future normal greeter start; do not restart the display
manager while a session is in use. Preserve the current runtime phone binding,
or install its declarative branch version before a full Hyprland config reload.
No merge, push, broad rebuild, logout or display-manager restart was performed.

References: [Mako configuration](https://github.com/emersion/mako/blob/v1.11.0/doc/mako.5.scd),
[SDDM theme API](https://github.com/sddm/sddm/wiki/Theming).
