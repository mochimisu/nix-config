# Machine configuration

This flake manages five NixOS machines, one nix-darwin machine, and standalone
Home Manager profiles for Brandon, Cove and Comet.

- `flake.nix`: inputs and explicit per-host module lists. `mkNixosHost` shares only
  NixOS/Home Manager wiring, leaving host roles and imports visible.
- `common.nix`: shared NixOS policy; `common-packages.nix`: shared application catalog.
- `common-gui.nix`, `desktop.nix`, `common-gaming.nix`: graphical services, NixOS
  session ownership, and gaming policy respectively.
- `home/`: shared Home Manager applications; `home/desktop.nix`: user desktop settings.
- `machines/<host>/`: hardware, host policy, and host-specific services/home settings.
- `vars.nix`: typed shared options, including touchscreen and desktop settings.
- `overlays/`: package customizations. Gaia imports its Home Assistant overlays;
  Oasis and Espresso import touchscreen overlays.
- `pkgs/`: locally maintained packages. Gaia's large service scripts and homepage
  assets live adjacent to the modules that package them.

## Maintenance

Run `python3 scripts/validate.py` from any directory to evaluate every exported
NixOS, Home Manager, Darwin and package derivation, including the Gaia ISO.
It does not activate systems or update the lock. Evaluation may build small
import-from-derivation dependencies, so ARM targets require an ARM builder or
native runner. A failed target makes the command fail; nothing is silently skipped.
Use `--list` and repeatable `--target '<exact target>'` for native-machine checks.
Run `nix flake check --no-build --no-write-lock-file` for flake output validation too.

Stage new source files before evaluating a Git flake. Review `git diff --cached`
and `git diff`; ordinary lock updates should be narrow and deliberate.

[Pin register](docs/pins.md) tracks compatibility constraints and update procedures.
[Historical incidents](docs/agent-history.md) preserve earlier diagnoses; current
operational constraints belong in `AGENTS.md` or the owning service's documentation.
