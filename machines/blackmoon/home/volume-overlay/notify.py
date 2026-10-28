"""Forward a Mako event, never read or modify the audio device."""
import json
import re
import subprocess
import sys


def query(command):
    return json.loads(subprocess.check_output(command, text=True, timeout=2))


def main():
    notification = next((n for n in query(["@makoctl@", "list", "-j"])
                         if n["id"] == int(sys.argv[1])), None)
    if notification is None:
        return  # Expired while queued; do not resurrect stale feedback.
    match = re.fullmatch(r"Volume · (?:(\d+)%|(muted))", notification["summary"])
    if not match:
        return
    monitors = query(["@hyprctl@", "monitors", "-j"])
    monitor = next((m for m in monitors if m.get("focused")), monitors[0])
    subprocess.run(["@qs@", "ipc", "-p", "@config@", "call", "--", "volume", "show",
                    match[1] or "0", "true" if match[2] else "false",
                    monitor["name"], str(monitor.get("reserved", [0, 0, 0, 0])[3])],
                   check=True, timeout=2)


if __name__ == "__main__":
    main()
