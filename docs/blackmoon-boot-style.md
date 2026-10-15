# Blackmoon boot appearance

`machines/blackmoon/boot-style/default.nix` styles GRUB and the Linux virtual
console using `machines/blackmoon/home/app-palette.json`: charcoal, neutral white,
teal selection and lavender accents. The GRUB theme uses the bootloader's bundled
Unifont and tiny deterministic PNGs generated locally with Python's standard
library. It has no downloaded artwork or runtime dependencies.

Only Blackmoon imports this module. Its Catppuccin GRUB and TTY integrations are
disabled so they do not compete with the host palette. Shared boot policy remains
in `boot-efi.nix`: GRUB/EFI, OS detection and 25 retained generations. The existing
five-second menu timeout, firmware access, kernel/security parameters, console
font/keymap and diagnostic verbosity are preserved. Plymouth remains disabled.
Console colors reach early boot through the generated `vt.default_*` kernel
parameters; firmware output and text emitted before Linux takes over are not
controlled by this palette.

## Build and install for a later boot

From the repository root:

```sh
nix build .#nixosConfigurations.blackmoon.config.system.build.toplevel
sudo nixos-rebuild boot --flake .#blackmoon
```

The second command installs a boot generation and updates GRUB without switching
the running desktop or rebooting. Inspect the theme at the next normal boot.
Verify firmware-selected monitor/resolution, long generation labels, submenu
navigation and console readability on the real displays. A headless QEMU/OVMF
preview validates GRUB rendering but cannot reproduce the NVIDIA/firmware display
handoff. Existing generations remain available in GRUB's configurations submenu.
To revert the styling, remove the host's `./boot-style` import and rebuild for boot;
a previous system generation alone does not necessarily restore the shared GRUB
theme files until its bootloader installation is rerun.
