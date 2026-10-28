"""Exact, reviewed main-module patches for optional Linux window controls."""


def patch(text):
    changes = [
        # Reuse the existing background creation path: no fallback reveal timer.
        ('background:e.isBackgroundLaunch}',
         'background:e.isBackgroundLaunch||codexNixStartHidden}', 2),
        ('!e.isBackgroundLaunch',
         '!e.isBackgroundLaunch&&!codexNixStartHidden', 5),
        # Stop explicit opening before it mutates the saved pet-open preference.
        ('async open(e,{forcePetView:t=!1,focusQuickChat:n=!1,persistPetIntent:r=!0}={}){',
         'async open(e,{forcePetView:t=!1,focusQuickChat:n=!1,persistPetIntent:r=!0}={}){if(codexNixDisableMini)return;', 1),
        # Also prevent prewarming and other callers from allocating the overlay.
        ('async ensureWindow(e){if(this.isAppQuitting)return null;',
         'async ensureWindow(e){if(codexNixDisableMini||this.isAppQuitting)return null;', 1),
        ('shouldPresentWindow(){return this.isNotchManager?',
         'shouldPresentWindow(){if(codexNixDisableMini)return false;return this.isNotchManager?', 1),
    ]
    if 'codexNixStartHidden' in text or 'codexNixDisableMini' in text:
        raise ValueError('Window controls already patched')
    for old, new, count in changes:
        if text.count(old) != count:
            raise ValueError(f'Upstream window lifecycle changed; review patch: {old}')
        text = text.replace(old, new)
    return ('const codexNixStartHidden=process.env.CHATGPT_START_MINIMIZED===`1`,'
            'codexNixDisableMini=process.env.CHATGPT_DISABLE_MINI===`1`;\n' + text)
