#!/usr/bin/env python3
"""Align Steam's existing Hyprland capture permission with the Dell ultrawide.

Never create a permission or change its approval list. Steam must obtain its
initial capture permission through the normal portal picker.
"""
import json
from pathlib import Path
import re
import subprocess

BUSCTL = "@busctl@"
HYPRCTL = "@hyprctl@"
SERVICE = "org.freedesktop.impl.portal.PermissionStore"
OBJECT = "/org/freedesktop/impl/portal/PermissionStore"


def run_json(args):
    return json.loads(subprocess.check_output(args, text=True, timeout=10))


def target_output(monitors):
    matches = [m for m in monitors if m.get("make") == "Dell Inc."
               and m.get("model") == "Dell AW3423DW"
               and not m.get("disabled", False)]
    if len(matches) != 1:
        raise ValueError("Expected one connected Dell AW3423DW; capture selection unchanged")
    return matches[0]["name"]


def replacement(record, output):
    """Return SetValue's variant arguments, or None when already correct.

    Fail closed on an unfamiliar portal schema instead of discarding fields.
    """
    if record.get("type") != "a{sas}v":
        raise ValueError("Unexpected permission-store response")
    permissions, variant = record["data"]
    if not any("yes" in values for values in permissions.values()):
        raise ValueError("Existing capture permission is not approved; use the portal picker")
    if variant.get("type") != "(suv)":
        raise ValueError("Unexpected portal restore variant")
    backend, version, payload = variant["data"]
    if (backend, version, payload.get("type")) != ("hyprland", 3, "a{sv}"):
        raise ValueError("Unsupported portal restore format; use the portal picker")
    fields = payload["data"]
    expected = {"withCursor": "u", "timeIssued": "t", "token": "s", "output": "s"}
    if set(fields) != set(expected) or any(fields[k].get("type") != t for k, t in expected.items()):
        raise ValueError("Unfamiliar restore fields; capture selection unchanged")
    if fields["output"]["data"] == output:
        return None
    args = ["(suv)", backend, str(version), "a{sv}", str(len(fields))]
    for key, value in fields.items():
        args += [key, value["type"], str(output if key == "output" else value["data"])]
    return args


def reconcile(home=Path.home()):
    output = target_output(run_json([HYPRCTL, "-j", "monitors"]))
    tokens = set()
    for config in (home / ".local/share/Steam/userdata").glob("*/config/localconfig.vdf"):
        tokens.update(re.findall(r'"DesktopCaptureRestoreToken"\s+"([^"\n]+)"', config.read_text()))
    if not tokens:
        print(f"Steam has no saved capture token; select Dell AW3423DW ({output}) in the portal picker")
        return
    base = [BUSCTL, "--user", "--json=short", "call", SERVICE, OBJECT, SERVICE]
    for token in tokens:
        before = run_json(base + ["Lookup", "ss", "screencast", token])
        args = replacement(before, output)
        if args is not None:
            subprocess.run(base + ["SetValue", "sbsv", "screencast", "false", token] + args,
                           check=True, capture_output=True, text=True, timeout=10)
            after = run_json(base + ["Lookup", "ss", "screencast", token])
            if after["data"][0] != before["data"][0] or replacement(after, output) is not None:
                raise ValueError("Capture readback did not match the requested output/permissions")
        print(f"Steam remembered capture: Dell AW3423DW ({output})")


if __name__ == "__main__":
    try:
        reconcile()
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        # Do not print D-Bus arguments (they contain the private restore token).
        print(f"Steam capture selection check failed: {type(error).__name__}; no fallback output selected")
        raise SystemExit(1)
