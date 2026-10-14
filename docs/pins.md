# Pins and compatibility overrides

Last reviewed: **2026-10-14**. `flake.lock` is the normal reproducibility boundary;
old lock timestamps alone are not reasons to remove a dependency. Prefer targeted
`nix flake update INPUT` and review the resulting diff.

| Component | Policy / reason | Removal or update condition | Verified |
| --- | --- | --- | --- |
| Hyprgrass `8e605468…` | ABI pairing for locked Hyprland 0.56.2; local tap-count patch preserves gesture behavior | Advance together using upstream `hyprpm.toml`; build and test touch gestures | 2026-10-14: retained |
| Brother brscan5 `1.6.2-0` | DS-640 device/path customizations; nixpkgs still has 1.3.1-0 | Compare vendor/upstream support, build and perform a real scan before removal | 2026-10-14: retained |
| AC Infinity `2.3.1` | Custom HA component absent from locked nixpkgs | Review release/manifest, update source hash, build, then verify devices after activation | 2026-10-14: updated from 2.2.0 |
| Bambu Lab `2.2.26` | Custom HA component absent from locked nixpkgs | Review upstream release and dependency changes; migrate when nixpkgs provides it | 2026-10-14: retained |
| BlackVue Sync `2.2.0` | Fixed upstream source with firmware API support | Review release, update hash, verify both camera workers | 2026-10-14: retained |
| File Dispatch | `flake.lock` owns reviewed revision `ad0637c…`; URL no longer repeats it | Targeted input update after upstream review | 2026-10-14: source unchanged |
| ChatGPT | Local version/hashes and guarded ASAR patch in `pkgs/chatgpt/` | Run updater, review patch anchors and build; retain guarded customization | 2026-10-14: unchanged |
| NVIDIA stable on Blackmoon | Kernel compatibility override, not an exact-version freeze | Verify another driver builds against the selected kernel and test graphics | 2026-10-14: retained |
| wvkbd / Qt virtual keyboard | Local layout, sizing and touch behavior | Remove only after equivalent behavior and device tests | 2026-10-14: retained |
| Codex zlib wrapper / X11 Rofi | Runtime library and host-specific behavior | Demonstrate upstream runtime fixes before removing | 2026-10-14: retained |
| SOPS Go-builder override | **Removed**: locked upstream now uses `buildGoModule` | Stock and overridden installer derivations were identical; shared NixOS and Comet HM shims removed | 2026-10-14 |

## Container images

`machines/gaia/container-images.nix` owns immutable registry manifest references.
Matter.js uses the `gaia.homeAssistant.matterjs.image` option. OTBR's recovery
scripts use the same configured image reference for their ancestor filters.
Matter.js no longer pulls a floating tag on each restart.

Registry manifests were fetched on 2026-10-14 through the authenticated public
registry APIs and the linux/amd64 child manifests inspected:

| Image | Manifest/index digest | amd64 config/image ID | Deployment comparison |
| --- | --- | --- | --- |
| Matter.js | `54232d0d3e7dff5a54759469d2753399270412b4c30c55b31750a4595e4cb236` | `a0e4feb33520b3ea1924c246914c84edcce3cf5bebb31855bc8dfff4aad451bc` | Matches Gaia's October 12 pull event |
| KOReader sync | `bb3f13615365703315a43b9059f65e71e876440f867e23a42bf27f2fa18264e1` | `d8449a32a7f08c839e9edde34aa2b1715022b0743e3ea7870761d9873eb656f7` | Matches Gaia's October 12 pull event |
| OTBR | `0010a108f54d352e293ea352e58a10a0831dcf7595e5eb598f4162b6267f28d1` | `3c9b07ad03c544b721f6f63fd1bc6f5f2e6c58398b3837f6ef57d7ccabac84f2` | **Update**: recent Gaia pull events show `fe1fc0ad…`; registry latest was published October 13 |

These are source pins, not a claim of runtime verification. The OTBR update must
be verified for radio attachment and Matter/Thread reports after activation.
Root Podman inspection was unavailable during preparation; comparisons above use
readable service journal events. No containers were restarted by this maintenance.
Home Assistant's existing package-version tag policy is unchanged.

To update: inspect the release and registry manifest, record the digest and image
ID here, change only the corresponding reference, run repository validation and
build Gaia. Keep the previous digest for rollback. After activation, check the
service and its real function (Thread attachment/reports, Matter devices, or
KOReader health/sync), not merely a running process. Rolling back configuration
does not roll back persistent application data.

## Sources

- [Hyprgrass compatibility map](https://github.com/horriblename/hyprgrass/blob/main/hyprpm.toml)
- [AC Infinity 2.3.1](https://github.com/dalinicus/homeassistant-acinfinity/releases/tag/2.3.1)
- [SOPS installer at the locked revision](https://github.com/Mic92/sops-nix/blob/ee48786c6f9160d2c1a084aac841f68195b8420c/pkgs/sops-install-secrets/default.nix)
- [Container reference syntax](https://github.com/containers/image/blob/main/docs/containers-transports.5.md)
- Registry APIs: `ghcr.io/v2/matter-js/matterjs-server/manifests/`,
  `registry-1.docker.io/v2/openthread/otbr/manifests/`, and
  `registry-1.docker.io/v2/koreader/kosync/manifests/`.

## Validation of the maintenance change

- Flake output check passed; AC Infinity 2.3.1 built with the manifest check.
- Full Blackmoon and Gaia system builds passed, without activation.
- All five NixOS Home Manager generation derivations match the pre-change baseline.
- Extracted homepage HTML, statistics collector and Matter naming tools preserve
  their generated store outputs. Python syntax and shell syntax checks passed.
- The all-output validation command passed 13 of 14 targets. It reports Comet's ARM Catppuccin palette build
  as a platform mismatch on Blackmoon; the known Comet SSH address was unreachable.
  Validate that target natively before deploying it.
