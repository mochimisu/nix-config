# Blackmoon application palette

`machines/blackmoon/home/app-palette.json` owns the charcoal application surfaces,
pure-white normal text, teal selections and lavender secondary accents. Its
`app-style.nix` module is imported only by Blackmoon. The illustrated Sekai
phone/sidebar/Hyprland/SDDM palette remains separate.

Coverage:

- GTK3: upstream adw-gtk3-dark with named-color overrides; replaces the old
  Thunar transparency rules with opaque application content.
- GTK4: dark preference and named-color CSS overrides; no forced GTK3 theme.
- Qt5/Qt6: qt5ct/qt6ct plugins, Fusion style and explicit QPalette colors. Set
  Fusion inside qtct; do not set QT_STYLE_OVERRIDE, which bypasses integration.
- Kitty: dark #181d21 background at the user’s restored 0.6 opacity, #ffffff foreground, coordinated ANSI colors,
  teal selection/cursor and lavender secondary accents. Shared SSH OSC color
  hooks and all non-appearance settings remain unchanged.
- Rofi: imports the existing mochi layout and overrides only palette variables;
  menu background is 93% opaque.
- Mako: #181d21 backgrounds at 60% opacity, matching Kitty, with opaque white
  text/icons and a Hyprland blur rule scoped to the verified `notifications`
  namespace. Teal borders/progress, lavender low-priority accent and red critical
  border remain opaque; notification routing and controls are unchanged.
- Neovim: retains Ayu and plugins, overriding content/selection/popup colors and
  selected syntax groups. Airline retains its existing theme.

Validation: Blackmoon Home Manager build passed; real GTK3, Qt5, Qt6 and Kitty
renders were inspected on an isolated display. Effective Rofi theme parsing and
Neovim Normal/Visual highlight reads passed. White text contrast is 16.98:1 on
background, 14.39:1 on surface and 6.42:1 on selection.

The initial live application linked only the generated appearance files, shell
session-variable files and theme assets, updated four desktop-interface dconf
keys, and set Qt environment values in Hyprland and the user manager. Mako was
reloaded; the hidden phone daemon was restarted to inherit the Qt environment.
No full activation, logout, desktop restart or SSH terminal recoloring occurred.
Normal future rebuilds own the same settings durably.

Existing app processes can retain old settings/environment; reopen them as needed.
GTK4/libadwaita was not visually checked. Self-themed apps, browser content and
sandboxed apps may ignore these desktop colors. Existing Kitty windows are not
force-reloaded because that could disturb SSH-specific color distinctions.

Blackmoon motion: window entry uses `popin 88%` at 320 ms, exit `popin 94%`
at 200 ms, layout moves 380 ms, and workspace `slidefade 30%` at 400 ms.
The easing curve `(0.22, 1, 0.36, 1)` settles without overshoot. The phone
launcher retains its own rigid pull-in; these changes do not alter its QML.
The generated Lua passed the installed Hyprland parser and a configuration-only
live reload; effective animation values were checked after reload. A synthetic
Mako notification confirmed the background treatment with no private content.
