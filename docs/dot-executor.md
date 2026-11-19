# Headless dot executor

`pkgs/dot-executor/` packages the supervisor and tests. The `dot-executor`
flake package is available for `x86_64-linux` (Gaia/Cove) and `aarch64-linux`
(Comet). `home/dot-executor.nix` is imported by the shared Home Manager module
and provides an opt-in `services.dot-executor` service.

This is an unofficial integration using the pinned native Codex executor.
It supports native command/file execution, not the desktop application's
browser/computer-use IPC. It does not enroll computers or grant dot access.

## Per-host configuration

After registering and approving the computer through the app, add this to its
Home Manager configuration, replacing both example values with that computer's
actual hostname and server-issued ID:

```nix
services.dot-executor = {
  enable = true;
  hostName = "comet"; # Use "cove" in Cove's configuration.
  environmentId = "REPLACE_WITH_THIS_COMPUTERS_APPROVED_ID";
};
```

Comet's configuration is `machines/comet/home.nix` (`steamos@comet`);
Cove's is `machines/cove/home.nix` (`deck@cove`). Both already import the module.
They remain disabled until their own identity and login are available. Never
reuse Gaia's ID or login to set up another host. Gaia's existing ID remains in
`machines/gaia/home/dot-executor.nix`.

Each user's state is `~/.local/share/dot-executor` (mode 700), with their existing
`auth.json` (mode 600). Credentials stay outside Git and the Nix store. Native
Codex owns login and refresh; the supervisor checks login status without reading
credential contents. If `enrollment.json` exists, its ID, hostname and registry
must agree with the declaration. A mismatch stops execution. The same hostname
check applies when no enrollment file exists.

The user service is skipped if `auth.json` is absent. It uses the user's Home
Manager profile and native OS command paths, including SteamOS paths. Normal
Home Manager activation installs the service and `dot-executor` command. SteamOS
owns its user manager and login lifecycle; this module does not enable linger
or change sleep/battery policy. Gaia already has linger configured separately.

## Inspect and verify

```sh
nix build .#dot-executor
nix build .#packages.aarch64-linux.dot-executor # Requires an ARM builder/cache.
# Supply the same host/ID as the module when no enrollment.json exists:
dot-executor check --host HOST --environment-id APPROVED_ID
dot-executor status --host HOST --environment-id APPROVED_ID
systemctl --user status dot-executor.service
journalctl --user -u dot-executor.service -n 30 --no-pager
```

`check` verifies local prerequisites only. Verify a fresh attachment and a
command such as `hostname` through dot to confirm actual remote access.
`status` may contain stale runtime state. Native Codex handles reconnection;
recognized authentication denials stop the supervisor without service retries.

## Gaia service-name migration

The old deployed name is `gaia-dot-executor.service`; the new one is
`dot-executor.service`. The new Gaia unit conflicts with and is ordered after
the old unit, preventing it from taking over until the old unit stops. Both
versions also share the same supervisor lock and private state directory.

Before activation, use an independent control connection to stop and disable
the old user service. Activate only the reviewed Home Manager changes, reload
the user manager and start the new service; verify the old service is inactive
and a fresh dot command reaches Gaia. Never run the GUI concurrently with the
headless executor under the same ID. Scoped file deployment must retain
`*-home-manager-files` ownership links and a GC root; run the generated collision
check. Do not switch unrelated host changes to deploy this rename.

For rollback, stop the new service before restoring/starting the old service.
Do not alter the ID or private login. Historical deployment evidence and backup
locations remain in [gaia-dot-executor.md](gaia-dot-executor.md). Generalizing
these files does not itself activate the new unit on any host.

## Generalization validation — November 19, 2026

- The x86-64 package built, including 31 offline tests and the installed launcher
  and native Codex checks.
- Gaia's Home Manager activation derivation and generated unit evaluated;
  disabling the option removes the unit, including its migration overrides.
- Cove's full Home Manager configuration evaluated with the service disabled;
  an opt-in override generated the expected `/home/deck` unit.
- The ARM package and isolated shared Home Manager module evaluated with
  Comet's hostname and `/home/steamos`. ARM build/runtime validation is pending.
- `python3 scripts/validate.py` passed 15 of 16 targets. Comet's full Home Manager
  target failed on an existing ARM Catppuccin import-from-derivation dependency
  because this x86-64 machine has no suitable ARM builder. It was not skipped.
- No service activation, enrollment, credential modification or commit was made.
