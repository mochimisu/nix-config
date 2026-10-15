# Blackmoon Acer bar and greeter layout

## Live Hyprland bar

The Acer bottom bar is Eww's `sysmon`, defined in
`machines/blackmoon/home/eww-sysmon.nix`, not Waybar. It retains its original
112px height, sensor/process/network content and polling commands.
Its width is now 100% of DP-1 (1440 logical pixels), with zero geometry offsets.
A dedicated `blackmoon-sysmon` layer namespace receives Hyprland order 20,
so its exclusive bottom zone is arranged before the vertical sidebar regardless
of startup order. The sidebar retains its right-side exclusive zone and ends
above the bottom bar. No desktop outer gaps were added.

The charcoal background is 60% opaque with layer blur. Values and all graph
traces are neutral white, with gray labels/date/separators; the subtle inset top
line is the only muted teal accent. Metric colors do not encode status or warning
levels. The user rejected the earlier per-metric teal/lavender colors. COMPUTE, COOLING and PROCESSES headings and thin vertical dividers group the
readings. Values use aligned monospace figures with smaller separate units.
Graphs use fine white lines with faint native area fill. Eww does not expose a
latest-reading dot, so no approximate marker is drawn. Both graph sections have
300px minima and expand into available space; the process section has a 340px
minimum, giving it more room than the first instrument-panel pass. Process names
use Montserrat with ellipsis and full-name tooltips, while CPU percentages occupy
a separate aligned Cascadia Code column. The clock and date share a right-aligned
LOCAL TIME block. The 90-second
history, polling and metrics remain unchanged. Graph class selectors target the
actual Eww widget classes.

Verified live on DP-1: bar `(3440,1888) 1440x112`; sidebar `(4858,-560) 22x2448`.
The bar is display-only: there are no click actions to change. Sensor updates,
clock and process content remain active. Hyprland's parser and Home Manager's
link-collision validation passed.

## SDDM only: staged rotation

`machines/blackmoon/sddm/rotate-displays.py` parses `xrandr --props` inside SDDM's
X11 setup hook. It identifies the Acer XB271HU and Dell AW3423DW by SHA-256 of
the first 128 EDID bytes, verified from this machine's DRM EDIDs. Xorg connector
names are resolved at greeter startup, never inferred from Hyprland's DP-1/DP-3.
The Acer rotates left, matching Hyprland transform 1; the Dell remains normal
and primary, with the Acer to its right. Missing or ambiguous Acer identities
leave the default layout unchanged. Errors are logged but do not block login.

The greeter still uses X11 and the existing centered, remembered-user theme.
GRUB, kernel console rotation, authentication and Hyprland output settings are
unchanged. Parser/selection tests include arbitrary connector names and missing
or duplicate identities. No SDDM server was restarted to test the real layout.

To install the built configuration for a later normal boot without switching
or restarting the current desktop:

```sh
sudo nixos-rebuild boot --flake /home/brandon/stuff/nix-config#blackmoon
```

The new SDDM setup runs when that installed generation starts its greeter.
Actual Xrandr mapping and physical orientation must be verified then; a build
and parser fixtures do not establish that the greeter has rotated successfully.
