"""Refresh ChatGPT pins from OpenAI's Debian indexes; run from the repo root."""

import base64
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

BASE = "https://persistent.oaistatic.com/codex-app-prod/linux/deb"
ARCHES = {"x86_64-linux": "amd64", "aarch64-linux": "arm64"}


def releases(index, arch):
    result = {}
    for paragraph in re.split(r"\n\s*\n", index.strip()):
        fields = dict(
            line.split(": ", 1)
            for line in paragraph.splitlines()
            if not line.startswith((" ", "\t")) and ": " in line
        )
        if fields.get("Package") != "chatgpt":
            continue
        version = fields.get("Version", "")
        if not re.fullmatch(r"\d+(?:\.\d+)+", version):
            raise ValueError(f"Unsupported upstream version: {version!r}")
        if fields.get("Architecture") != arch:
            raise ValueError(f"Unexpected architecture in {arch} index")
        expected = f"pool/main/c/chatgpt/chatgpt_{version}_{arch}.deb"
        if fields.get("Filename") != expected:
            raise ValueError(f"Unexpected download path for {arch} {version}")
        digest = fields.get("SHA256", "")
        if not re.fullmatch(r"[0-9a-fA-F]{64}", digest):
            raise ValueError(f"Invalid SHA256 for {arch} {version}")
        sri = "sha256-" + base64.b64encode(bytes.fromhex(digest)).decode()
        if version in result and result[version] != sri:
            raise ValueError(f"Conflicting hashes for {arch} {version}")
        result[version] = sri
    return result


def replace_once(pattern, value, text):
    updated, count = re.subn(pattern, lambda m: m[1] + value + m[2], text)
    if count != 1:
        raise ValueError(f"Expected exactly one package field matching {pattern!r}")
    return updated


def main():
    package = Path("pkgs/chatgpt/package.nix")
    original = package.read_text()
    versions = re.findall(r'  version = "([0-9.]+)";', original)
    if len(versions) != 1:
        raise ValueError("Expected exactly one pinned ChatGPT version")
    current = versions[0]
    indexes = {}
    for system, arch in ARCHES.items():
        index = subprocess.check_output(
            ["curl", "--fail", "--silent", "--show-error", "--location",
             "--retry", "2", "--connect-timeout", "15", "--max-time", "60",
             f"{BASE}/dists/stable/main/binary-{arch}/Packages"],
            text=True,
        )
        indexes[system] = releases(index, arch)
    common = set.intersection(*(set(index) for index in indexes.values()))
    if not common:
        raise ValueError("No ChatGPT release available for both architectures")
    version_key = lambda v: tuple(map(int, v.split(".")))
    latest = max(common, key=version_key)
    if version_key(latest) < version_key(current):
        print(f"ChatGPT: keeping {current}; upstream common release is older ({latest}).")
        return
    updated = replace_once(r'(  version = ")[^"]+(";)', latest, original)
    for system in ARCHES:
        pattern = rf'({re.escape(system)} = \{{\s*arch = "[^"]+";\s*hash = ")[^"]+(";)'
        updated = replace_once(pattern, indexes[system][latest], updated)
    if updated == original:
        print(f"ChatGPT: already up to date ({current}).")
        return
    if latest == current:
        raise ValueError("Upstream hashes changed for the pinned version; inspect manually")
    # Validate all metadata before writing, and preserve the original on failure.
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", dir=package.parent, delete=False) as f:
            temporary = Path(f.name)
            f.write(updated)
        temporary.chmod(package.stat().st_mode & 0o777)
        if package.read_text() != original:
            raise ValueError("Package changed during update; retry after other edits finish")
        os.replace(temporary, package)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)
    print(f"ChatGPT: {current} -> {latest}; updated both architecture hashes.")
    print("Build and install with your normal NixOS rebuild (nix-rs).")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"ChatGPT update failed; pins unchanged: {error}", file=sys.stderr)
        sys.exit(1)
