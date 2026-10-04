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

## Checkout and future updates

The durable checkout is `/home/steamos/stuff/nix-config`. It was cloned from a
Blackmoon Git bundle containing the unpushed integration commit, with the actual
remote preserved as `git@github.com:mochimisu/nix-config.git`. No GitHub push was
performed. Follow-on Comet-only changes can be transferred by bundle and fast-forwarded
without rewriting the remote or requiring credentials on Blackmoon.

As steamos, in a login shell, run:

```sh
home-manager switch --flake '/home/steamos/stuff/nix-config#steamos@comet'
```

Non-login automation must first put the installer binaries on PATH:

```sh
export PATH=/nix/var/nix/profiles/default/bin:$PATH
```

Do not use sudo, `nixos-rebuild` or `nh os switch` on Comet. GitHub access is a
separate setup step: the user-created `~/.ssh/id_ed25519_github` is passphrase
protected, no agent was available to the SSH automation, and GitHub's host key
was not yet in Comet's known_hosts. Unlock the key privately with ssh-agent/ssh-add;
never provide the passphrase in chat. Compare GitHub's host fingerprint with its
[official documentation](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints)
before accepting the first connection. No persistent authentication configuration
was changed by the agent.

## Temporary caffeine command

Comet installs `caffeine` as a small Home Manager package. Existing nixpkgs
`caffeine-ng` is ARM-compatible but its desktop screensaver/session interfaces
were absent in Frame's session; it does not use logind. The alternative
[wlinhibit](https://github.com/einetuer/wlinhibit) is explicitly marked broken by
its upstream author. Neither was installed just to provide a misleading indicator.

The package wraps the host's existing `/usr/bin/systemd-inhibit`; it does not
replace systemd, start a service, or change power/security policy:

```sh
caffeine                    # keep a terminal open; Ctrl-C stops it
caffeine sleep 3600          # release automatically after one hour
caffeine nix build .#...     # release when the command exits
```

It requests only `idle` inhibition, verified to be permitted as steamos without
sudo. Combined `idle:sleep` inhibition returned `Interactive authentication required`
and is deliberately not used. The lock ends with the command/process. This blocks
logind idle handling; it does not promise coverage of Valve's headset auto-suspend,
manual suspend, low-battery/thermal actions or power-button behavior. A three-second `caffeine sleep 3` test visibly acquired an `idle`/`block` lock
for steamos and released it when the command exited. No persistent
inhibitor is left running after verification. GUI rendering, VR app sharing,
reboot persistence and OS-update survival remain untested.

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
