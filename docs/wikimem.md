# Declarative Wikimem clients

The shared Home Manager module installs the service-backed Codex skill and the `wikimem` MCP bridge on managed Linux clients. Gaia uses authenticated loopback first. Blackmoon, Glasscastle, Espresso, Oasis and standalone Linux Home Manager use an SSH tunnel to the `gaia` hostname first, with public HTTPS fallback. `oai-dev` evaluates with the client disabled and receives no activation or package from this module.

The public [wikimem-skill flake](https://github.com/mochimisu/wikimem-skill) owns the portable skill/plugin, client bridge, and reusable Home Manager module. This repository pins that dependency in `flake.lock` and retains host routing, SOPS credentials and deployment policy. Update intentionally with `nix flake update wikimem-skill`, review the lock change, and rebuild. No mutable checkout or npm installation at login is required.

Ingestion, refresh scheduling, jobs and verification belong to the private Wikimem service project. The local collector only submits redacted Codex conversation packets. No automation implementation is vendored here; see `~/stuff/wikimem-mcp/docs/automation.md` for its separate deployment.

Home activation reconciles only `[mcp_servers.wikimem]` in the mutable Codex configuration, preserving other servers and user settings. It links the Nix-owned client settings and skill, backs up replaced files under `~/.local/state/wikimem/nix-backups`, and removes the recognized legacy filesystem skill entrypoints. The legacy Drive sync and wiki viewer have been removed from Nix. Existing filesystem/Drive content and local sync state are retained as archives; Obsidian continues to use Syncthing. Paused legacy Syncthing folder declarations prevent old clients from resuming wiki sync.

## Credentials

Gaia and Blackmoon have separate SOPS-encrypted account keys at `secrets/wikimem-<host>.enc`. Gaia reuses its existing named key; Blackmoon has a separately revocable “Blackmoon Codex (Nix)” key. Each is encrypted to the host's registered SSH-derived age recipient and the existing recovery recipient. Activation decrypts only to `/run/secrets/wikimem`, owned by brandon with mode 0400. Plaintext keys are never evaluated by Nix or copied into the store.

Glasscastle, Espresso and Oasis have client configuration prepared but still need their own credential enrollment. Their default key path is `~/.config/wikimem/codex.key` until a per-host encrypted file exists. Do not reuse Gaia's or Blackmoon's key. To make enrollment declarative:

1. Create a named read/write key for that computer in Wikimem's authenticated Account → Manage access keys page.
2. Determine the computer's trusted SSH-host age recipient using `ssh-to-age` on its `/etc/ssh/ssh_host_ed25519_key.pub`. Add a `.sops.yaml` rule for `secrets/wikimem-HOST.enc` with that recipient and the existing recovery recipient.
3. Encrypt the key as SOPS binary data into that file; never put plaintext into Nix expressions, command arguments, git, or chat. For example, from a private mode-0600 input file, with the matching creation rule installed:

   ```sh
   sops encrypt --filename-override secrets/wikimem-HOST.enc \
     --input-type binary --output-type json /path/to/private-key-input \
     > secrets/wikimem-HOST.enc
   git add secrets/wikimem-HOST.enc .sops.yaml
   ```

4. Rebuild the host. The module automatically selects `/run/secrets/wikimem` when its encrypted file is present. Existing sops-nix host-key decryption must be available. Remove any temporary plaintext enrollment file after validation.

## Apply and verify

Transfer/review these repository changes on each machine, then run its normal `nix-rs` or `sudo nixos-rebuild switch --flake .#HOST`. This work does not commit/push the repository or remotely rebuild clients. On Gaia, the current imperative connection remains working until system activation installs the declarative replacement.

Restart Codex after activation. Ask it to call `wiki_status`, search for `wikimem` under `automation`, and report identity, write permission and route. The bridge logs only `loopback`, `lan-ssh`, or `public-https` to stderr. Test public fallback on a non-Gaia machine with its LAN route unavailable. SSH host verification is pinned in Nix; each client's own SSH identity still needs access to Gaia. A mid-session transport failure is surfaced rather than replaying an uncertain write.

The legacy `wikiskill-daily-daemon` is disabled on every NixOS client. Gaia's replacement worker and collector are user services deployed from the service project. Inspection on 2026-10-03 found the worker and collector timer installed but disabled; ingestion and scheduled refresh are therefore not active. Stop the old system daemon before enabling those units; the Nix change alone takes effect only after rebuild. Other clients' local conversation histories are not collected until a collector is explicitly installed there.

## Prompt for the model on each managed client

> In this machine's nix-config, apply the reviewed Wikimem client migration described in docs/wikimem.md. Exclude oai-dev. Determine this host from its existing Nix configuration. Use the Nix-built bridge and skill; do not run the imperative install-local.js installer. On Gaia use loopback first; elsewhere use verified SSH over the LAN and HTTPS fallback. Inspect whether this host's SOPS key is enrolled; if not, prepare its encryption rule and ask me to create the named key through the authenticated account UI, never to paste it into chat. Preserve unrelated Codex configuration, Drive data and Obsidian. Build and apply with this machine's usual rebuild workflow, report any sudo requirement, then verify the account using wiki_status and a scoped search. Do not claim remote machines were updated.

Validation performed on Gaia: the Nix client package built successfully; all five NixOS configurations evaluated with the client enabled, and oai-dev evaluated disabled. The reconciliation tests verify preservation of unrelated settings, idempotence and refusal to overwrite malformed TOML. Gaia/Blackmoon encrypted credentials round-tripped through SOPS without displaying plaintext. Full system activation still requires the normal privileged rebuild.

## Legacy retirement audit (2026-10-03)

The live Wikimem MCP reported read/write access and successfully searched the migrated `automation` corpus. The pinned public skill and service audit cover literal/ranked search, selected reads, links/backlinks, revision-checked edits, atomic multi-page commits, history, metadata, structural checks and moves. SQLite is canonical; changes to the old Drive replica do not enter Wikimem.

Removed the legacy viewer, Drive bisync module/timer, encrypted Drive grant and its creation rule, host enable flags, and Gaia's viewer proxy. Gaia's homepage now links to `https://wikimem.bwang.dev/`. The shared SOPS installer compatibility override is defined once in `common.nix`, fixing Blackmoon's duplicate `sops.package` evaluation failure.

Retain local wiki/plugin trees, Drive files, runtime OAuth state, and old ingestion completion receipts. Attachments, raw sources and generated rendering are outside Wikimem's Markdown corpus. Web/Corpowiki search remains a separate tool capability. Hosted ChatGPT/Work connections and collectors on other computers require their own deployment; removing the legacy Nix services does not install those.

Nix removal takes effect per host after activation. Restart Codex afterward to load Wikimem. Separately installed personal Wikiskill plugins must be disabled in their owning client; removing a Nix module does not uninstall account-level plugins. Do not delete retained archives or revoke the old Google grant until all clients and remaining attachment needs have been reviewed.
