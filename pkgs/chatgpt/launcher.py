"""Read opt-in Nix window policy, consume local flags, then exec ChatGPT."""
import json
import os
from pathlib import Path
import sys

OPTIONS = {
    'startMinimized': ('CHATGPT_START_MINIMIZED', '--start-minimized', '--show-window'),
}


def configure(args, env):
    env = dict(env)
    config = Path(env.get('XDG_CONFIG_HOME') or Path.home() / '.config') / 'chatgpt-nix/window-options.json'
    try:
        settings = json.loads(config.read_text())
    except FileNotFoundError:
        settings = {}
    if not isinstance(settings, dict) or settings.keys() - (OPTIONS.keys() | {'disableMini'}):
        raise ValueError(f'{config}: expected an object containing startMinimized')
    for key, value in settings.items():
        if type(value) is not bool:
            raise ValueError(f'{config}: {key} must be a boolean')
    # Accept the retired setting during rolling Home Manager/package upgrades.
    # Mini visibility belongs to the app; never pass the old suppression variable.
    env.pop('CHATGPT_DISABLE_MINI', None)
    for key, (variable, _, _) in OPTIONS.items():
        if variable not in env:
            env[variable] = '1' if settings.get(key, False) else '0'
        elif env[variable] not in ('0', '1'):
            raise ValueError(f'{variable} must be 0 or 1')
    forwarded = []
    flags = {flag: (var, value) for var, yes, no in OPTIONS.values()
             for flag, value in [(yes, '1'), (no, '0')]}
    for index, arg in enumerate(args):
        if arg == '--':
            forwarded.extend(args[index:])
            break
        if arg in ('--disable-mini', '--enable-mini'):
            continue  # Retired wrapper flags, accepted as no-ops for migration.
        if arg in flags:
            variable, value = flags[arg]
            env[variable] = value
        else:
            forwarded.append(arg)
    return forwarded, env


if __name__ == '__main__':
    try:
        args, env = configure(sys.argv[2:], os.environ)
    except (ValueError, OSError) as error:
        sys.exit(f'chatgpt: {error}')
    os.execve(sys.argv[1], [sys.argv[1], *args], env)
