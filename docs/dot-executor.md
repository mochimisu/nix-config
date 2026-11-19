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
Cove's is `machines/cove/home.nix` (`deck@cove`). Both are enabled with their own
locally enrolled and approved identities as of November 19, 2026. Never
reuse another host's ID or login. Gaia's existing ID remains in
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
Comet and Cove had `loginctl enable-linger USER` applied during their authorized
setup so the enabled user service starts at boot without an interactive login.

## Comet and Cove enrollment — November 19, 2026

Each host's genuine ChatGPT app registered its own identity. Comet used its
existing host-local ChatGPT login in the dedicated executor home; Cove completed
a fresh native device-code login. The enabled local **Allow access** confirmation
granted doot access on each computer. Concurrent approvals initially conflicted;
Comet's approval succeeded after retrying sequentially. Both showed **Access
allowed** before the headless handoff. No cross-host credential copying occurred.

The temporary app and authenticated virtual display were stopped before starting
the headless service with the same identity. Both native architectures built.
Only the declared executor unit and its enablement link were installed, through
a scoped `home-manager-files` derivation rooted at
`~/.local/state/dot-executor-setup/service-files`; generated Home Manager collision
checks and systemd verification passed. Future normal Home Manager switches own
the same links and also install the CLI in the profile. Native SteamOS linger
is configured separately from Home Manager.

Both services reported `transport_ready`; authenticated registry status reads
returned HTTP 200 and `connected`. A native-child SIGKILL test on each host
produced exactly one automatic restart after 30 seconds and restored that same
connected status. Both have `Linger=yes`, an enabled service, and no failed
user units. The local supervisor's `dot_access` field
remains `not_verified` because it does not query per-dot grants; the app's normal
grant UI supplied that verification. Full reboot and fresh dot command execution
are separate checks, not established merely by registry connectivity.

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
Systemd restarts other failed exits after 30 seconds, without a retry-window
limit, so a boot-time outage does not permanently strand the executor offline.
Exit 2 (invalid setup) and exit 77 (access denied) suppress automatic restarts.
An explicit service stop still stops the service normally.

### Boot failure and readiness diagnostics — November 19, 2026

On Gaia, the native child exited with code 1 five seconds after boot; with
`Restart=no`, the enabled unit remained failed. Restarting restored registration
and rendezvous connectivity. An authenticated read of the existing environment's
registry status returned `connected`, and the user subsequently confirmed the
green presence indicator. The original child error was discarded, so the cause
of the boot exit remains unresolved; network timing is not established.

Native tracing emitted ANSI colors despite piped output and `LOG_FORMAT=json`.
The supervisor now strips ANSI control sequences before classifying diagnostics,
so colored readiness and HTTP-denial messages are recognized. The regression
test uses the observed colored field format. Process liveness and transport
readiness still do not establish per-dot access.

The parser fix and retry policy were built and deployed to Gaia through only
the generated service and enablement links, retaining Home Manager ownership
and a GC root. All 32 package tests passed. A live native-child SIGKILL test
triggered one automatic restart after 30 seconds; the new process reported
`transport_ready`, and the registry again returned HTTP 200 / `connected`.
This verifies process-failure recovery, not a full reboot test. Authentication
denials and setup errors remain excluded from retries. Temporary diagnostic
service overrides were removed.
Isolated systemd checks also confirmed exit codes 2 and 77 cause zero retries.
Repository evaluation passed 15 of 16 targets. Comet's cache lookup was
interrupted after a separate no-substitution evaluation confirmed its existing
ARM Catppuccin build-hook dependency cannot build on this x86-64 host.

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
