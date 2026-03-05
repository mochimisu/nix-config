## Nix Config Agent Notes

### Repo scope and layout
- This is a Nix flake managing NixOS, home-manager, and nix-darwin.
- Entry point: `flake.nix` defines `nixosConfigurations`, `homeConfigurations`, and `darwinConfigurations`.
- Shared system modules live in `common.nix`, `common-gui.nix`, and `boot-efi.nix`.
- Host-specific config lives under `machines/<host>/`.
- Home-manager modules live under `home/` and are imported via `homeModules.home`.

### Per-machine changes
- If asked to apply a change to only one computer, gate it by hostname.
- Prefer gating at the NixOS module level using `networking.hostName` from `config`.
- Example pattern: `lib.mkIf (config.networking.hostName == "<hostname>") { ... }`
- Alternatively, place the change in `machines/<host>/...` and import it only for that host.

### Workflow notes
- When adding new Nix files, make sure they are `git add`'d so the flake can build.
- Store useful information in this `AGENTS.md` for subsequent runs.
- Store secrets (tokens, passwords, API keys) in `.AGENTS.LOCAL.md` only and keep it out of git.

### Host notes
- Gaia runs the Openclaw NixOS container in `machines/gaia/openclaw-container.nix` (container name: `gaiaclaw`).
- Gaia Matter declarative pairing reconcile lives at `machines/gaia/home-assistant/pairings.nix` and reads setup codes from `/etc/secret/matter-reconcile.env`.
- Gaia Matter custom OTA drop directory is `/earth/home-assistant/matter-server/ota-provider` (files are imported by matter-server and removed after successful import).
- For new Matter devices on Gaia, define the device in `machines/gaia/home-assistant/pairings.nix` and keep sensitive/unique identifiers (setup codes, MACs, unique IDs, serials) in sops (`machines/gaia/secrets/matter-env.env`) referenced via `*_env` keys.
