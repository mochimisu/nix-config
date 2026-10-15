# Desktop style regression checks

Run from the repository root on a Linux desktop build host:

```sh
nix eval --impure --json --file tests/desktop/options.nix
nix eval --impure --json --file tests/desktop/matrix.nix --apply 'f: f {}'
nix build .#nixosConfigurations.blackmoon.config.home-manager.users.brandon.home.activationPackage --out-link /tmp/style-home
runner=$(nix-build tests/desktop --no-out-link)
"$runner/bin/test-desktop-style" --repo "$PWD" --generation /tmp/style-home --output /tmp/style-test-results
```

The runner starts private Xvfb and headless Sway instances with temporary runtime,
config and cache directories. It uses private session buses, denies access to the
system bus, disables production helper processes, and substitutes action callbacks
with recorded calls. It never deploys configuration or invokes real power, network,
audio or application-launch actions. An unavailable renderer/compositor fails the
test rather than silently skipping it. Logs and PNGs remain in `--output`.

Coverage:

- Bare typed style options default off, reject invalid types, and enable independently.
  The matrix test asserts capability defaults on native hosts, Gaia exclusion,
  and Cove ownership. For Comet use `--apply 'f: f {includeComet=true;}'` with an ARM builder.
  This check is platform-independent and does not force Comet's ARM packages.
- Real sidebar QML: workspace and all ten control actions, audio selection,
  compact 420/220px layouts, scrolling through 40 outputs, and unthemed defaults.
- Real launcher QML: transformed inside/outside hit testing, held-release dismissal,
  no click-through, and normal/compact viewports. Pointer unit tests separately
  cover rotated/scaled/negative-origin outputs and disconnected-output rejection.
- Real greeter: remembered account, selected session, duplicate submission, failure
  clearing, layout selection, compact focus, and real optional Qt Virtual Keyboard
  sizing/visibility at 1280×800 and 800×600. Authentication/power calls are mocked.
- Real Eww: long process names and 0–3200% CPU values on a private 1440×112 output;
  Wayland configure events assert the actual layer size. Screenshots expose clipping
  or misleading track scaling for review. No synthetic values reach the live bar.
- Existing search-ranking, media-OSD and EDID selection tests.

For a refactor, save the previous sidebar source and pass
`--baseline-sidebar /path/to/previous-shell.qml`. Both versions receive identical
fixture state. Pixel comparisons permit only sparse one-level GPU edge rounding
(at most 0.1% of channels, maximum 1/255), not geometry/text/color changes. PNG
metadata is ignored. This does not certify actual hardware touch or GPU behavior.

Compare built Home Manager generations with:

```sh
python3 tests/desktop/compare.py BEFORE_GENERATION AFTER_GENERATION --host blackmoon
```

The comparison fails on unexpected managed-file or content changes. It understands
only the explicit sidebar option substitution, the relocated non-overlapping
notification rule/launcher binding, and an equivalent profile path whose symlink
target membership is unchanged. Remove/update that narrow migration allowance
when future intentional behavior changes make it obsolete.

`python3 scripts/validate.py` evaluates every exported configuration. Comet's full
Home Manager evaluation still requires an ARM builder for Catppuccin's palette
import-from-derivation. A passing portable option test does not replace that build,
software-renderer validation, or a real nested-session test.
