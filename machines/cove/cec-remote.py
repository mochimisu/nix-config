"""Cove-only CEC Back hold; no root, key logging, or non-CEC input access."""
import os
from pathlib import Path
import select
import signal
import subprocess
import time

from evdev import InputDevice, UInput, ecodes as E

SOURCE_NAME = 'cecd cros-ec-cec'
HOLD_SECONDS = 0.8


class BackButton:
    def __init__(self, short, long):
        self.short, self.long = short, long
        self.started = None
        self.fired = False

    def event(self, value, now):
        if value == 1 and self.started is None:
            self.started, self.fired = now, False
        elif value == 0 and self.started is not None:
            self.tick(now)
            if not self.fired:
                self.short()
            self.started, self.fired = None, False
        # Kernel repeat events retain the original press time.

    def tick(self, now):
        if self.started is not None and not self.fired and now - self.started >= HOLD_SECONDS:
            self.fired = True
            self.long()


def source_path():
    # Inspect sysfs names; never open unrelated keyboards to find this device.
    for path in Path('/sys/class/input').glob('event*/device/name'):
        try:
            if path.read_text().strip() == SOURCE_NAME:
                return '/dev/input/' + path.parent.parent.name
        except OSError:
            continue
    return None


def gaming_mode():
    return subprocess.run(['/usr/bin/pgrep', '-u', str(os.getuid()), '-x', 'gamescope'],
                          stdout=subprocess.DEVNULL).returncode == 0


def steam_menu():
    # Same XTest Ctrl+1 sequence used by Gamescope's wlserver_open_steam_menu.
    # Root Xwayland belongs to Steam, independent of the currently focused app.
    env = dict(os.environ, DISPLAY=':0')
    subprocess.run(['/usr/bin/xdotool', 'key', '--delay', '0', 'ctrl+1'],
                   env=env, check=True, timeout=3)


def relay(path):
    with InputDevice(path) as source:
        if source.name != SOURCE_NAME:
            raise RuntimeError('CEC device identity changed')
        with UInput.from_device(source, name='Cove CEC remote', phys='cove/cec-remote') as output:
            # Create the replacement before grabbing. Any process exit releases grab.
            source.grab()
            pressed = set()
            def short():
                output.write(E.EV_KEY, E.KEY_ESC, 1)
                output.syn()
                output.write(E.EV_KEY, E.KEY_ESC, 0)
                output.syn()
            button = BackButton(short, steam_menu)
            try:
                check_session = time.monotonic()
                while True:
                    now = time.monotonic()
                    if now - check_session >= 2:
                        if not gaming_mode():
                            return
                        check_session = now
                    if select.select([source.fd], [], [], 0.025)[0]:
                        for event in source.read():
                            if event.type == E.EV_KEY and event.code == E.KEY_ESC:
                                button.event(event.value, time.monotonic())
                            elif event.type in (E.EV_KEY, E.EV_MSC, E.EV_SYN):
                                output.write_event(event)
                                if event.type == E.EV_KEY:
                                    if event.value == 1:
                                        pressed.add(event.code)
                                    elif event.value == 0:
                                        pressed.discard(event.code)
                    button.tick(time.monotonic())
            finally:
                for key in pressed:
                    output.write(E.EV_KEY, key, 0)
                output.syn()
                source.ungrab()


def main():
    if Path('/proc/sys/kernel/hostname').read_text().strip() != 'cove':
        raise RuntimeError('This relay is restricted to Cove')
    if os.getuid() == 0:
        raise RuntimeError('Run as the desktop user, never root')
    signal.signal(signal.SIGTERM, lambda *_: (_ for _ in ()).throw(SystemExit(0)))
    while True:
        path = source_path()
        if path and gaming_mode():
            try:
                relay(path)
            except (OSError, subprocess.SubprocessError) as error:
                print('CEC relay released; retrying:', type(error).__name__, flush=True)
        time.sleep(2)


if __name__ == '__main__':
    main()
