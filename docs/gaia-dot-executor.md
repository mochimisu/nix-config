# Gaia headless dot executor deployment history

The shared implementation is now documented in [dot-executor.md](dot-executor.md).
The entries below describe the November 9 deployment under its original name.
The next activation migrates to `dot-executor.service`; it has not been deployed
as part of the generalization. Preserve the existing identity and private state.

## Ownership and scope

`machines/gaia/home/dot-executor.nix` declares Brandon's Gaia-only
`gaia-dot-executor.service`. It is imported only by Gaia's Home Manager module.
`pkgs/gaia-dot-executor/` packages the supervisor and offline tests; the flake
exports `packages.x86_64-linux.gaia-dot-executor`.

The package uses Python and the same zlib-wrapped Codex CLI as the shared package
catalog, pinned by `flake.lock`. The generated executable and service reference
immutable store paths. The service no longer depends on the mutable
`~/stuff/gaia-dot-executor` working copy or the current system's Codex symlink.

This is a tested unofficial integration, not a published standalone dot
installer. Native command/file execution works. It does not recreate the
desktop app's browser/computer-use IPC.

## Identity and private state

The module declares Gaia's existing server-issued environment ID. That ID is not
a credential. It is the identity enrolled by the real Gaia ChatGPT app and
explicitly granted doot access in the normal local-device confirmation.

All writable state stays in `~/.local/share/dot-executor`:

- `auth.json` contains the existing Gaia login. The directory must be mode 700
  and the file mode 600, owned by Brandon. Never commit it, copy it into the
  Nix store, or use a Nix path literal to refer to it.
- `enrollment.json` is the retained nonsecret enrollment/provenance record. If
  present, it must match the declared ID, host and registry exactly. A mismatch
  fails closed without changing either identity. If absent, the declared
  identity can be used with the existing valid private login.
- Runtime status and the duplicate-supervisor lock are private mutable files.

The unit is skipped if the existing auth file is absent. Neither the Nix build,
activation nor supervisor creates a login, registers a computer, or grants
access. Native Codex owns authentication and token refresh; the supervisor only
checks file metadata and `codex login status`, never auth-file contents.

Do not replace refreshing OAuth state from a static secret deployment on every
activation. Optional backups of credentials must be encrypted and access
controlled. Retain the nonsecret enrollment identity and, if keeping the old GUI
rollback, the app's installation identity. A clean reinstall still needs valid
private login state and the existing server-side grant; Nix does not recreate
those account permissions.

## Lifecycle

The user unit is wanted by `default.target`. Gaia already declares
`users.users.brandon.linger = true`, so the user manager can run at boot without
a login session. No linger, network, firewall, credential or sandbox setting was
changed for this deployment.

The supervisor keeps native Codex's stdin open and manages graceful shutdown. It
strips display and borrowed-auth environment overrides. Native Codex owns normal
transport reconnects. The unit deliberately uses `Restart=no`; recognized
authentication/access denials stop it without a service retry loop.

`status` is a local snapshot. `running_unverified` means no recognized readiness
log was seen, not that direct access failed. Verify availability using the dot's
computer list and a direct command; process liveness alone is not proof.

## Build and inspect

```sh
nix build .#gaia-dot-executor
nix build .#nixosConfigurations.gaia.config.home-manager.users.brandon.home.activationPackage
nix run .#gaia-dot-executor -- check
systemctl --user status gaia-dot-executor.service
journalctl --user -u gaia-dot-executor.service -n 30 --no-pager
```

The package build runs offline unit tests and validates the pinned native Codex
binary. Those tests never read the real login or contact enrollment/grant APIs.

For future changes, run `python3 scripts/validate.py` as the repository-wide
evaluation check. Report platform/input failures separately from this package's
build and live verification. Never switch unrelated dirty host changes merely
to activate this service.

## Scoped activation and rollback

The initial deployment replaces only the old imperative user unit and its
`default.target.wants` link. Links must point through the generated
`*-home-manager-files` directory, not directly to resolved leaf derivations, so
future Home Manager collision checks recognize ownership. Keep a Nix GC root for
the generation. Run the generated `check-link-targets.sh` after migration.

Only `gaia-dot-executor.service` should be restarted. Because it serves the
current direct connection, use an independently authorized control path for that
restart, then verify a fresh direct attachment and command. Do not start the old
GUI concurrently against the same environment ID.

The old regular unit and enablement target are backed up under
`~/.local/state/gaia-dot-executor-nix-migration-20261109T210048Z/`.
Its `before.json` records only nonsecret identity/file metadata; credentials were
not copied. The original imperative project remains available for rollback.

To roll back the live service, stop this unit, replace only its two generated
links with the saved regular unit and original enablement symlink, reload the
user manager, and start the unit again. The same granted identity and private
state are retained. Verify direct access afterward. The older
`~/stuff/gaia-dot-executor/rollback-granted-gui.sh` restores the genuine-app route
and is a separate fallback, not the normal Nix rollback.

## Deployment verification — November 9, 2026

- The final Nix package built and passed all 30 offline tests, its installed
  launcher check, and the pinned native Codex 0.167.0 version check.
- Gaia's Home Manager generation built. Only this service's two ownership links
  were activated; no whole-host or whole-Home-Manager switch was performed.
- The Nix-built service is active and enabled. Direct reattachment and commands
  verified Gaia with DISPLAY/WAYLAND_DISPLAY unset and no GUI processes running.
- Existing auth/enrollment file metadata was unchanged across activation; the
  separate Codex Remote service remained active.
- The complete generated Home Manager collision check passed. The generation
  is held by a Nix GC root at `~/.local/state/gaia-dot-executor-home-generation`.
- Repository-wide evaluation passed 14 of 15 targets. Comet's ARM Home Manager
  target failed because an `aarch64-linux` Catppuccin dependency could not build
  on Gaia's `x86_64-linux`; no Gaia target failed.
- Changes were left uncommitted and unpushed, preserving unrelated staged and
  unstaged work. An operational note was appended to the already-dirty root
  AGENTS.md without staging that file.

The exact rollback helper is
`~/.local/state/gaia-dot-executor-nix-migration-20261109T210048Z/rollback.sh`.
Run it from an independently authorized control route because restarting the
executor interrupts a command running through that executor.

## Verification limits

A full reboot, a clean-machine restoration and forced credential-expiry recovery
have not been tested. The GUI/display installation is retained only for rollback
and is not required for this service. A provider/runtime change can affect this
undocumented integration.

## Sources

- [Native executor protocol](https://github.com/openai/codex/blob/main/codex-rs/exec-server/README.md)
- [CLI arguments](https://github.com/openai/codex/blob/main/codex-rs/cli/src/exec_server_command.rs)
- [Normal dot computer grant](https://learn.chatgpt.com/docs/enterprise/cloud-local-access#end-user-experience)
