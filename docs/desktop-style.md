# Desktop style ownership

Home Manager imports `home/theme/default.nix`. Four independent typed settings in
`vars.nix` default to false:

```nix
variables.desktopStyle = {
  apps.enable = true;
  shell.enable = true;
  launcher.enable = true;
  mediaFeedback.enable = true;
};
```

Only `machines/blackmoon/home/default.nix` enables them today. This extraction does
not opt other hosts into a new appearance or activate anything. All features require
a Linux GUI home; shell/launcher require Hyprland, media feedback requires the
existing Mako owner, and the launcher is guarded against nested sessions for now.
An opt-in is explicit configuration, not a claim of runtime compatibility.

| Owner | Responsibility |
| --- | --- |
| `home/theme/apps.nix` | GTK, Qt, Kitty, Rofi and Neovim appearance |
| `home/theme/shell.nix` | Hyprland appearance/motion and Mako appearance |
| `home/theme/media-feedback.nix` | Media feedback package and Mako categories |
| `home/theme/palettes.nix` | Charcoal app tokens and illustrated shell tokens; shared rail text derives from app text |
| `home/apps/quickshell/phone-launcher` | Launcher rendering, IPC and service |
| `home/apps/quickshell/sidebar` | Shared sidebar rendering; explicit palette/media settings |
| `machines/blackmoon/home` | Enabled features, audio exclusions, sensor bar, display/wallpaper ownership |
| `machines/blackmoon/{sddm,boot-style}` | Host-only greeter, EDID rotation and boot theme |

The two palettes intentionally differ. Existing generated theme names such as
`blackmoon.rasi` remain stable to avoid breaking installed references. Appearance
settings do not own physical monitor names, EDIDs, sensor names or audio-device
exclusions. `variables.quickshellSidebar.blockedAudioDescriptions` is supplied by
the host. The Acer bar remains host-specific, including its 112px four-column layout.

The launcher takes an optional `variables.desktopStyle.launcher.wallpaperPackage`.
Blackmoon supplies its existing Skwd package. No provider means a neutral header;
it does not install a wallpaper daemon. Shell appearance and media actions are
independent: enabling shell colors alone does not change volume-key behavior.

## Validation and rollout

Run `python3 scripts/validate.py` for all exported derivations and the isolated
[desktop tests](../tests/desktop/README.md) for actual widgets/input. Before and
after a refactor, compare generated Home Manager files, package membership and
screenshots; store-address changes and reordered non-overlapping declarations
must be explained, not silently ignored. Never replace Home Manager links with
resolved leaf-store paths during scoped deployment.

Blackmoon is the reference runtime. Oasis and Cove Home Manager builds can be
checked on x86 without deployment. Oasis's standalone Hyprland verifier reports
Hyprgrass option-registration errors, so validate plugin behavior in its actual
session before rollout. Cove currently has no managed Hyprland session: app
styling is the appropriate first scope, not a copied login/desktop stack.

Comet is ARM SteamOS with a private nested desktop and software-rendered sidebar.
Its Catppuccin import-from-derivation requires an ARM builder, blocking full
validation on x86. Keep native SteamOS Qt/plugin environments and session
ownership separate. The launcher's flat mode does not remove its shader/media
requirements. Renderer/lifecycle checks must precede any Comet launcher opt-in.
No boot theme, EDID mapping, notification owner or system service should be copied
from Blackmoon as part of app-style enablement.

See [historical trial notes](history/blackmoon-style-trials-2026-10.md) for dated
experiments; use the current module files and this document for operational work.
