# Blackmoon wallpapers

Blackmoon uses pinned upstream Skwd-wall beta.24 (the `skwd-wall` flake input).
`machines/blackmoon/home/wallpaper.nix` owns `blackmoon-wallpaper.service` and
explicitly selects the local Snowfall in Forest video on DP-3 and portrait DP-1:
`untracked-assets/snowfall-in-forest-motionbgs-4k.mp4` from
https://motionbgs.com/snowfall-in-forest . Media stays outside Git and the Nix store.

## Playback and persistence

Both outputs use muted, bottom-layer, fill-mode video. Hyprpaper remains the
static underlay if the video is unavailable. Automatic recoloring and upstream
startup restoration are disabled. Nix seeds both cache selections with snow;
the supervisor explicitly applies it at startup and reconciles connected outputs
once a second. It retries transient RPC/apply failures and reapplies snow after
an output returns or its selection changes. Monitor disappearance no longer
terminates the service. The picker is not the source of persistent selection;
change the module to select a different durable wallpaper.

The DP-3 fullscreen policy remains: normal fullscreen windows pause Skwd,
fullscreen Kitty does not. Skwd's pause API affects both outputs.

## October 17, 2026 migration

The old `blackmoon-cat-wallpaper.service` was stopped, disabled and masked locally.
The new service conflicts with that legacy name and `skwd-walld.service` to
prevent competing daemons. The old video and complete prior Skwd cache were moved
to freedesktop Trash, preserving recovery while removing their picker entries,
history and thumbnails from active use. No Nix store or Git history was purged.
The picker now contains only snow.

The failure was a hotplug/restart followed by restoration of the old fallback on
DP-3; DP-1 retained snow. The new module does not use mutable cache selections as
policy and has no alternative video fallback.

## Validation and deployment

```sh
nix build .#nixosConfigurations.blackmoon.config.home-manager.users.brandon.home.activationPackage
nix build .#nixosConfigurations.blackmoon.config.system.build.toplevel
sudo nixos-rebuild switch --flake /home/brandon/stuff/nix-config#blackmoon
systemctl --user status blackmoon-wallpaper.service
skwd-helm current --json
skwd-helm list --json
```

The Home Manager and full NixOS builds passed. Only the wallpaper unit and its
wanted-by link were deployed live from the generated `home-files` directory;
the generation is pinned at `~/.local/state/blackmoon-wallpaper/generation`.
A real wallpaper-service restart retained snow on both outputs, with zero
automatic restarts. Local screenshots confirmed both rendered snowy forest.
A harness using the generated runner passed simulated single/all-output removal,
reconnection, transient RPC/apply failures and stable-state idempotence. Physical
monitor disconnect and reboot were not performed.

Full NixOS activation still requires an interactive sudo password. The old system
Home Manager activation remains installed until that switch; do it before reboot
to avoid reapplying the old setup. Unrelated existing HDR edits were preserved;
no whole Home Manager activation or desktop restart was performed by this task.

To stop animation, stop `blackmoon-wallpaper.service`; Hyprpaper remains visible.
Update Skwd only deliberately with `nix flake update skwd-wall`, not a broad input
update. To change the permanent video, edit this host's module and rebuild.
