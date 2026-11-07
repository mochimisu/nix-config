"""Exact, reviewed main-module patches for optional Linux window controls."""


def patch(text):
    changes = [
        # Reviewed 26.1103.32239: two background creation sites, two explicit
        # initial reveals, and three primary/progress-window visibility predicates.
        ('background:Z.isBackgroundLaunch}',
         'background:Z.isBackgroundLaunch||codexNixStartHidden}', 2),
        ('||Z.isBackgroundLaunch||',
         '||Z.isBackgroundLaunch||codexNixStartHidden||', 2),
        ('!Z.isBackgroundLaunch',
         '!Z.isBackgroundLaunch&&!codexNixStartHidden', 3),
    ]
    if 'codexNixStartHidden' in text or 'codexNixDisableMini' in text:
        raise ValueError('Window controls already patched')
    for old, new, count in changes:
        if text.count(old) != count:
            raise ValueError(f'Upstream window lifecycle changed; review patch: {old}')
        text = text.replace(old, new)
    return 'const codexNixStartHidden=process.env.CHATGPT_START_MINIMIZED===`1`;\n' + text
