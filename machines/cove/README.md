# Cove — SteamOS media machine

Cove is the x86_64 Valve Fremont / AMD Navi33 machine at `192.168.1.29`,
user `deck`. SteamOS owns the host and graphics session. Comet is the separate
ARM Steam Frame; its VR and desktop settings do not belong here.

## Configuration layout

| File | Responsibility |
| --- | --- |
| `home.nix` | Standalone Home Manager composition and shared packages/fonts |
| `media-apps.nix` | VacuumTube Flatpak, launcher and additive Steam registration |
| `mpv.nix` | mpv/FFmpeg, app-scoped graphics drivers, desktop entry and controls |
| `remote-controls.lua` | Small remote-friendly playback menu |
| `power.nix` | Plasma AC automatic-suspend setting |
| `mounts.nix` | Read-only Gaia automount and SteamOS update preservation |
| `save-gaia-credential.py` | Optional interactive credential provisioning on Cove |
| `cec-remote.nix`, `cec-remote.py` | Pending long-Back feature; deliberately not imported |

The file browser is shared with Comet through `../../home/mpv-browser.nix`.
Steam registration reuses Comet's existing `steam-apps.py` helper.
Gaia owns its Samba shares and restricted `cove-media` account in
`../gaia/samba.nix`; Cove does not administer the server.

## Apply and preserve

After the upstream Nix installer's Steam Deck setup, apply the user environment:

```sh
home-manager switch --flake ~/stuff/nix-config#deck@cove
cove-steam-apps          # inspect existing registrations
cove-steam-apps --apply  # add missing entries through the running Steam client
```

Home Manager declares packages, user configuration and desktop entries. Steam
owns Library registrations and existing customizations; the registrar preserves
matching entries. Flatpak profiles and credentials are private state under the
persistent home partition, not Git or Nix-store content.

System mount units require a separate root step because this is SteamOS, not
NixOS. After a mount configuration change, run on Cove:

```sh
sudo /home/deck/.nix-profile/bin/cove-install-host-integration
```

`mounts.nix` is the sole source for both units and the
`/etc/atomic-update.conf.d/cove-media.conf` preservation list. The installer copies
those files and enables the automount. No sudo policy, host graphics replacement,
background configuration-repair service or reboot is required.

The Nix installer separately preserves Nix's SteamOS integration. A fresh host
still needs that bootstrap, the declared user activation, Steam registration,
and the explicit system-mount install. A normal Home Manager switch alone does
not provision host Nix or root-owned system units.

## Gaia media

`~/Videos/Gaia` mounts `//gaia/cove-transmission` on demand, using encrypted
SMB3.1.1 with `ro,nosuid,nodev,noexec`. Local ownership is UID/GID1000; files are
0440 and directories0550. Initial mount timeout is10seconds and idle unmount is
120seconds. Existing I/O during a server outage can have additional CIFS recovery
delays. The mount does not require Gaia to be online at boot.

The server account has no shell or writable media-group membership. Its hidden
read-only share is restricted to `/earth/transmission`, requires encryption and
rejects symlink traversal. Samba passwords stay in Gaia's private Samba database.
For a fresh setup, the user runs `sudo smbpasswd -a cove-media` on Gaia after its
NixOS configuration is applied, then personally enters the same password through
`python3 ~/stuff/nix-config/machines/cove/save-gaia-credential.py` on Cove.
The helper refuses to overwrite an existing credential. Cove's credential file
is `~/.config/cove/gaia.smb`, owned by deck with mode0600; never commit its value.

The original live-provisioning and temporary Samba boot-bridge scripts are
obsolete after Gaia's reviewed rebuild. They were archived outside the checkout;
no service consumes them now. Do not reinstall that compatibility override.

## Playback and power

Native `/bin/sh` launchers clear Steam's injected library paths before invoking
Nix binaries. mpv selects matching Mesa drivers only for itself. Gaming Mode uses
Vulkan/x11vk, gamescope-wsi and HDR colorspace hints; Plasma uses the verified
OpenGL/VA-API fallback. SteamOS retains its compositor and system drivers.

Outside menus, Select toggles pause, Left/Right seek10seconds, Down opens subtitle
selection, and Back/Up opens the playback menu with Quit to Steam. uosc handles
arrows/Select and Back within its menus. Long Back is not enabled: physical CEC
press/repeat/release timing and actual Steam-menu behavior still need validation.

`power.nix` reapplies Plasma's AC automatic-suspend setting. Gaming Mode's saved
sleep Disabled / TV-off sleep off settings remain Steam-owned, not Nix-declared.
Display dimming and manual power controls are preserved.

## Verified state and limits

The live generation last verified was
`/nix/store/fhw9xgcikaavd5ra0fxpnix917ccvzki-home-manager-generation` (v8).
The source organization cleanup has not been activated.

- Normal Steam launch: actual mpv window/drawable3840x2160, and a true3840x2160
  HDR10 source decoded with Vulkan/p010, BT2020/PQ. HDMI signaling was separately
  verified at10bpc/PQ with source metadata. Sustained arbitrary4K playback is not
  claimed; the reported1080p limitation was not reproduced in this test.
- H264/HEVC/AV1 and AAC/AC3/EAC3 are present. SDR and HDR samples played through the
  registered Steam entry; Plasma's SDR fallback was checked.
- Synthetic player input tests passed pause/resume, precise seeking, menu
  open/close and subtitle disable/re-enable. Physical remote confirmation remains.
- Encrypted media reads, denied writes and denied access to Gaia's broader share
  passed. Root mount units/update-preservation were verified; no reboot/update or
  real server outage was induced as a test.

Evidence and temporary test files live in `~/.local/state/cove-setup`. The temporary
`~/.config/mpv/scripts/cove-verification.lua` and local IPC remain from paused
input testing; remove them when that test finishes. They are not production Nix
configuration. Keep existing app profiles, credentials and user-owned root tmux
sessions intact. No authentication or account contents are stored in this folder.
