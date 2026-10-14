# Historical agent notes

These are dated incident records, preserved from AGENTS.md on 2026-10-14.
They are historical evidence, not pending tasks or current package requirements.
In particular, the SOPS workaround was removed after its upstream fix, and the
old Wikiskill services must remain retired. Check current source before acting.

- Gaia shower light is Matter node 608. On 2026-10-04 its blank NodeLabel broke the Matter Layer binding; HA registry serial matching confirmed the node. The live label was restored, `MATTER_UID_MBR_SHOWER` corrected in SOPS, and the binding gained `unique_id_env`. Matter Layer also retried Off every 100ms, preventing its 2.5s fade from completing. The 5s settling fix and regression test are in `~/stuff/matter-layer` as uncommitted changes; the duplicate Nix patch was removed at the owner's request. Commit/push Matter Layer, update its flake input, and rebuild to activate the fix. Live workaround sets shower `1/8/19` (OffTransitionTime) from 25 to 0; after activating the runtime fix, restore 25 and verify on/off through Matter Layer. Do not re-pair this online switch to repair its label.

- With UWSM enabled, `home/common-linux.nix` disables Home Manager's Hyprland systemd integration. HM's startup `stop hyprland-session.target` propagates to `graphical-session.target` and tears down UWSM during login; disabling that integration restored login on September 6. Session services such as Blackmoon's wallpaper follow `graphical-session.target`. The attempted compositor downgrade did not fix the failure and was removed; the Aquamarine crash was during teardown and did not establish the cause of login failure.

- Gaia's 337 Codex rollouts were converted to paginated history with the supported `codex migrate-rollouts --apply` command on 2026-09-05 after Remote thread loads proved slow. The pre-migration sessions and consistent state/history database copies are retained at `~/.codex/backups/thread-store-pre-pagination-20260905T1610`; keep that backup until Remote behavior has been confirmed over normal use.

- With the September 2026 nixpkgs update, sops-nix still requests removed `buildGo125Module`. `common.nix` centrally imports its installer with a package scope extended to map that builder to `pkgs.buildGoModule` (verified with Go 1.26.7). SOPS itself is not explicitly revision-pinned in flake.nix; remove this override once its upstream builder is updated.

- When repairing Steam PipeWire capture on Blackmoon, restart Steam after any portal restart. The September 30 black-frame incident used a stale capture node ID recycled for the BRIO webcam (`no more input formats`). Steam’s saved `DesktopCaptureRestoreToken` plus PermissionStore `screencast` data can retain DP-3 without a picker; do not globally auto-approve capture to fix repeated prompts.

- Openclaw was removed from Gaia’s Nix configuration on 2026-10-01 at the owner’s request. Its module, input, documents, plugin registration helper, and homepage card are gone. Saved state in `/var/lib/openclaw` and workspace in `/home/brandon/stuff/openclaw` were retained; historical repair notes remain in Wikiskill.

- Wikiskill was retired from Nix on 2026-10-03 in favor of Wikimem. Keep old local/Drive data, attachments and ingestion receipts as archives. Only paused Syncthing tombstones remain in `obsidian-sync.nix`; Gaia's homepage links to Wikimem. The service worker and collector timer were installed but disabled at audit time, so do not claim automated upkeep is active. Keep the SOPS compatibility package definition centralized in `common.nix`: duplicate `mkDefault` package definitions from separate modules caused Blackmoon evaluation to fail. See `docs/wikimem.md`.
