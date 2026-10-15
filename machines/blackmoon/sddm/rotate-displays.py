"""Identify physical displays from Xrandr EDID, never Wayland connector names."""
import hashlib
import re
import subprocess
import sys

ACER = "51cdbaefa141f439750ae35893bf37932a55acd40369fb59778cc8ae47374b0c"
DELL = "d0d528e1d18f4976d2d87923d4d0c16958fdbe8a200847674035479c46466318"


def connected_edids(text):
    outputs = {}
    current = None
    collecting = False
    for line in text.splitlines():
        heading = re.match(r"^(\S+) (connected|disconnected)\b", line)
        if heading:
            current = heading[1] if heading[2] == "connected" else None
            collecting = False
        elif current and line.strip() == "EDID:":
            outputs[current] = ""
            collecting = True
        elif collecting:
            value = line.strip()
            if re.fullmatch(r"[0-9a-fA-F]{32}", value):
                outputs[current] += value
            else:
                collecting = False
    return {name: hashlib.sha256(bytes.fromhex(data)[:128]).hexdigest()
            for name, data in outputs.items() if len(data) >= 256}


def arguments(outputs):
    acer = [name for name, fingerprint in outputs.items() if fingerprint == ACER]
    dell = [name for name, fingerprint in outputs.items() if fingerprint == DELL]
    # Do nothing on absent/ambiguous identity rather than rotating another panel.
    if len(acer) != 1:
        return []
    args = ["--output", acer[0], "--rotate", "left"]
    if len(dell) == 1:
        args += ["--right-of", dell[0], "--output", dell[0], "--rotate", "normal", "--primary"]
    return args


def main():
    try:
        result = subprocess.run(["@xrandr@", "--props"], check=True, capture_output=True, text=True, timeout=5)
        args = arguments(connected_edids(result.stdout))
        if not args:
            print("Blackmoon SDDM: Acer EDID absent or ambiguous; keeping display defaults", file=sys.stderr)
            return
        print("Blackmoon SDDM: applying verified display layout: " + " ".join(args), file=sys.stderr)
        subprocess.run(["@xrandr@", *args], check=True, timeout=5)
    except (OSError, subprocess.SubprocessError, ValueError) as error:
        # Appearance failure must not prevent the login screen from starting.
        print(f"Blackmoon SDDM: display setup skipped: {error}", file=sys.stderr)


if __name__ == "__main__":
    main()
