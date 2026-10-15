"""Resolve each launcher show from the current pointer and Skwd output state."""
import json
import subprocess
from pathlib import Path


def query(command):
    return json.loads(subprocess.check_output(command, text=True, timeout=2))


def pointer_output(monitors, cursor):
    for monitor in monitors:
        if monitor.get("disabled"):
            continue
        width, height = monitor["width"], monitor["height"]
        if monitor.get("transform", 0) % 2:
            width, height = height, width
        scale = monitor.get("scale", 1)
        if (monitor["x"] <= cursor["x"] < monitor["x"] + width / scale
                and monitor["y"] <= cursor["y"] < monitor["y"] + height / scale):
            return monitor["name"]
    raise RuntimeError("Pointer is not on a connected output")


def main():
    name = pointer_output(query(["@hyprctl@", "-j", "monitors"]),
                          query(["@hyprctl@", "-j", "cursorpos"]))
    result = {"monitor": name, "wallpaper": "", "video": False}
    try:
        outputs = query(["@skwd@", "current", "--json"])["outputs"]
        selected = next(output for output in outputs if output["name"] == name)
        path = Path(selected.get("path") or selected.get("current", ""))
        if path.is_file() and selected.get("type") in ("video", "image"):
            result.update(wallpaper=path.as_uri(), video=selected["type"] == "video")
    except (OSError, ValueError, KeyError, StopIteration, subprocess.SubprocessError):
        pass  # Neutral header if Skwd is unavailable; never a stale static wallpaper.
    print(json.dumps(result))


if __name__ == "__main__":
    main()
