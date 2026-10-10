# Comet (Steam Frame)

Comet runs Valve SteamOS with upstream Nix, not NixOS. Its standalone Home Manager
target is `homeConfigurations."steamos@comet"` (`aarch64-linux`, `/home/steamos`).
SteamOS owns boot, kernel, GPU drivers, networking, SSH and the VR session.
The hostname was verified as `comet` after the user's manual rename.

## Explicit imports

Host composition stays visible in `flake.nix`:

- Blackmoon/Glasscastle/Espresso/Oasis NixOS: `common.nix`, `common-gui.nix`,
  `desktop.nix`, `common-gaming.nix`, and existing host/hardware modules.
- Existing homes: `homeModules.home`, `home/desktop.nix`, and their host modules.
  Existing Gaia/macOS behavior remains gated by their existing GUI/platform settings.
- Comet: Catppuccin's Home Manager module, `homeModules.home`, and `machines/comet/home.nix`.
  It imports neither NixOS modules nor `home/desktop.nix`.

`common-packages.nix` is the single source of shared app packages/fonts consumed
by `common.nix`, `common-gui.nix` and Comet. Comet inherits compatible entries by
default, not a separate handpicked list. `homeModules.home` shares the existing
app configuration: Nixvim, zsh, tmux, Kitty, Rofi, Obsidian and other shared tools.

NixOS `desktop.nix` owns Hyprland, SDDM/virtual keyboard, desktop portal, polkit,
keyring/PAM, session environment and related packages. `home/desktop.nix` owns
Quickshell/Mako, desktop-wide MIME/GTK/dconf settings and GCR/Wayland shell variables.
There is no CLI/GUI split, Comet `disabledModules` list, `manageDesktop` capability
flag or package-name session exclusion list.

The remaining Comet adaptations are concrete: correct username/home/architecture,
Home Manager rebuild aliases, a store-path tmux shell, no forced Obsidian registration
overwrite, no Git author identity, no credential-backed Wikimem enrollment, no
repository auto-cloning and no generic-Linux GPU driver integration. Bash remains
the login shell; shared zsh is available without changing the OS account.

## True platform omissions

From the locked aarch64 package set: Discord, Proton Pass GUI, Ledger Live, Itch
and Wine are unavailable; XIVLauncher has no aarch64 output. The catalog exposes
these through `exclusions`. Session packages are omitted structurally by not
importing the desktop module, not by platform filtering.

Bambu Studio is currently a NixOS-managed Flatpak declaration, not a shared Nix
package; its deployment was not replicated. Blackmoon's NVIDIA/hardware additions
and host-specific compositor/wallpaper stack also remain host-owned. Installing
Tailscale, WARP, NetworkManager or Proton VPN packages does not enable/configure
those services. No accounts, tokens, keys or saved app data are copied.

## Validation and deployment status (2026-10-04 UTC)

- All seven existing Home Manager activation derivations exactly match committed baseline.
- All five NixOS package multisets match; the four desktop hosts' list order changes
  as session packages move to their own module. Gaia's ordering is unchanged.
- Hyprland/UWSM, SDDM/settings/keyboard extras, X server, keymap, libinput,
  keyring/PAM/polkit, session variables, fonts and PipeWire options match baseline.
- Some generated NixOS store paths change with import/package ordering and source
  locations; whole NixOS system outputs are not claimed byte-identical or deployed.
- Final Comet evaluation: no user services/timers, Git identity, forced agent/display
  environment, GPU integration, Wikimem enrollment or forced Obsidian overwrite.
- Final target built natively and activated successfully at 2026-10-04 07:06 UTC:
  `/nix/store/bb1mycpvqzg04i6m70bmjm1x8lb0pmhw-home-manager-generation`.
- Fresh login-shell checks find ChatGPT, Codex, Chromium, Neovim, zsh, tmux,
  Kitty, Obsidian, VLC, Signal, Thunar, OBS, Spotify Player, Proton VPN and shared
  tools; corresponding desktop entries are installed. No GUI apps were launched.
- Login shell remains `/bin/bash`, Git identity remains unset, upstream Nix remains
  2.35.2 and its daemon socket and `/nix` mount remain active.
- Backups and pinned rollback generation:
  `/home/steamos/.local/state/comet-setup/pre-shared-20261004T070626Z/`.
  `existing-configs.tar` preserves touched existing files/symlinks;
  `previous-generation`, `rollback-generation`, file manifests and a package list
  preserve the prior state. Earlier SteamOS shell backups also remain below.

## Checkout and future updates

The durable checkout is `/home/steamos/stuff/nix-config`. It was cloned from a
Blackmoon Git bundle containing the unpushed integration commit, with the actual
remote preserved as `git@github.com:mochimisu/nix-config.git`. No GitHub push was
performed. Follow-on Comet-only changes can be transferred by bundle and fast-forwarded
without rewriting the remote or requiring credentials on Blackmoon.

As steamos, in a login shell, run:

```sh
home-manager switch --flake '/home/steamos/stuff/nix-config#steamos@comet'
```

Non-login automation must first put the installer binaries on PATH:

```sh
export PATH=/nix/var/nix/profiles/default/bin:$PATH
```

Do not use sudo, `nixos-rebuild` or `nh os switch` on Comet. GitHub access is a
separate setup step: the user-created `~/.ssh/id_ed25519_github` is passphrase
protected, no agent was available to the SSH automation, and GitHub's host key
was not yet in Comet's known_hosts. Unlock the key privately with ssh-agent/ssh-add;
never provide the passphrase in chat. Compare GitHub's host fingerprint with its
[official documentation](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints)
before accepting the first connection. No persistent authentication configuration
was changed by the agent.

## Temporary caffeine command

Comet installs `caffeine` as a small Home Manager package. Existing nixpkgs
`caffeine-ng` is ARM-compatible but its desktop screensaver/session interfaces
were absent in Frame's session; it does not use logind. The alternative
[wlinhibit](https://github.com/einetuer/wlinhibit) is explicitly marked broken by
its upstream author. Neither was installed just to provide a misleading indicator.

The package wraps the host's existing `/usr/bin/systemd-inhibit`; it does not
replace systemd, start a service, or change power/security policy:

```sh
caffeine                    # keep a terminal open; Ctrl-C stops it
caffeine sleep 3600          # release automatically after one hour
caffeine nix build .#...     # release when the command exits
```

It now requests `idle:sleep` in `block` mode and fails before starting the command
if this session lacks sleep-inhibitor authorization. There is no idle-only fallback,
interactive authorization prompt, sudo, or permanent power/polkit change. Use a local
graphical terminal if SSH authorization is denied. A finite command such as
`caffeine sleep 7200` releases after two hours; Ctrl-C also releases the lock.

The original idle-only implementation did not stop Steam's one-hour AC inactivity
suspend; see the diagnosis below. Brief acquisition/release of the stronger lock
is verified, but Steam honoring it at its next one-hour timeout is still untested.
The user's already-running old caffeine/tmux process is deliberately not replaced;
only a new invocation uses the updated helper. Battery/thermal policies are unchanged.

## Existing backups and rollback

Original SteamOS shell behavior was inspected and preserved. Original files:

- `/home/steamos/.bashrc.comet-pre-hm-20261004T062024Z`
- `/home/steamos/.bash_profile.comet-pre-hm-20261004T062024Z`
- Duplicate originals and package inventory:
  `/home/steamos/.local/state/comet-setup/pre-hm-20261004T062024Z/`

For rollback to the pre-shared configuration, run the pinned
`pre-shared-20261004T070626Z/rollback-generation/activate` as steamos. For complete Home Manager removal use `home-manager uninstall`,
then restore original shell files. Replace symlinks with backups; do not copy
through symlinks into the Nix store.

NixOS community installer 2.35.2 installed upstream Nix using the Steam Deck plan.
`/nix` bind-mounts `/home/nix` on the separate ext4 home partition. Root has Btrfs
`ro=true` despite `rw` mount flags. Installer receipt/uninstaller remain at
`/nix/receipt.json` and `/nix/nix-installer`; do not permanently disable protection.

## Nested Hyprland checkpoint (2026-10-04)

Activated `/nix/store/lkvh5104zzs7ypqii8zwmax4sjvagg38-home-manager-generation`.
`comet-hyprland` (desktop entry **Hyprland Desktop**) starts a private KWin X11
bridge and nested Hyprland 0.56.2. `comet-hyprland --test` limits it to 40 seconds;
`comet-hyprland --stop` stops only its transient unit. The existing Desktop
fallback and SteamOS login-session setting are unchanged.

Verified: private WAYLAND-1 output 1280x720 at 60 Hz, scale 2, GPU buffers;
Konsole mapped/visible/accepting input as a native Wayland client; no configuration
errors. Outer Gamescope, Steam and Chromium PIDs remained unchanged; selected
user-manager graphical environment matched the pre-test snapshot. Headset
appearance/controller input still needs user confirmation. Tests have timed out.

The runtime path must stay short for IPC. Source the HM environment fragment
without nounset. Native graphics dependencies use a private symlink directory,
never global LD_LIBRARY_PATH or all of /usr/lib. The nested child disables the
Gamescope Vulkan bypass layer. SteamOS updates may require updating the checked
native graphics SONAMEs.

Limitations: matching Aquamarine's actual app ID in the KWin fullscreen rule
caused no Hyprland output, so the change was reverted; nesting is windowed inside
KWin. The retained Hyprland-class rule does not force Aquamarine fullscreen.
Kitty failed EGL initialization; use native `comet-terminal` (Konsole). General
Nix GUI application compatibility remains unverified. No clipboard watchers,
lock action or shared systemd desktop integration start.

Rollback: stop the private launcher, then run
`/nix/store/8nq27z3imxxyw9b3qsshhgns1sq6sdnb-home-manager-generation/activate`.
That path is recorded in `~/.local/state/comet-setup/pre-nested-generation`.

## Declarative media apps (2026-10-04)

`media-apps.nix` has one `apps` attribute set defining VacuumTube and Kodi.
It drives both the pinned `nix-flatpak` Home Manager module and stable desktop
launchers (`/usr/bin/flatpak run --user APP_ID`). The module uses SteamOS's native
Flatpak only within its own scope. Unmanaged apps/remotes are preserved; automatic
updates, retry loops, unused-runtime pruning and permission overrides are off.
Removing an app from the declaration lets nix-flatpak remove that managed app.

Installed and verified on Comet: VacuumTube 1.8.2 and Kodi 21.3-Omega, both aarch64
user Flatpaks from Flathub. Kodi's upstream build currently depends on the retired
Freedesktop 24.08 runtime; VacuumTube uses 25.08. No accounts, Kodi media sources,
credentials or additional sandbox permissions were configured. Apps were not
launched during the overnight setup; playback/controller testing is pending.

Steam registration is explicitly separate from installation:

```sh
comet-steam-apps          # read-only status; exit 3 means pending
comet-steam-apps --apply  # tomorrow, with Steam running; may show Steam UI
```

The registrar reads shortcuts with nixpkgs' VDF parser and submits only missing
entries through Valve's installed `steamos-add-to-steam` helper (`steam://`
IPC). It never writes `shortcuts.vdf`, starts/stops Steam, or replaces manual
shortcuts. Exact existing Flatpak entries are preserved, name conflicts fail,
and a pending-submission receipt prevents duplicates before Steam saves its
in-memory state. Multiple Steam accounts require an explicit `--account ID`.
A pending receipt is not proof of registration: confirm in Steam and with the
status command. If a request fails, inspect the receipt under
`~/.local/state/comet-steam-apps/ACCOUNT/` before considering a manual retry.

Registration is additive: removing/renaming declarations does not delete or
rewrite Steam shortcuts. Steam remains the owner of shortcut customization.
No URI submissions occurred during overnight setup. These are non-Steam app
entries, not Steam Store app-ID purchases or game installation declarations.
The + menu desktop entries are available independently of Steam Library entries.

Five isolated registrar checks passed: existing/manual entry preservation, name
conflict refusal, status-only behavior, pending-submission deduplication, and
refusal to launch Steam when it is stopped. Native Flatpak reconciliation exited
successfully; the headset session and existing apps were left running.

### Caffeine limitation confirmed (2026-10-04)

The user's original tmux caffeine process (PID 61705, child sleep infinity 61707)
remained running with an idle/block inhibitor from 00:33 PDT across real suspend.
At 02:14:24 PDT Steam logged a transition to k_ESystemPowerState_Sleep after
3600 seconds of inactivity on AC (BIsOnBattery=false); at 02:14:25 its systemmanager
issued Suspend. Logind entered deep suspend and resumed at 12:15:14 PDT on a
power-key press. This was Steam's AC inactivity policy, not an expired SSH/tmux
process or low-battery event. Logind IdleAction=ignore: the idle-only lock is not
a blocker for Steam's explicit suspend request.

The initial warning-only correction was superseded by the durable repair above.
New caffeine invocations request idle:sleep and fail clearly when unauthorized;
the existing process is not altered.
A separate three-second idle:sleep/block acquisition succeeded from the current
local Codex context without sudo or a prompt, then released; the existing tmux
idle lock remained untouched. Earlier SSH context required authorization.

Candidate temporary command, from a locally authorized terminal while on AC:

```sh
/usr/bin/systemd-inhibit --no-ask-password --what=idle:sleep --mode=block \
  --who=caffeine --why='Temporary requested work on Comet' /usr/bin/sleep 7200
```

Ctrl-C or the two-hour expiry releases it. No persistent policy is changed.
If remote authorization fails, run from the local graphical terminal; do not
change polkit rules. Acquisition is verified, but whether Steam's one-hour
suspend path honors the sleep lock has NOT been tested. Do not claim this is a
Frame-specific supported guarantee or bypass thermal/battery protections.

Durable repair activated as generation
`/nix/store/gs79ijkri61ar3hkd1vggfdzjy8wnjjf-home-manager-generation`, pinned at
`~/.local/state/comet-setup/caffeine-sleep-result`. `caffeine sleep 3` acquired a
sleep:idle/block inhibitor without a prompt and released it on exit. A simulated
polkit denial exited 1 with local-terminal guidance, no command execution and
no idle-only fallback. Existing tmux caffeine PIDs 61705/61707 remained untouched
and still hold the old idle-only lock; the user must start a new invocation for
the repaired behavior. Hyprland config and media manifest matched the prior
active generation. No forced suspend or full-hour verification was performed.

### Launcher discovery and Nix app declarations (2026-10-04 follow-up)

The running Steam/SteamVR XDG_DATA_DIRS omits ~/.nix-profile/share. Home Manager
now publishes declared desktop entries in ~/.local/share/applications, verified
with native Gio.DesktopAppInfo without launching anything. The shipped Frame +
button increments a scan counter on activation; its hook calls
SteamClient.Apps.ScanForInstalledNonSteamApps. Close/reopen + to rescan. Its launch
handler calls LaunchNonSteamApp. No session restart is required for that scan.

The media registrar initially failed to recognize Steam's quoted arguments.
Fixed using shlex.split; the actual saved Kodi and VacuumTube entries are now
recognized and preserved. The user confirmed launching VacuumTube successfully;
full playback/controller testing is not inferred. No entries were resubmitted.

The `apps` set in media-apps.nix now accepts exactly one of:

```nix
vacuumtube = { name = "VacuumTube"; flatpakAppId = "rocks.shy.VacuumTube"; };
vlc = { name = "VLC"; package = pkgs.vlc; binary = "vlc"; }; # example, not enabled
hyprland = {
  name = "Hyprland Desktop";
  command = "${config.home.profileDirectory}/bin/comet-hyprland";
  desktopId = "comet-hyprland";
  icon = "desktop";
};
```

`package` entries install their Nix package automatically. Optional `binary`
defaults to lib.getName package; optional `args` is a list of argument strings.
`command` is an absolute executable path for an already-declared integration.
Optional `icon`, `terminal` and `desktopId` customize its desktop entry.
Only Flatpak entries are passed to nix-flatpak. Native packages are not made
sandboxed or GPU-compatible merely by adding a launcher.

Each app gets a stable ~/.local/bin/comet-apps/KEY launcher. Rebuilds update its
Home Manager symlink; a registered Steam entry keeps that stable executable path,
so artwork, controller settings, names and launch arguments stay Steam-owned.
Existing direct Flatpak entries are recognized too, without migration or duplicates.
Hyprland is included in the declaration and + menu; Steam Library registration
for it is pending explicit `comet-steam-apps --apply` if wanted. Activation never
submits Steam URIs. Future first-time entries need that explicit command with
Steam running; check `comet-steam-apps` afterward. Removing declarations does not
remove Steam shortcuts. Pending receipts still suppress automatic resubmission.

Actual Steam-only service on Frame is steam.service (not steam-launcher.service).
If the user independently wants to restart Steam, the command is
`systemctl --user restart steam.service`; it interrupts Steam and its activity.
The installed dependency graph does not propagate this restart to SteamVR or
Gamescope. Never restart steamvr.service/gamescope-session.service just to refresh
an app list. No restart was performed by the agent.


### Nested startup warning and minimal desktop (2026-10-04)

The nested child now uses Hyprland 0.56.2's official `start-hyprland` watchdog,
with `--no-nixgl --path <packaged Hyprland> -- --config <generated config>`.
This retains the private runtime/DBus, native graphics shim and disabled Home
Manager systemd integration. The watchdog passes an inherited pipe descriptor
to Hyprland; it does not import the session into the global user manager.
`--no-nixgl` avoids adding a second graphics wrapper to the tested Valve shim.
The previous direct launch explains the "without start-hyprland" warning.
An already-running session keeps its old process until the user relaunches it.

A terminal on a black background is the current minimal nested desktop:
shared window styling and keybindings are imported, but startup callbacks are
overridden to avoid global agents. No wallpaper daemon, Quickshell/sidebar or
Mako is launched. Adding those requires separate private-session integration;
do not import all of home/desktop.nix or enable global session agents here.


### Shared desktop integration (2026-10-04)

Comet now imports `home/desktop.nix` and the shared Hyprpaper module alongside
shared Hyprland styling/bindings. The `variables.nestedDesktop` guard lets these
same modules run Hyprpaper, Quickshell/sidebar and Catppuccin-styled Mako directly
inside the private compositor session. The blanket startup override and demo
terminal autostart were removed. Shared Rofi/app discovery, Thunar, screenshots,
workspace/window actions and keyboard switching remain available. Super+Q opens
the tested native Konsole adapter, Super+Space opens Rofi and Super+G opens Thunar.

Comet uses the shared dusk wallpaper on any nested output. Blackmoon's animated
cat MP4 is untracked and absent here; its host-specific DP-3 video service is not
imported. The sidebar uses the first nested output and Qt software rendering to
avoid the observed Valve/Nix EGL mismatch. QWERTY and native Konsole remain Frame
adaptations. Rofi opens directly instead of globally killing other Rofi processes.

Nested guards omit login-session agents, clipboard watchers and global Mako
D-Bus activation, keep Home Manager's Hyprland systemd integration/reload off,
and hide/disable sidebar hardware/network/lock/power controls. Shared GTK styling
is included; global browser defaults, dconf preferences and SSH agent/SDL shell
variables are not taken over. No portals, SDDM, security or power policies change.
Future launches snapshot Hyprland Lua into their private runtime so subsequent
rebuilds apply on the next launch. All children remain in comet-hyprland.service.

Built and activated the shared-desktop-result generation. Hyprland
`--verify-config` passed, Qt qmlformat parsed the generated sidebar, generated
startup isolation assertions passed, and global user-unit names/content matched
the previous generation. The existing Steam/VR/Chromium and nested compositor
processes were retained. Wallpaper/sidebar/notifications and app shortcuts have
not yet been graphically verified in this new setup.

When ready, save work in nested windows, run `comet-hyprland --stop`, then reopen
**Hyprland Desktop** from + (or run `comet-hyprland`). The original Desktop fallback
remains available. Roll back the configuration with
`~/.local/state/comet-setup/hyprland-watchdog-result/activate` and relaunch the
nested desktop. Changes are local and uncommitted on Comet; syncing them back to
Blackmoon remains separate work. Blackmoon was not accessed or changed.

### Viewport and cursor verification (2026-10-04)

Captured both the 1280x720 nested output and the 1920x1080 KWin X11 window before
changes. The latter showed Hyprland at (160,90), with black margins. Gamescope
and KWin output were 1920x1080 scale1, while Hyprland defaulted to 1280x720 scale2
(640x360 logical). A child in the private session confirmed inherited
XCURSOR_SIZE=256 and XCURSOR_THEME=steam. These are desktop captures, not the
headset's stereoscopic render or SteamVR's spatial placement.

Live targeted testing succeeded: after mapping, a private KWin script sets only
resourceClass=aquamarine noBorder=true, clears maximize and assigns frameGeometry
to window.output.geometry. Maximize alone used the stale 1600x900 work area;
explicit output geometry produced 1920x1080. Reloading only the private Lua copy
with a WAYLAND-1 preferred/scale1 rule produced 1920x1080 scale1. Setcursor to
breeze_cursors 24 and a sidebar-only refresh produced a normal pointer and sidebar
at x1898, width22, height1080. Screenshot inspected after changes; margins gone.
No compositor, Steam, VR, Chromium or user app restart. The original failed
fullscreen-at-initial-map approach was not retried; its precise failure remains
unproven, and this post-map geometry approach was verified instead.

The Comet launcher now reads Gamescope's XRandR size for KWin's initial dimensions,
fits the nested window only after its output appears, and exports local 24px
Breeze cursor settings. Nix declares scale1. Built and activated desktop-fit-result;
Hyprland config verification passed. Current session already has the live fixes;
a future relaunch exercises the new startup automation, not yet tested end-to-end.
Rollback configuration: ~/.local/state/comet-setup/shared-desktop-result/activate.

A separate issue discovered in the running shared desktop: Hyprpaper0.8.4 aborted
inside Hyprtoolkit0.6.0 OpenGL procedure loading (loadGLProc). Therefore the dark
wallpaper background remains; this is distinct from the fixed outer margins.
Wallpaper rendering still requires a compatibility fix; do not claim it works.

### Wallpaper graphics fix verified (2026-10-04)

Verbose Hyprpaper logging isolated the prior OpenGL abort to missing dynamically
loaded Valve Mesa dependencies: first libzstd.so.1, then libxcb-xfixes.so.0.
Adding those two explicit SteamOS libraries to the existing private native-graphics
shim restored GBM/EGL initialization. No global library path, renderer replacement,
package downgrade or graphics driver change was needed. The shared Hyprpaper
configuration and dusk image remain unchanged.

Started only Hyprpaper in the live private session. Verified a 1920x1080 background
layer and inspected a screenshot showing dusk across the full desktop with the
sidebar/cursor intact. Persisted dependencies in nested-desktop.sh; built and
activated wallpaper-fixed-result (6q1lyka376d6v7npw2fmlmlpm2lqsybl). Hyprland config
verification and git diff whitespace checks passed. Core compositor/Steam/VR/app
PIDs remained unchanged. No relaunch is needed for the current wallpaper.

Non-disruptive generated fit-script tests covered existing and delayed Aquamarine
windows and rejected mutations to an unrelated Konsole window. Startup's bounded
private-output wait and private D-Bus addressing were reviewed. Full next-launch
ordering still awaits a user relaunch; no automatic session restart was performed.

### Steam AC timer caffeine integration (2026-10-04)

Supersedes the inhibitor-only caffeine behavior above. `caffeine [COMMAND ...]`
now acquires a lease on Steam's **AC-only** inactivity timer, setting it to Never
(`system_idle_suspend_ac_sec=0`) through the installed Steam settings UI wrapper.
It then runs COMMAND (default `sleep infinity`) under an idle:sleep/block
inhibitor. Battery timeout and power-button behavior are not modified.

`comet-caffeine.service` is a small user recovery guard. With no leases or pending
restoration it does not access Steam or change settings. Overlapping invocations
share the initial saved timeout; the last exit restores it. PID start time and
boot ID identify leases. Dead clients are pruned, their tracked command group is
terminated, and the timer is restored. The guard restarts after failure and
recovers saved intent on the next user session. If Steam is unavailable, the
saved restoration remains pending and is retried; this is not reported as a
successful restore. `caffeine --status` shows live timers, leases and pending
restoration. State is private under `~/.local/state/comet-caffeine/`.

A manual nonzero AC change observed while leases are active relinquishes timer
ownership, so exit preserves that choice. A manual Never-to-Never change is
indistinguishable from caffeine's existing value; likewise a change away and
back entirely between polls cannot be detected. Caffeine warns if timer control
is lost while a command is running. It cannot guarantee wakefulness during a
Steam outage or a manual override. SIGKILL of the guard plus a stopped/disabled
user service prevents automatic recovery until the service is restarted.

Steam's existing localhost diagnostic endpoint must already be available.
Caffeine never enables debugging, changes authorization, restarts Steam, masks
services, or writes raw Steam configuration files. The native SetSetting call
accepts a serialized protobuf, so the implementation uses the installed UI's
wrapper instead of inventing a key/value call. Changes fail closed before the
requested command starts if acquisition cannot be confirmed.

Validation: eight guard tests cover overlap, preexisting Never, manual override,
setter failure, unavailable Steam, restoration retry, dead clients, and a crash
between saving intent and writing the timer. Live normal-exit, concurrent-run,
SIGTERM and killed-client tests confirmed AC0 while owned, AC3600 afterward,
battery900 unchanged, and no leftover test inhibitors. This is a controlled
short test, not a full one-hour inactivity/suspend endurance test.

Usage: `caffeine sleep 7200` keeps AC idle sleep disabled for two hours;
`caffeine --status` reports its state. Ctrl-C releases a foreground run.
Stop all clients and allow restoration before rolling back the Home Manager
package. Do not simply stop the recovery service while a restore is pending.


### Native media applications

Comet installs mpv and FFmpeg, publishing mpv's desktop file with absolute
Exec/TryExec paths because the running Steam session lacks the Nix PATH.
A user-level `menus/applications.menu` alias to SteamOS's
`/etc/xdg/menus/plasma-applications.menu` lets KDE discover applications under
Gamescope, which has no `XDG_MENU_PREFIX`. Without it Dolphin's chooser was
empty even when GIO could find VLC and mpv.

The user-level VLC desktop entry launches `comet-vlc`. This keeps SteamOS's
native VLC/graphics integration but removes inherited `LD_LIBRARY_PATH`:
Steam's `steamrtarm64/libavcodec.so.58` lacks E-AC-3 and reported AC-3 failures
in the old player. Clean native VLC decoded AC-3, E-AC-3 and DTS to PCM in
bounded null-output tests. The wrapper uses a new instance so requests cannot
return to a surviving player with the polluted library environment. Existing
players are left alone; reopen the file with the corrected VLC launcher.
FFmpeg decoded short audio/video segments of all 11 transferred files without
errors (H.264, HEVC Main 10; AC-3, E-AC-3, DTS). These are codec checks, not a
full-length playback/performance guarantee. No explicit MIME defaults changed.

VLC additionally prefers avcodec PCM decoding (headset audio is not an AC-3
passthrough sink). Both ordinary and file-launch single-instance reuse are
disabled. On the current SteamOS Mesa build, VLC unloads Freedreno before a
thread's registered destructor finishes: GDB traced the SIGSEGV to
libvulkan_freedreno.so's pthread-key destructor during nptl_deallocate_tsd.
The launcher preloads that native driver for VLC only, retaining it until exit;
this fixed the isolated synthetic GUI playback/exit test. It does not replace
the system driver, alter Steam/VR environment, or preload anything globally.

### Frame menu and session incident (2026-10-05 UTC)

ChatGPT's packaged desktop entry is exported into the user application directory
so Steam's + scanner can find it. Kodi/VacuumTube use their canonical Flatpak
desktop IDs as user overrides; the earlier `comet-media-*` entries were removed
by Home Manager. Existing Steam library shortcuts remain unchanged. Backups of
previous generated entries are in
`~/.local/state/comet-setup/menu-backup-20261005/`.

The VacuumTube + wrapper serializes launches and refuses an additional launch
if that Flatpak is already running. Its existing Steam library shortcut was
updated in place through SteamClient.Apps.SetShortcutExe/SetShortcutLaunchOptions
to use the same wrapper. Persisted VDF comparison confirmed only exe and
launchoptions changed; appID 2518984771 and all other fields were preserved. The installed app has no
single-instance lock. Two main instances were observed sharing the persistent
`~/.var/app/rocks.shy.VacuumTube/config/VacuumTube/sessionData` profile; only the
first had Local Storage LevelDB files open. This supports profile contention,
but successful login persistence across a clean app restart is not yet verified.
No cookies, tokens, or profile contents were read, copied, reset, or migrated.

At 00:49:33 UTC, SteamVR `vrserver` crashed with SIGSEGV; its shutdown was followed
by Gamescope/SteamVR recovery and app loss. This was not a host reboot. The boot
ID remained `360b5ac6-2587-4100-93e6-31ce05546ad2`. Home Manager activation ended
at 00:46:05 with a user-manager reload, not a VR stop. A diagnostic X11 pointer
click occurred around 00:49:24; whether that triggered the crash is unknown.
Avoid repeating injected pointer tests until that interaction is understood.
There is also a repeating mangoapp crash involving permission denied on the
nested KWin process's map_files; no security policy was changed to address it.

The uosc browser replacement is installed and points/highlights the right row,
but click-to-open validation did not pass before the VR crash. Do not report it
as fully repaired. Separate muted VLC tests advanced displayed-frame counters
after forward/backward seeks in HEVC Main10 and H.264; the user's seek freeze
remains unreproduced. Do not claim those counters verify actual headset pixels.

Follow-up browser validation used `/usr/bin/Xvfb` on a private display, not
SteamVR. The unmodified installed mpv wrapper and current Home Manager config
passed pointer move + button-down/up activation on a synthetic fixture:
`/tmp/comet-browser-fixture/test.mkv`, time-pos 0.042 to 1.0, stop returned to
`user-data/uosc/menu.type=open-file`. Evidence:
`/tmp/comet-uosc-isolated/final-results.txt`. Test player exited 0 and private
X server was stopped. The virtual display required an explicit 60 Hz test-only
refresh override; no such override was added to user configuration. Actual
headset/controller click confirmation remains pending. SteamVR/Gamescope PIDs
were unchanged throughout these tests.

The two-hour caffeine lease ended normally around 01:05 UTC. Verified no active
leases or pending restoration, AC idle timeout restored to 3600 seconds,
battery unchanged at 900 seconds. No extension was made. Gaia-side encoding
can continue without Comet; final transfer to the SD card requires Comet online.


### Chromium + launcher and travel-mode inspection

`media-apps.nix` now declares Nix Chromium (the same Widevine-enabled package
already in the shared catalog) under canonical `chromium-browser.desktop`.
Its wrapper removes inherited Steam library/preload and Qt plugin paths before
executing Nix Chromium; it does not set or migrate a browser profile. Verified
Steam's actual + app scan returns exactly one Chromium entry pointing at
`~/.local/bin/comet-apps/chromium`, and version is 154.0.8037.92. Activation
preserved active Obsidian and the mode-0400 SOPS secret.

Installed SteamVR is 2.17.10, package
`deckard-steamvr-rel r25358740+28b72a4f-1`. Installed dashboard `systemui.js`
contains the vehicle-travel prompt and names the UI path
`VR Settings > Valve Internal > Travel Mode`. Its handler sets the boolean
path property `/driver_cv/enableTravelMode`. Read-only access through
SteamClient.OpenVR.PathProperties.GetBoolPathProperty confirmed false; the
requestEnablingTravelModeSentToUser property was also false. The automatic
popup render wrapper returns null in this build. `settingsschema.vrsettings`
marks Valve Internal internal_only. Installed chunk~f620ae578.js gates visibility
on a SteamVR main build, `/settings/steamvr/showInternalSettings`, or both a
Valve email and developer_mode_enabled. Ordinary Developer Mode alone does not
satisfy that gate. No flag, boundary, tracking option, or runtime was changed.

A sandboxed temporary-profile Chromium probe on a secure localhost page exposed
navigator.xr, but a real-time isSessionSupported('immersive-vr') returned false.
H.264 and VP9 canPlayType returned probably. This was a headless capability test,
not a headset playback test. The packaged Chromium gclient_args.gni explicitly
sets checkout_openxr=false and the installed binary had no OpenXR strings;
these corroborate a missing OpenXR backend rather than a browser flag to toggle.
Temporary test profiles were removed; existing profiles were untouched.

Valve Internal menu visibility was subsequently enabled with explicit user
approval, using the installed OpenVR SDK's IVRSettings_003 in Utility mode.
`steamvr/showInternalSettings` was previously unset (effective false); SetBool
returned no error and repeated readback returned true. Travel Mode's driver
property was re-read and remained false. Existing vrserver/gamescope processes
were unchanged, and no restart or boundary/tracking change was performed.
The installed schema/code now permits the Valve Internal page, but the actual
Travel Mode control was not visually confirmed in the currently open UI.
Navigation suggested by installed UI text: VR Settings > Valve Internal >
Travel Mode. Exact rollback to the prior unset state:

```sh
~/.local/state/comet-setup/valve-internal-menu/comet-internal-menu restore-unset
```

The narrow helper's source, binary, and before.json record are in that same
state directory. It only supports reading/enabling/hiding/removing the
showInternalSettings key; it cannot change Travel Mode.


### Travel Mode utility (2026-10-05)

The separate **Travel Mode** + entry is installed through `media-apps.nix`.
Launch with `~/.local/bin/comet-apps/travel`. It offers large Turn On and
Turn Off buttons, live readback, Refresh status, and Close (also Escape).
Opening/closing does not change the setting. Only an explicit On/Off click
writes `/driver_cv/enableTravelMode` through the existing Steam runtime API.
Remain seated: this experimental setting may briefly shift the view;
persistence between sessions is unverified. Closing does not turn it off.
To reverse a user-enabled setting, press Turn Off and wait for confirmed OFF.

Built and activated `~/.local/state/comet-setup/travel-mode-result`.
Steam's installed-app scanner returned exactly one Travel Mode entry.
The installed `comet-travel-mode --status` read returned false (OFF).
No actual tracking toggle or visible headset window was used in validation.
Seven backend/controller fixture tests passed (`test-travel-mode.py`).
Additional isolated Xvfb GUI fixture tests passed On/Off, repeated clicks,
error-disabled controls, Refresh recovery, and closing without a write,
using the packaged Python/Tk runtime. A fixture screenshot is saved at
`/tmp/comet-travel-mode-fixture.png`. Actual headset controller interaction,
real setter behavior, persistence, and vehicle effectiveness remain untested.
SteamVR and Gamescope retained PIDs 2649 and 2324 through activation;
Syncthing remained active and the SOPS runtime secret remained mode 0400.

To remove just this utility, remove the `travel` entry and `travelMode` let
binding in `media-apps.nix`, rebuild the Comet Home Manager configuration and
activate it. Removing the launcher does not reset the driver setting.
The separate Valve Internal menu visibility rollback above is unrelated.


### VacuumTube controller navigation (2026-10-06)

Installed Flatpak VacuumTube 1.8.2 already has `controller_support=true`.
Steam reports its app 2518984771/controller 0 layout as Gamepad, with gamepad
output enabled and no keyboard/mouse output. Its installed native mappings are
D-pad/left stick = arrows, A = Enter, B = Escape, X = search,
LT/RT = seek backward/forward, LB/RB = back/forward, Select/Start = volume
down/up, and L3 = mute. R3 settings was removed in this version; settings uses
Ctrl+O. Do not assume Space/K playback bindings without verifying them.

With the app closed, changed only `touch_overlay` from true to false in
`~/.var/app/rocks.shy.VacuumTube/config/VacuumTube/config.json`. Native controller
support remains on, and the independent mouse/right-click fallback remains.
The exact JSON semantic diff was verified to contain only that field. No
cookies, session data, Flatpak permissions, or Steam global bindings changed.
Previous input booleans are recorded in
`~/.local/state/comet-setup/vacuumtube-controller-20261006/prior-input-settings.json`.
Rollback: with VacuumTube closed, set `touch_overlay` back to true (or use the
app's Touch Overlay setting). Do not replace the whole config/profile.

First headset test: launch the existing VacuumTube Steam Library shortcut,
focus its window, then try D-pad/left stick, A and B. That shortcut retains the
singleton wrapper shared with the + menu. Actual Frame gamepad delivery and
+ menu focus behavior remain unverified; no playback or synthetic key events
were started during this change. If native gamepad delivery fails, consider an
app-only keyboard layout using arrows/Enter/Escape/S and F2/F3, then disable
native controller support only for that alternate layout to avoid double input.


### VacuumTube per-window Steam Input association, 2026-10-06

The + launch was observed with X11 focus but zero virtual-gamepad events; Steam selected Desktop AppID 413080 and empty.vdf. The existing VacuumTube Gamepad layout belongs to AppID 2518984771. Its guarded launcher now runs vacuumtube-input.py, which assigns STEAM_GAME only to the new exact VacuumTube main window after matching a PID from this launch (including Flatpak namespace PIDs). It leaves existing windows, other app IDs, root properties, focus, controller layouts and the singleton/profile unchanged. It launches Flatpak directly, never redirects through Steam Library. The helper times out after 30 seconds, then continues holding the app lifecycle under the outer lock.

Isolated Xvfb checks passed for property readback, idempotence, rejecting a wrong owner, preserving an existing different app ID, and not touching an unrelated window. The single Nix launcher derivation built offline and its symlink was activated; no full Home Manager switch or app launch occurred. Actual Gamescope/Frame controller delivery remains unverified: next user + launch should be checked for STEAM_GAME=2518984771, the selected Steam Input layout, and D-pad/A/B navigation. Fixture success alone does not prove the Frame overlay accepts this app identity. Rollback: replace ~/.local/bin/comet-apps/vacuumtube symlink with the exact target in ~/.local/state/comet-setup/vacuumtube-input-20261006/previous-launcher-target, then revert only the helper invocation in media-apps.nix.
