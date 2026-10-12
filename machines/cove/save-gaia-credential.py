#!/usr/bin/env python3
"""Run interactively as deck on Cove; never print or transmit the entered value."""
import getpass
import os
from pathlib import Path
import sys

if os.getuid() != 1000 or Path('/proc/sys/kernel/hostname').read_text().strip() != 'cove':
    sys.exit('Run this as deck on Cove.')
if not sys.stdin.isatty() or not sys.stdout.isatty():
    sys.exit('An interactive terminal is required.')
folder = Path.home() / '.config/cove'
folder.mkdir(mode=0o700, parents=True, exist_ok=True)
os.chmod(folder, 0o700)
target = folder / 'gaia.smb'
if target.exists():
    sys.exit('Credential file already exists; it was not replaced.')
password = getpass.getpass('New cove-media password (same as Gaia): ')
confirmation = getpass.getpass('Confirm password: ')
if not password or password != confirmation or '\n' in password or '\r' in password:
    sys.exit('Passwords must match, be nonempty, and contain no newlines.')
fd = os.open(target, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
with os.fdopen(fd, 'w') as stream:
    stream.write('username=cove-media\npassword=' + password + '\n')
    stream.flush()
    os.fsync(stream.fileno())
password = confirmation = None
print('Credential saved privately on Cove. The automount can now be enabled.')
