"""Comet-only Steam AC idle leases. No battery, button or system policy writes."""
import base64
import contextlib
import fcntl
import hashlib
import json
import os
from pathlib import Path
import signal
import socket
import struct
import subprocess
import sys
import time
import urllib.parse
import urllib.request
import uuid

UNIT = 'comet-caffeine.service'
ROOT = Path(os.environ.get('XDG_STATE_HOME', str(Path.home() / '.local/state'))) / 'comet-caffeine'
AC = 'system_idle_suspend_ac_sec'
BAT = 'system_idle_suspend_battery_sec'


def atomic(path, value):
    temp = path.with_suffix('.tmp')
    temp.write_text(json.dumps(value))
    temp.chmod(0o600)
    temp.replace(path)


def read_json(path, default=None):
    return json.loads(path.read_text()) if path.exists() else default


@contextlib.contextmanager
def locked(root):
    root.mkdir(mode=0o700, parents=True, exist_ok=True)
    with (root / 'lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        yield


def identity(pid):
    # starttime prevents PID reuse; boot ID prevents stale leases after reboot.
    stat = Path(f'/proc/{pid}/stat').read_text().rsplit(')', 1)[1].split()
    if stat[0] == 'Z':
        raise ProcessLookupError(pid)
    return [Path('/proc/sys/kernel/random/boot_id').read_text().strip(), stat[19]]


class Steam:
    """Use the already enabled loopback Steam diagnostic endpoint, never enable it."""
    def evaluate(self, expression):
        with urllib.request.urlopen('http://127.0.0.1:8080/json/list', timeout=4) as response:
            pages = json.load(response)
        page = next(p for p in pages if p.get('title') == 'SharedJSContext')
        url = urllib.parse.urlparse(page['webSocketDebuggerUrl'])
        if url.hostname not in ('127.0.0.1', 'localhost') or url.port != 8080:
            raise RuntimeError('Unexpected Steam diagnostic endpoint')
        with socket.create_connection(('127.0.0.1', 8080), timeout=5) as sock:
            key = base64.b64encode(os.urandom(16)).decode()
            sock.sendall((f'GET {url.path} HTTP/1.1\r\nHost: 127.0.0.1:8080\r\n'
                          f'Upgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: {key}\r\n'
                          'Sec-WebSocket-Version: 13\r\n\r\n').encode())
            def read(n):
                data = b''
                while len(data) < n:
                    part = sock.recv(n - len(data))
                    if not part:
                        raise ConnectionError('Steam diagnostic connection closed')
                    data += part
                return data
            header = b''
            while not header.endswith(b'\r\n\r\n'):
                header += read(1)
                if len(header) > 16384:
                    raise RuntimeError('Oversized WebSocket header')
            accept = base64.b64encode(hashlib.sha1((key + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11').encode()).digest())
            if not header.startswith(b'HTTP/1.1 101') or accept not in header:
                raise RuntimeError('Steam diagnostic WebSocket handshake failed')
            def send(payload, opcode=1):
                mask = os.urandom(4)
                n = len(payload)
                length = bytes([128 | n]) if n < 126 else bytes([254]) + struct.pack('!H', n)
                sock.sendall(bytes([128 | opcode]) + length + mask + bytes(v ^ mask[i % 4] for i, v in enumerate(payload)))
            send(json.dumps({'id': 1, 'method': 'Runtime.evaluate', 'params': {
                'expression': expression, 'returnByValue': True, 'awaitPromise': True}}).encode())
            fragments = b''
            deadline = time.monotonic() + 8
            while time.monotonic() < deadline:
                head = read(2)
                n = head[1] & 127
                if n == 126:
                    n = struct.unpack('!H', read(2))[0]
                elif n == 127:
                    n = struct.unpack('!Q', read(8))[0]
                if n > 4 * 1024 * 1024:
                    raise RuntimeError('Oversized Steam response')
                mask = read(4) if head[1] & 128 else None
                data = read(n)
                if mask:
                    data = bytes(v ^ mask[i % 4] for i, v in enumerate(data))
                opcode = head[0] & 15
                if opcode == 8:
                    raise ConnectionError('Steam closed diagnostic connection')
                if opcode == 9:
                    send(data, 10)
                    continue
                if opcode not in (0, 1):
                    continue
                fragments += data
                if not head[0] & 128:
                    continue
                message = json.loads(fragments)
                fragments = b''
                if message.get('id') != 1:
                    continue
                result = message.get('result', {})
                if 'exceptionDetails' in result or 'error' in message:
                    raise RuntimeError('Steam settings operation failed')
                return result['result'].get('value')
            raise TimeoutError('Steam settings operation timed out')

    def read(self):
        result = self.evaluate(f'({{ac:settingsStore.clientSettings.{AC},battery:settingsStore.clientSettings.{BAT}}})')
        if not isinstance(result, dict) or any(type(result.get(k)) is not int or result[k] < 0 for k in ('ac', 'battery')):
            raise RuntimeError('Steam idle settings unavailable')
        return result

    def set_ac(self, expected, value):
        # Same protobuf-setting wrapper used by the installed Steam settings UI.
        result = self.evaluate('''(async () => {
          const before = settingsStore.clientSettings;
          const battery = before.system_idle_suspend_battery_sec;
          if (before.system_idle_suspend_ac_sec !== EXPECTED) return false;
          let req;
          webpackChunksteamui.push([[Symbol()], {}, r => { req = r }]);
          const module = Object.keys(req.m).map(id => req.m[id].toString().includes("Settings.SetSetting") ? req(id) : null).find(Boolean);
          if (!module) throw Error("Steam settings wrapper unavailable");
          const set = Object.values(module).find(f => typeof f === "function" && f.toString().includes("Settings.SetSetting("));
          if (!set) throw Error("Steam settings setter unavailable");
          await set("system_idle_suspend_ac_sec", VALUE);
          await new Promise(r => setTimeout(r, 300));
          if (settingsStore.clientSettings.system_idle_suspend_battery_sec !== battery) throw Error("Battery setting changed externally");
          if (settingsStore.clientSettings.system_idle_suspend_ac_sec !== VALUE) throw Error("AC setting readback failed");
          return true;
        })()'''.replace('EXPECTED', str(int(expected))).replace('VALUE', str(int(value))))
        return result is True


class Guard:
    def __init__(self, root, steam):
        self.root, self.steam = root, steam

    def step(self):
        root = self.root
        with locked(root):
            leases = {}
            for path in root.glob('lease-*.json'):
                lease = {}
                try:
                    lease = read_json(path)
                    alive = identity(lease['pid']) == lease['identity']
                except (OSError, KeyError, ValueError):
                    alive = False
                if alive:
                    leases[path.stem] = lease
                else:
                    # A killed client must not leave its wrapped command/inhibitor orphaned.
                    try:
                        child = lease.get('child')
                        if child and identity(child['pid']) == child['identity']:
                            os.killpg(child['pid'], signal.SIGTERM)
                    except (OSError, UnboundLocalError):
                        pass
                    path.unlink(missing_ok=True)
            state = read_json(root / 'restore.json')
            phase, detail = 'idle', ''
            try:
                if state and state.get('overridden'):
                    phase = 'overridden'
                    if not leases:
                        (root / 'restore.json').unlink()
                        phase = 'idle'
                elif leases or state:
                    current = self.steam.read()
                    if not state and leases:
                        state = {'previous': current['ac'], 'overridden': False}
                        # Write intent before mutation so a crash can recover.
                        atomic(root / 'restore.json', state)
                        if current['ac'] != 0 and not self.steam.set_ac(current['ac'], 0):
                            state['overridden'] = True
                            atomic(root / 'restore.json', state)
                            raise RuntimeError('AC setting changed before acquisition')
                        current = self.steam.read()
                        if current['ac'] != 0:
                            raise RuntimeError('Steam AC Never could not be confirmed')
                    if leases:
                        if current['ac'] != 0:
                            state['overridden'] = True
                            atomic(root / 'restore.json', state)
                            phase = 'overridden'
                        else:
                            phase = 'active'
                    else:
                        # Restore only when the value still matches our Never.
                        if current['ac'] == 0 and state['previous'] != 0:
                            if not self.steam.set_ac(0, state['previous']):
                                raise RuntimeError('AC setting changed during restoration')
                        (root / 'restore.json').unlink()
                        phase = 'idle'
            except Exception as exc:
                phase, detail = 'unavailable', str(exc)
            atomic(root / 'status.json', {'phase': phase, 'detail': detail,
                   'leases': list(leases), 'updated': time.time()})
            return phase, detail


def guard():
    manager = Guard(ROOT, Steam())
    previous = None
    while True:
        result = manager.step()
        if result != previous:
            print('caffeine guard:', *result, flush=True)
            previous = result
        time.sleep(1)


def client(command):
    if subprocess.run(['/usr/bin/pkcheck', '--action-id', 'org.freedesktop.login1.inhibit-block-sleep', '--process', str(os.getpid())], stdout=subprocess.DEVNULL).returncode:
        raise RuntimeError('Sleep inhibition unauthorized; use a local graphical terminal. Command not started.')
    token = 'lease-' + uuid.uuid4().hex
    path = ROOT / (token + '.json')
    child = None
    signalled = 0
    def stop(sig, _frame):
        nonlocal signalled
        signalled = sig
        if child and child.poll() is None:
            os.killpg(child.pid, sig)
    for sig in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP):
        signal.signal(sig, stop)
    try:
        with locked(ROOT):
            atomic(path, {'pid': os.getpid(), 'identity': identity(os.getpid())})
        subprocess.run(['/usr/bin/systemctl', '--user', 'start', UNIT], check=True)
        deadline = time.monotonic() + 20
        while not signalled:
            status = read_json(ROOT / 'status.json', {})
            if token in status.get('leases', []):
                if status['phase'] == 'active' and time.time() - status['updated'] < 5:
                    break
                if status['phase'] in ('overridden', 'unavailable'):
                    raise RuntimeError('Steam AC sleep timer not acquired: ' + status.get('detail', status['phase']))
            if time.monotonic() > deadline:
                raise RuntimeError('Steam AC sleep timer acquisition timed out')
            time.sleep(.2)
        if signalled:
            return 128 + signalled
        child = subprocess.Popen(['/usr/bin/systemd-inhibit', '--no-ask-password', '--what=idle:sleep', '--mode=block', '--who=caffeine', '--why=Temporary user-requested idle and sleep inhibition', '--'] + command, start_new_session=True)
        with locked(ROOT):
            lease = read_json(path)
            try:
                lease['child'] = {'pid': child.pid, 'identity': identity(child.pid)}
                atomic(path, lease)
            except OSError:
                pass  # A very short command may already have finished.
        print('caffeine: Steam AC sleep is Never; battery timer unchanged. Last exit restores prior AC timeout.', flush=True)
        warned = False
        while child.poll() is None:
            status = read_json(ROOT / 'status.json', {})
            if not warned and (status.get('phase') != 'active' or time.time() - status.get('updated', 0) > 15):
                print('caffeine: Steam timer control lost or changed manually; command continues, keep-awake is not guaranteed.', file=sys.stderr, flush=True)
                warned = True
            time.sleep(.3)
        return child.returncode if child.returncode >= 0 else 128 - child.returncode
    finally:
        if child and child.poll() is None:
            os.killpg(child.pid, signal.SIGTERM)
        with locked(ROOT):
            path.unlink(missing_ok=True)
        deadline = time.monotonic() + 15
        while time.monotonic() < deadline:
            status = read_json(ROOT / 'status.json', {})
            if token not in status.get('leases', []) and status.get('phase') in ('idle', 'active', 'overridden'):
                print('caffeine: lease released; ' + ('AC timer restored or manual choice preserved.' if status['phase'] == 'idle' else 'other runs still own their leases.'), flush=True)
                break
            time.sleep(.2)
        else:
            print('caffeine: restoration pending; user service will retry when Steam is available. Check caffeine --status.', file=sys.stderr)


def main():
    if sys.argv[1:] == ['--guard']:
        guard()
    elif sys.argv[1:] == ['--status']:
        print(json.dumps({'guard': read_json(ROOT / 'status.json', {}), 'pending_restore': read_json(ROOT / 'restore.json'), 'live': Steam().read()}, indent=2))
    elif sys.argv[1:] in (['--help'], ['-h']):
        print('Usage: caffeine [COMMAND [ARG...]] | --status\nTemporarily set Steam AC idle sleep to Never and hold idle:sleep.\nDefault command: sleep infinity. Ctrl-C releases; overlapping runs share ownership.\nBattery and power buttons unchanged. Steam localhost diagnostic endpoint must already be available.\nThe user service recovers killed clients and retries pending restoration; manual nonzero changes win.\nAn indistinguishable manual change from Never to Never cannot be detected.')
    else:
        return client(sys.argv[1:] or ['/usr/bin/sleep', 'infinity'])
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except Exception as exc:
        print('caffeine:', str(exc), file=sys.stderr)
        sys.exit(1)
