#!/usr/bin/env python3
"""Give only the newly launched VacuumTube X11 window its existing Steam ID.

The outer launcher owns the singleton lock. This helper never launches Steam,
changes focus, remaps input, or touches root-window properties.
"""
import os
from pathlib import Path
import re
import subprocess
import sys
import time

APP_ID = 2518984771
CLASS = 'WM_CLASS(STRING) = "vacuumtube", "vacuumtube"'


def command(*args):
    try:
        return subprocess.run(args, capture_output=True, text=True, timeout=3)
    except (OSError, subprocess.TimeoutExpired):
        # Input association must not terminate the app or release its lock.
        return subprocess.CompletedProcess(args, 1, '', '')


def windows():
    result = command('/usr/bin/xwininfo', '-root', '-tree')
    if result.returncode:
        return set()
    return set(re.findall(r'^\s+(0x[0-9a-fA-F]+) ', result.stdout, re.M))


def app_pids(root_pid):
    """Match the actual app in this launch's process subtree, including NSpid."""
    processes = {}
    for path in Path('/proc').glob('[0-9]*'):
        try:
            status = dict(line.split(':', 1) for line in (path / 'status').read_text().splitlines() if ':' in line)
            processes[int(path.name)] = (int(status['PPid']), status, path)
        except (OSError, ValueError, KeyError):
            continue
    descendants = {root_pid}
    while True:
        found = {pid for pid, (parent, _, _) in processes.items() if parent in descendants}
        if found <= descendants:
            break
        descendants |= found
    result = set()
    for pid in descendants:
        if pid not in processes:
            continue
        _, status, path = processes[pid]
        try:
            executable = (path / 'cmdline').read_bytes().split(b'\0')[0]
            if executable.rsplit(b'/', 1)[-1] == b'vacuumtube':
                result.add(pid)
                result.update(map(int, status.get('NSpid', '').split()))
        except (OSError, ValueError):
            continue
    return result


def associate(window, allowed_pids):
    props = command('/usr/bin/xprop', '-id', window, 'WM_CLASS', '_NET_WM_PID', 'STEAM_GAME')
    if props.returncode or CLASS not in props.stdout.splitlines():
        return False
    pid = re.search(r'^_NET_WM_PID\(CARDINAL\) = (\d+)$', props.stdout, re.M)
    if not pid or int(pid.group(1)) not in allowed_pids:
        return False
    current = re.search(r'^STEAM_GAME\(CARDINAL\) = (\d+)$', props.stdout, re.M)
    if current:
        # Never overwrite a different association.
        return int(current.group(1)) == APP_ID
    changed = command('/usr/bin/xprop', '-id', window, '-f', 'STEAM_GAME', '32c', '-set', 'STEAM_GAME', str(APP_ID))
    if changed.returncode:
        return False
    check = command('/usr/bin/xprop', '-id', window, 'STEAM_GAME')
    return check.stdout.strip() == f'STEAM_GAME(CARDINAL) = {APP_ID}'


def main():
    baseline = windows() if os.environ.get('DISPLAY') else set()
    child = subprocess.Popen(['/usr/bin/flatpak', 'run', '--user', 'rocks.shy.VacuumTube', *sys.argv[1:]])
    try:
        deadline = time.monotonic() + 30
        while os.environ.get('DISPLAY') and child.poll() is None and time.monotonic() < deadline:
            owners = app_pids(child.pid)
            if any(associate(window, owners) for window in windows() - baseline):
                print('VacuumTube window associated with its Steam Input app ID.', file=sys.stderr)
                break
            time.sleep(0.5)
        return child.wait()
    except KeyboardInterrupt:
        # Do not leave an unguarded child using the authenticated profile.
        if child.poll() is None:
            child.terminate()
        return child.wait()


if __name__ == '__main__':
    raise SystemExit(main())
