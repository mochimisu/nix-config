"""Add declared apps through Valve's helper; never write Steam's VDF files."""
import argparse
import fcntl
import json
import os
import shlex
from pathlib import Path
import subprocess
import sys
import time
import vdf


def shortcuts(path):
    if not path.exists():
        return []
    with path.open("rb") as stream:
        return list(vdf.binary_load(stream).get("shortcuts", {}).values())


def matches(entry, app):
    fields = {key.lower(): value for key, value in entry.items()}
    executable = fields.get("exe", "").strip('"')
    if executable == app.get("executable"):
        return True
    # Preserve already-registered Flatpaks from the original native launcher.
    return (bool(app.get("appId")) and executable == "/usr/bin/flatpak"
            and app["appId"] in shlex.split(fields.get("launchoptions", "")))



def main():
    manifest = Path(sys.argv[1])
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", help="submit missing entries to running Steam; may show Steam UI")
    parser.add_argument("--account", help="numeric Steam userdata directory; required if more than one exists")
    args = parser.parse_args(sys.argv[2:])
    apps = json.loads(manifest.read_text())
    root = Path.home() / ".local/share/Steam/userdata"
    accounts = [p for p in root.iterdir() if p.name.isdigit() and (p / "config").is_dir()]
    if args.account:
        accounts = [p for p in accounts if p.name == args.account]
    if len(accounts) != 1:
        parser.error("Specify --account for exactly one existing Steam userdata directory.")
    target = accounts[0] / "config/shortcuts.vdf"
    state = Path.home() / ".local/state/comet-steam-apps" / accounts[0].name
    lock = None
    try:
        if args.apply:
            state.mkdir(parents=True, exist_ok=True, mode=0o700)
            lock = (state / "lock").open("w")
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        pending = False
        for app in apps:
            entries = shortcuts(target)
            existing = [entry for entry in entries if matches(entry, app)]
            if existing:
                print(f'{app["name"]}: registered; existing shortcut preserved')
                continue
            if any(str(entry.get("AppName", entry.get("appname", ""))).casefold() == app["name"].casefold() for entry in entries):
                raise RuntimeError(f'{app["name"]}: name conflict; refusing to modify a manual shortcut')
            receipt = state / ((app.get("appId") or app["key"]) + ".requested.json")
            if receipt.exists():
                print(f'{app["name"]}: previously submitted; Steam has not saved a matching entry yet (not resubmitting)')
                pending = True
                continue
            if app.get("appId"):
                subprocess.run(["/usr/bin/flatpak", "info", "--user", app["appId"]], check=True, stdout=subprocess.DEVNULL)
            if app.get("executable") and not os.access(app["executable"], os.X_OK):
                raise RuntimeError(f'Missing executable launcher: {app["executable"]}')
            if not args.apply:
                print(f'{app["name"]}: installed; Steam registration pending (--apply)')
                pending = True
                continue
            # The Valve helper contacts the running client. Never start or restart it.
            subprocess.run(["/usr/bin/pgrep", "-u", str(os.getuid()), "-x", "steam"], check=True, stdout=subprocess.DEVNULL)
            if not Path(app["desktop"]).is_file():
                raise RuntimeError(f'Missing desktop entry: {app["desktop"]}')
            # Record before IPC so a crash cannot cause automatic duplicate submission.
            receipt.write_text(json.dumps({"app": app, "submitted_at": time.time()}) + "\n")
            env = dict(os.environ, PATH="/usr/bin:/bin")
            subprocess.run(["/usr/bin/steamos-add-to-steam", app["desktop"]], check=True, env=env)
            for _ in range(20):
                if any(matches(entry, app) for entry in shortcuts(target)):
                    print(f'{app["name"]}: registered and verified in Steam shortcuts')
                    break
                time.sleep(0.25)
            else:
                print(f'{app["name"]}: submitted; persistence pending Steam confirmation')
                pending = True
        return 3 if pending else 0
    finally:
        if lock is not None:
            lock.close()



if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError) as error:
        sys.exit(str(error))
