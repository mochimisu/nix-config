#!/usr/bin/env python3
"""Evaluate every exported deployable configuration without activation or lock updates.

Nix evaluation can require import-from-derivation builds. Configure native/remote
builders for each platform, or use --target on the appropriate native machine.
"""
import argparse
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
BASE = ["nix", "eval", "--no-write-lock-file", "--option", "eval-cache", "false"]


def discover(attr):
    result = subprocess.run(
        BASE + ["--json", "--apply", "builtins.attrNames", f".#{attr}"],
        cwd=ROOT, text=True, capture_output=True, check=True,
    )
    return json.loads(result.stdout)


def targets():
    for group, suffix in [
        ("nixosConfigurations", "config.system.build.toplevel.drvPath"),
        ("homeConfigurations", "activationPackage.drvPath"),
        ("darwinConfigurations", "system.drvPath"),
    ]:
        for name in discover(group):
            yield f"{group}.{json.dumps(name)}.{suffix}"
    for system in discover("packages"):
        for name in discover(f"packages.{system}"):
            yield f"packages.{system}.{json.dumps(name)}.drvPath"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--list", action="store_true", help="List targets without evaluating their derivations")
    parser.add_argument("--target", action="append", default=[], help="Evaluate only this exact target from --list (repeatable)")
    args = parser.parse_args()
    available = list(targets())
    if args.list:
        print("\n".join(available))
        return 0
    unknown = set(args.target) - set(available)
    if unknown:
        parser.error("unknown targets: " + ", ".join(sorted(unknown)))
    selected = args.target or available
    failures = []
    for attr in selected:
        print(f"Checking {attr}", flush=True)
        result = subprocess.run(BASE + ["--raw", ".#" + attr], cwd=ROOT, text=True, capture_output=True)
        if result.returncode:
            failures.append(attr)
            print(result.stderr, file=sys.stderr)
        else:
            # Keep warnings visible; a successful evaluation is not a full build.
            if result.stderr:
                print(result.stderr, file=sys.stderr, end="")
            print(result.stdout)
    print(f"Evaluated {len(selected) - len(failures)}/{len(selected)} targets successfully.")
    if failures:
        print("Failed targets:\n" + "\n".join(failures), file=sys.stderr)
    return bool(failures)


if __name__ == "__main__":
    sys.exit(main())
