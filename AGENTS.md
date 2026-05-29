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
- Wikiskill system services in `common.nix` should run the Node entrypoints directly, not `npm run`, so systemd signals the process with the shutdown handler; the daily daemon is expected to stop promptly on SIGTERM.
- Gaia runs Openclaw directly on the host from `machines/gaia/openclaw.nix` as the `openclaw` service user with state in `/var/lib/openclaw`; it no longer uses the old `gaiaclaw` NixOS container.
- Gaia Matter declarative pairing reconcile lives at `machines/gaia/home-assistant/pairings.nix` and reads setup codes from `/etc/secret/matter-reconcile.env`.
- Gaia Matter custom OTA drop directory is `/earth/home-assistant/matterjs-server/ota-provider` (files are imported by matter-server and removed after successful import).
- For new Matter devices on Gaia, define the device in `machines/gaia/home-assistant/pairings.nix` and keep sensitive/unique identifiers (setup codes, MACs, unique IDs, serials) in sops (`machines/gaia/secrets/matter-env.env`) referenced via `*_env` keys.
- Gaia's IKEA `MYGGBETT door/window sensor` exposes door state as Matter `BooleanState` at `1/69/0`, with `true=closed` and `false=open`; invert it when using door-open semantics.
- Gaia can run without the local ZBT-2 OTBR by leaving `gaia.homeAssistant.localThreadBorderRouter.enable = false`; in that mode Matter.js/keepalive do not depend on OTBR and Gaia relies on the same-dataset Aqara M3 route over `enp5s0`.
- Gaia BlackVue sync lives in `machines/gaia/blackvue-sync.nix` and pulls from dashcam `192.168.1.208` into `/earth/blackvue` on a 15-minute systemd timer with daily grouping, `90d` retention, `90%` max disk use, and `1h` failed-download retry.
- Gaia ebook hosting lives in `machines/gaia/ebooks.nix`: Kavita serves the ebook/OPDS library on port `8083` with state in `/earth/kavita` and book files in `/earth/books`; KOReader position sync runs as the `koreader/kosync` Podman container with state in `/earth/koreader-sync` and ports `17200` (HTTP API) and `7200` (HTTPS).
- Non-Gaia NixOS machines install a Nix post-build hook from `common.nix` that opportunistically runs `nix copy --to ssh://brandon@gaia $OUT_PATHS` after local builds. The hook is non-fatal and requires the building machine's root user to have SSH access to `brandon@gaia`.
- Obsidian Syncthing is Nix-owned in the shared `obsidian-sync.nix`; Gaia hosts the canonical `/earth/syncthing/obsidian` folder and NixOS clients use `/home/brandon/Obsidian Vault`. If fixing live through the Syncthing API before a rebuild, do not restart Gaia's Syncthing afterward or the old generated config may overwrite folder membership.
- For Matter/Thread reliability debugging, do not mask missed presence or remote events by extending automation timing windows such as door pulse durations. Keep compensating pulses short (Gaia bathroom door pulse stays 15s) and focus on fixing underlying Thread transport, node availability, subscription, or sensor reporting issues.
- Hyprgrass is temporarily pinned to `horriblename/hyprgrass` PR #381 so it can load and configure correctly with Hyprland Lua config. The touchscreen module translates old hyprgrass bind strings to the PR's `hl.plugin.hyprgrass.bind` Lua API. Switch the flake input back to Hyprgrass main once Lua support lands there or the PR is merged.
