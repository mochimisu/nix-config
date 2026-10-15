# Blackmoon wallpapers

Blackmoon uses the upstream Skwd-wall Nix package, pinned by `flake.lock` (initially
`2b85cb2b45a1efb1140280571d522f53a58169d9`, beta.24). This packages upstream release
binaries; it does not maintain a local Rust build. The input follows our existing
nixpkgs. The optional proprietary Steamworks helper is not installed.

`machines/blackmoon/home/wallpaper.nix` owns `blackmoon-cat-wallpaper.service`.
The service supervises Skwd's daemon, seeds DP-3 with the existing ignored
`untracked-assets/cat-in-the-swamp-moewalls-com.mp4`, and preserves later picker
selections. Hyprpaper remains underneath and on the other output. The video stays
muted, fills DP-3, and uses the bottom layer. No media is copied or committed.

Nix merges its playback defaults into the writable
`~/.config/skwd-wall-v2/config.json`; an existing file is backed up once as
`config.json.before-nix`. Automatic all-output restoration is disabled; the module
restores only DP-3 and retains only its saved selection in the output cache
(backed up once as `outputs.json.before-nix`). Wallpaper-based theme changes are disabled. The module
preserves the transparent Kitty fullscreen exception by managing pause/resume
itself. Skwd's control API pauses all animated outputs, so revisit this policy if
adding animated wallpapers to other monitors. Missing DP-3 or the cat asset
stops the renderer and waits; the static fallback remains available.

Build/check:

```sh
nix build .#skwd-wall
nix build .#nixosConfigurations.blackmoon.config.home-manager.users.brandon.home.activationPackage
nix build .#nixosConfigurations.blackmoon.config.system.build.toplevel
sudo nixos-rebuild switch --flake .#blackmoon
systemctl --user status blackmoon-cat-wallpaper.service
skwd-helm current --json
```

Only update Skwd when desired: `nix flake update skwd-wall`. Do not broadly update
inputs for a wallpaper change. Run `skwd-wall-v2` to open the picker after the
system package profile is activated.

## Initial deployment, 2026-10-14

Package, Home Manager, and NixOS builds passed. The user Home Manager generation
was activated live without rebooting. Verified muted DP-3 playback, a mapped
`skwd-wall-vk` bottom layer, no mpvpaper process, normal fullscreen pausing,
fullscreen Kitty resuming, picker operation, stop/start static fallback, and
repeated restarts with video confined to DP-3. The previous mpvpaper wrapper was
also briefly tested successfully for rollback.
The NixOS system profile still needs the sudo switch above: unattended sudo
requires a password, and user-only Home Manager activation does not replace
NixOS's `/etc/profiles/per-user/brandon` package profile or boot generation.

## Rollback

Stop the new service to immediately expose Hyprpaper:

```sh
systemctl --user stop blackmoon-cat-wallpaper.service
```

The pre-migration user generation is retained at
`/nix/store/8vbgnnz6ajikq0r8g96yx6b96p8vq8dg-home-manager-generation`.
Before a system switch, activate its `activate` script to restore the previous
user service. Its mpvpaper wrapper is
`/nix/store/ab4ar4vvg5blprll301s29k5ya3y5nch-blackmoon-cat-wallpaper`.
After a system switch, standard NixOS generation rollback also restores the old
package profile. Restore the repository's wallpaper change separately before a
future rebuild; keep the cat asset and any saved Skwd configuration.


## Both connected outputs (2026-10-15)

DP-3 and portrait DP-1 now each restore their saved Skwd selection, muted.
The seed keeps both cache entries, and startup snapshots the cache before applying
either output so the first apply cannot erase the other selection. Disconnected
outputs are skipped. Both currently use the local 3840×2160 Snowfall in Forest
MP4 from https://motionbgs.com/snowfall-in-forest, retained in untracked-assets.
The previous cat video remains the fallback and is unchanged. Fill mode and
monitor layout are unchanged. The existing DP-3 fullscreen/Kitty policy remains;
Skwd's global pause/resume affects both animated outputs.
This supersedes the DP-3-only restoration notes above.
