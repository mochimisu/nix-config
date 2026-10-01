# Wikiskill on Google Drive

Use Drive **instead of Syncthing for wiki content and plugin source**: each client syncs its local
`~/stuff/wikiskill` directly with `wiki/` in the private `Wikiskill Sync` Drive folder.
Plugin source at `~/plugins/wikiskill` syncs separately with `plugin/` in the same
Drive folder. Gaia is an ordinary client, not a gateway. Obsidian stays on Syncthing. Raw Markdown is readable by Drive clients without a custom protocol.
Plugin installation is separate; a Drive content replica alone does not install
Wikiskill's helpers or change a cloud client's skill routing.

`wikiskill-drive.nix` provides one `rclone bisync` command and a five-minute systemd
timer per enabled host. The legacy `wikiskill-sync.nix` module keeps Blackmoon/Gaia’s former wiki and plugin Syncthing folders paused.
Blackmoon and Gaia now enable the module and use the shared encrypted grant.
Their initial baselines and two-way wiki/plugin transfers through Drive have been
verified. Other hosts remain disabled until their machine keys and baselines are
provisioned. This replaces the Gaia-only bridge.

## One Google login, shared SOPS secret

The existing production grant is already in `secrets/wikiskill-drive.enc`; new
clients reuse it. The following OAuth steps are only needed to replace that grant.

Create a Google OAuth Desktop app client, enable the Drive API in its project,
and set the OAuth audience to In production. Rclone’s shared client is being retired
in 2026; do not leave the client ID blank. Run this once on a computer with a browser,
in your own terminal (rclone can print tokens). The existing Google account/full Drive scope was already approved. The
folder ID narrows operations, not the OAuth grant's permissions.

```sh
umask 077
rclone --config "$HOME/.config/wikiskill-drive/rclone.conf" config
```

Create a remote named `wikiskill-drive`, type `drive`, scope `drive`, root folder ID
`10tbl7eQcRKXASx-wIwPVoA9trSmF3QMn`, supply your own client ID/secret, and finish browser sign-in. Store the complete
config (including OAuth refresh token and any custom client credentials) encrypted:

```sh
mkdir -p secrets
sops --encrypt --input-type binary --output-type binary \
  --filename-override secrets/wikiskill-drive.enc \
  "$HOME/.config/wikiskill-drive/rclone.conf" > secrets/wikiskill-drive.enc
git add secrets/wikiskill-drive.enc
```

The shared rule in `.sops.yaml` includes the existing age recipient and the verified
Blackmoon/Gaia SSH host-key recipients. Each new
client needs a decryption identity: either securely provision the existing age key
at `/var/lib/sops-nix/key.txt` and set `sops.age.keyFile` to that path, or add its
SSH-host/age public recipient to the shared rule and run `sops updatekeys` on the
ciphertext. This key provisioning replaces per-client Google sign-in. Never commit
private keys or plaintext config. Check encryption succeeded before staging.

In each intended host's configuration:

```nix
services.wikiskillDrive.enable = true;
# Only needed if provisioning the existing shared age identity:
sops.age.keyFile = "/var/lib/sops-nix/key.txt";
```

SOPS decrypts to `/run/secrets/wikiskill-drive`. The command seeds a mode-0600 copy at
`~/.local/state/wikiskill-drive/rclone.conf` on first run. Each client refreshes its
own writable copy; rebuilds preserve it. For credential rotation, update SOPS, stop
the timer/service, and replace the runtime copy from the decrypted secret on each
host. Revoking the shared Google grant affects all clients. A Google OAuth app in
Testing mode may expire its grant after seven days; use a persistent grant.

## First migration

1. Back up/reconcile existing wiki/plugin replicas and the Drive folder. Pause the wiki
   and plugin-source Syncthing folders on **all** participating hosts before starting
   Drive sync. Keep Obsidian sharing enabled. Deploy the configuration above on
   each host; stop `wikiskill-drive.timer` during bootstrap.
2. On the initial authoritative client, create `RCLONE_TEST` in both local roots and
   their remote `wiki/` and `plugin/` roots. Inspect the selected files, then run as `brandon`:
   `wikiskill-drive-sync all --resync --resync-mode path1 --dry-run`.
   Run again without `--dry-run` after checking the diff. On subsequent clients use
   `--resync-mode path2` after reconciling any local-only edits. Resync unions unique
   files and chooses the specified side for differences; it is not a semantic merge.
3. Verify a harmless edit in both directions for each tree, then start `wikiskill-drive.timer`.
   Update existing `~/.config/wikiskill/hosts.json` to `sync_engine: rclone-bisync`
   with the local corpus route and `plugin_source.sync_folder: plugin`. Nix's default registry preserves existing files.
   Use the updated shared skill with `rclone-bisync` handling. Its legacy helper
   refuses writes for externally managed replicas. Cloud clients must explicitly select their direct Drive route.

For the remote access marker, after the first command has seeded the runtime config:
`rclone --config ~/.local/state/wikiskill-drive/rclone.conf touch --drive-root-folder-id
10tbl7eQcRKXASx-wIwPVoA9trSmF3QMn wikiskill-drive:wiki/RCLONE_TEST`.
Never schedule `--resync`; missing or damaged baseline state requires an inspected
recovery. Check service status with `journalctl -u wikiskill-drive`.

## What syncs and what can conflict

The filter includes article Markdown, numbered Markdown conflict copies, images
(PNG/JPEG/WebP/SVG), PDFs and the access marker. It excludes hidden files, root
underscore directories (raw sources/runtime state/exports), dependencies, renderer,
scripts, tests and root instruction files. Code/helpers remain separately installed;
source evidence in `_sources` is not available through this content-only replica.

The separate plugin filter includes instructions, helpers, tests and `.codex-plugin`
metadata, excluding private configuration, credentials, Git/Syncthing metadata and
caches. Source sync does not install or refresh a versioned plugin cache. Existing
source-backed skill links see updated instructions on their next invocation; keep
source writers trusted and resolve conflicts before using the source. There are no
receive-triggered installation hooks. Use `wikiskill-drive-sync plugin` or `wiki`
for an individual tree; no arguments syncs both. Each has separate baselines/backups.
Create the remote marker for `plugin/RCLONE_TEST` using the same command as above.
The plugin source filter follows [rclone filtering](https://rclone.org/filtering/).

Normal runs propagate edits and deletions. A run deleting over 10% of either side
stops for inspection. Overwritten/deleted files are backed up outside the synced
roots, locally and under `backups/<hostname>/<wiki-or-plugin>/<timestamp>` in Drive. There is no
automatic backup cleanup. Conflicts retain both numbered alternatives; the original
filename may disappear until reconciled. Avoid editing the same page concurrently
on multiple clients. Bisync's locks are local, not distributed; randomized timers
reduce overlap but do not make simultaneous writes transactional.

See [rclone bisync](https://rclone.org/bisync/) for bootstrap, recovery and concurrency
limits, and [Drive authentication](https://rclone.org/drive/) for OAuth configuration.
