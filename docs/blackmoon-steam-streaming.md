# Blackmoon Steam streaming target

The intended streaming display is the **Dell Alienware AW3423DW ultrawide**,
currently **DP-3**, 3440x1440, unrotated at (0,0). DP-1 is the rotated Acer
XB271HU, not the streaming target. Prefer hardware identity when resolving the
connector; do not change the desktop layout or disable the Acer to repair Steam.

## Capture selection

Blackmoon starts Steam with `-silent -pipewire` and allows the normal portal
picker to issue a persistent restore token. The saved PermissionStore
`screencast` record, referenced by Steam's `DesktopCaptureRestoreToken`, chooses
the captured output. The token itself is private runtime state, not Nix data.

`machines/blackmoon/home/steam-capture-output.py` resolves the unique connected
Dell AW3423DW and updates only the output field of an existing approved Hyprland
v3 restore record. It preserves the approval map, cursor setting, timestamp and
opaque backend token. It never creates or grants capture permission. Unknown
schemas and missing/ambiguous target hardware fail rather than choose another
monitor. Without a saved token, use the normal portal picker and choose the Dell.

Home Manager installs `steam-capture-output` and runs it before the Blackmoon
`steam-autostart` service. The new service unit was installed on 2026-11-01 through its generated
Home Manager files path, followed only by systemd daemon-reload. Steam was not
restarted. The helper can also be run manually by its evaluated ExecStartPre
store path before a coordinated Steam restart; installing its short command in
the user profile awaits a normal Home Manager activation. An unavailable Dell or unfamiliar saved
permission prevents the guarded autostart; manual Steam launching is unchanged.
This is a startup reconciliation, not a daemon changing active capture sessions.

## 2026-11-01 correction and validation

Steam's saved capture incorrectly selected DP-1. The built helper changed that
existing record to DP-3 and verified its unchanged approval map. A second run
was idempotent. Steam remained PID 3398; no Steam/portal/game restart, monitor
change, or input-permission change occurred. The ordinary `-pipewire` launcher
and existing DP-3 game defaults were already correct.

Five offline tests in `tests/test-steam-capture-output.py` cover hardware-based
connector resolution, missing/disabled/ambiguous hardware, preservation of the
restore data, idempotence, and rejection of unapproved/unknown records. The helper
was built with Nix and the evaluated ExecStartPre points to it.

## Pending Comet test

Coordinate a Steam restart or fresh portal capture session; the running process
may still hold its old capture session. Confirm that Comet shows the unrotated
Dell ultrawide. Test the four image corners and center, clicking harmless UI,
then disconnect/reconnect once to check retained selection. Test a game menu
and relative camera control separately. Verify the physical mouse still traverses
both displays.

Do not deploy an extest patch before this test. Source inspection found that
extest 1.0.3 declares axes from maximum individual output dimensions (3440x2560)
while Hyprland maps absolute events across the combined 4880x2560 desktop. Also,
Xwayland's reported output origins differ from Hyprland's. This is a potential
remaining absolute-input defect, not evidence that correcting capture fixes it.
Hyprland 0.56.2 accepts device.output but does not apply that field to ordinary
absolute mice in setPointerConfigs; adding that rule alone is not a validated fix.
No custom extest or compositor patch has been deployed.

## Scoped deployment and rollback

The service symlink points through
`/nix/store/50wrncw14hfqbb5pm4cp011gm65c6lby-home-manager-files`, protected by the
indirect GC root `~/.local/state/steam-capture-output/home-files`. The previous
service symlink target is recorded in `previous-service-link` in that directory.
The generated Home Manager collision check passed. No full generation switch
was performed. Restore that recorded service link and run user daemon-reload
to remove the startup guard without restarting Steam. The corrected portal
selection remains persistent independently of that guard.
