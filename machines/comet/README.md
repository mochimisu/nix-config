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

## Future updates

Activation used a temporary source bundle. GitHub access still needs a Comet
identity key: its SSH directory had only `authorized_keys`, no `.pub` identity.
No key was created or GitHub authorization configured. Once access is configured,
clone the repository to `/home/steamos/stuff/nix-config`, then as steamos run:

```sh
home-manager switch --flake '/home/steamos/stuff/nix-config#steamos@comet'
```

For an explicit build/review from that checkout:

```sh
nix build '.#homeConfigurations."steamos@comet".activationPackage' --out-link result-comet
HOME_MANAGER_BACKUP_EXT=comet-shared-before ./result-comet/activate
```

Use a fresh backup suffix if a previous backup already exists. Do not use sudo,
`nixos-rebuild` or `nh os switch` on Comet. The local Blackmoon commit is not pushed
automatically, so the remote repository may not yet include this target.
GUI rendering, GPU acceleration, VR app sharing, reboot persistence and OS-update
survival remain untested. No VPN/network configuration, credentials or system
security settings were changed.

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
