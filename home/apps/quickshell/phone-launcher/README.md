# Phone launcher

The shared Home Manager module is imported by `home/theme/default.nix` and enabled
with `variables.desktopStyle.launcher.enable`. Only Blackmoon currently opts in.
The optional `launcher.wallpaperPackage` supplies Skwd; an absent/unavailable
provider gives a neutral header. Other machines do not need a Skwd argument.

The persistent `sekai-launcher.service` starts hidden with the graphical session.
Super+Space and Super+Alt+Space toggle the same instance through IPC; other Rofi
menus are unchanged. `KillMode=process` preserves applications launched from the
phone during a launcher-only restart. Files, wrapper and unit are Nix-store owned;
there is no workspace script or runtime keybinding override to maintain.

Each show resolves the current pointer output, accounting for scale, rotation and
negative coordinates. A canceled/superseded context query cannot reopen an old
request. Outside dismissal consumes both press and release; reopening cancels an
in-progress close. Search ranks exact names before prefixes, metadata and fuzzy
matches. Escape returns from search, then closes from home.

The header follows the selected output's current image/video. Its separate muted
video decoder pauses while hidden. Text stays outside the 3× media/mask texture.
`SEKAI_LAUNCHER_FLAT=1` removes perspective and entrance motion; it does **not**
remove QtMultimedia or the mask effect and is not a software-renderer compatibility
mode. Nested desktop enablement is guarded pending renderer and lifecycle testing.

Run the reproducible checks in [tests/desktop](../../../../tests/desktop/README.md).
They exercise actual QML on private displays with side effects disabled, plus
pointer geometry and search ranking. Prior live Blackmoon validation and media
behavior are recorded in [Blackmoon launcher](../../../../docs/blackmoon-phone-launcher.md).
Intermediate experiments are preserved in the [historical notes](../../../../docs/history/blackmoon-style-trials-2026-10.md).

Reference inspiration: https://www.reddit.com/r/LinuxPorn/comments/1x36scr/project_sekai_inspired_rice/
