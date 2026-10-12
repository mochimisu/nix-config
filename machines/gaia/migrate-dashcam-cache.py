#!/usr/bin/env python3
"""Gaia-only, root-run cache migration. No original recordings are removed.
Run in a persistent terminal: sudo python3 migrate-dashcam-cache.py
A failure retains the old cache; inspect the printed phase before retrying.
"""
import fcntl, json, os, pathlib, shutil, stat, subprocess, sys, time, urllib.request
os.environ['PATH'] = '/run/current-system/sw/bin:/run/wrappers/bin:/usr/bin:/bin'
S = pathlib.Path('/var/cache/dashcam-viewer')
D = pathlib.Path('/earth/dashcam-viewer-cache')
STATE = pathlib.Path('/var/lib/dashcam-cache-migration')
UNITS = ['dashcam-viewer.service', 'dashcam-viewer-preprocess.service']
TIMER = 'dashcam-viewer-preprocess.timer'
DROP = '90-earth-cache.conf'

def run(*args, capture=False, check=True):
    return subprocess.run(args, text=True, stdout=subprocess.PIPE if capture else None,
                          check=check)
def say(s): print(time.strftime('%Y-%m-%d %H:%M:%S'), s, flush=True)
def mounted():
    run('mountpoint', '-q', '/earth')
    assert run('findmnt', '-n', '-o', 'FSTYPE', '-T', '/earth', capture=True).stdout.strip() == 'btrfs'
    assert os.stat(S).st_dev != os.stat('/earth').st_dev

def inventory(root):
    rows = {}
    device = root.stat().st_dev
    for parent, dirs, files in os.walk(root, followlinks=False):
        for name in dirs + files:
            p = pathlib.Path(parent)/name
            st = p.lstat()
            assert st.st_dev == device and not stat.S_ISLNK(st.st_mode), f'Unexpected mount/link: {p}'
            assert stat.S_ISDIR(st.st_mode) or stat.S_ISREG(st.st_mode), f'Unexpected file type: {p}'
            rows[str(p.relative_to(root))] = [st.st_mode, st.st_size, st.st_mtime_ns, st.st_ino]
    return rows

def playback():
    base='http://127.0.0.1:3000'
    deadline=time.monotonic()+300
    while time.monotonic()<deadline:
        try:
            with urllib.request.urlopen(base+'/api/index?car=blackvue-taycan', timeout=20) as r:
                d=json.load(r)
            clips=d.get('clips', [])
            if clips: break
        except Exception: pass
        time.sleep(3)
    else: raise RuntimeError('Viewer index did not become ready')
    # Select recent front footage. Proxy creation, if necessary, only writes generated cache.
    clip=next(c for c in reversed(clips) if c.get('hasFront'))
    url=base+clip['cameraUrls']['front'].replace('/api/video/', '/api/compatible-video/', 1)
    while time.monotonic()<deadline:
        req=urllib.request.Request(url, headers={'Range':'bytes=0-4095'})
        with urllib.request.urlopen(req, timeout=30) as r:
            body=r.read(4096)
            if r.status==206 and body and r.headers.get('Content-Type','').startswith('video/'):
                say('Playback range smoke test passed (HTTP 206, video bytes).')
                return
            assert r.status==202, f'Unexpected playback status {r.status}'
        time.sleep(3)
    raise RuntimeError('Compatible playback did not become ready')

assert os.geteuid()==0, 'Run with sudo on Gaia; never send a password to the agent.'
assert os.uname().nodename=='gaia', 'Wrong host'
STATE.mkdir(mode=0o700, exist_ok=True)
lock=open(STATE/'lock','w'); fcntl.flock(lock, fcntl.LOCK_EX|fcntl.LOCK_NB)
assert not (STATE/'complete.json').exists(), 'Migration already completed'
assert S.is_dir() and not S.is_symlink()
mounted()
assert run('systemctl','is-active',UNITS[0],check=False,capture=True).returncode==0
assert run('systemctl','is-active',TIMER,check=False,capture=True).returncode==0
for u in UNITS:
    assert not (pathlib.Path('/etc/systemd/system.control')/(u+'.d')/DROP).exists(), 'Drop-in already exists; inspect previous attempt'
    env=run('systemctl','show',u,'-p','Environment','--value',capture=True).stdout
    assert 'DASHCAM_PROXY_CACHE_ROOT='+str(S)+'/compatible-video' in env, 'Service cache configuration changed; review first'
resume = sys.argv[1:] == ['--resume-verified']
assert not sys.argv[1:] or resume, 'Unknown arguments'
if resume:
    assert D.is_dir() and not D.is_symlink()
    assert (STATE/'verified-source.json').is_file(), 'No prior checksum certificate'
else:
    assert not D.exists(), 'Destination exists; inspect previous attempt instead of overwriting'
needed=sum(v[1] for v in inventory(S).values() if stat.S_ISREG(v[0]))
assert shutil.disk_usage('/earth').free > needed + 10*1024**3, 'Insufficient destination headroom'
if not resume:
    D.mkdir(mode=0o750)
    run('chown','--reference='+str(S),str(D))
paused=False
activated=False
try:
    if not resume:
        say('Phase 1: initial copy while viewer remains online; this may take many minutes.')
        result=run('rsync','-aHAX','--numeric-ids','--exclude=*.tmp.*','--info=progress2',str(S)+'/',str(D)+'/',check=False)
        assert result.returncode in (0,24), f'Initial rsync failed: {result.returncode}'
    say('Phase 2: pause viewer and preprocessing, then finish and checksum-verify copy.')
    run('systemctl','stop',TIMER)
    # Let an archive-mutating preprocessing pass finish rather than interrupting it.
    paused=True
    deadline=time.monotonic()+50*60
    while run('systemctl','show',UNITS[1],'-p','ActiveState','--value',capture=True).stdout.strip() in ('active','activating','deactivating'):
        assert time.monotonic()<deadline, 'Preprocessing did not finish; no migration activation'
        say('Waiting for existing preprocessing pass to finish safely.')
        time.sleep(30)
    run('systemctl','stop',*UNITS)
    for u in UNITS:
        assert run('systemctl','show',u,'-p','MainPID','--value',capture=True).stdout.strip()=='0'
    mounted()
    before=inventory(S)
    # Resume is only for a reviewed post-verification activation failure where
    # the destination has never been activated or modified. Reuse the successful
    # full checksum pass only if the source inventory and destination metadata
    # still match its certificate exactly. Otherwise perform full verification again.
    reuse = resume and before == json.loads((STATE/'verified-source.json').read_text())
    if reuse:
        diff=run('rsync','-aHAXn','--numeric-ids','--delete','--itemize-changes',str(S)+'/',str(D)+'/',capture=True).stdout
        reuse = not diff.strip()
    if reuse:
        say('Prior full checksum certificate retained: source inventory and destination metadata unchanged.')
    else:
        run('rsync','-aHAX','--numeric-ids','--info=progress2',str(S)+'/',str(D)+'/')
        # Read-only checksum comparison also flags extra destination files.
        diff=run('rsync','-aHAXnc','--numeric-ids','--delete','--itemize-changes',str(S)+'/',str(D)+'/',capture=True).stdout
        assert not diff.strip(), 'Checksum/metadata comparison failed; both caches retained: '+diff[:2000]
    assert inventory(S)==before, 'Source changed while stopped'
    (STATE/'verified-source.json').write_text(json.dumps(before))
    say('Full rsync checksum and metadata verification passed.')
    common='''[Unit]\nRequiresMountsFor=/earth/dashcam-viewer-cache\nRequires=earth.mount\nAfter=earth.mount\nBindsTo=earth.mount\nAssertPathIsMountPoint=/earth\n[Service]\nCacheDirectory=\nReadWritePaths=/earth/dashcam-viewer-cache\nEnvironment=DASHCAM_PROXY_CACHE_ROOT=/earth/dashcam-viewer-cache/compatible-video\nEnvironment=DASHCAM_BLACK_VIDEO_CACHE_ROOT=/earth/dashcam-viewer-cache/black-video-analysis\n'''
    for u in UNITS:
        path=pathlib.Path('/etc/systemd/system.control')/(u+'.d')
        path.mkdir(exist_ok=True)
        leaf='DASHCAM_THUMBNAIL_CACHE_ROOT=thumbnails' if u==UNITS[0] else 'DASHCAM_PREPROCESS_PROBE_CACHE_ROOT=video-probes'
        key,value=leaf.split('=')
        (path/DROP).write_text(common+f'Environment={key}={D}/{value}\n')
    run('systemctl','daemon-reload')
    for u in UNITS:
        env=run('systemctl','show',u,'-p','Environment','--value',capture=True).stdout
        assert 'DASHCAM_PROXY_CACHE_ROOT='+str(D)+'/compatible-video' in env
        assert str(S) not in env, f'Old cache reference remains: {u}'
    run('systemctl','start',UNITS[0]); activated=True
    deadline=time.monotonic()+30
    while time.monotonic()<deadline:
        pid=run('systemctl','show',UNITS[0],'-p','MainPID','--value',capture=True).stdout.strip()
        try:
            env=(pathlib.Path('/proc')/pid/'environ').read_bytes().split(b'\0')
            if ('DASHCAM_PROXY_CACHE_ROOT='+str(D)+'/compatible-video').encode() in env:
                break
        except (FileNotFoundError, ProcessLookupError):
            pass
        time.sleep(0.2)
    else:
        raise RuntimeError('Live cache environment did not become ready')
    # Validate writes inside the same strict filesystem sandbox used by preprocessing.
    # This creates and immediately removes only its own empty probe file.
    probe='set -eu; f=$(/run/current-system/sw/bin/mktemp /earth/dashcam-viewer-cache/.migration-write.XXXXXX); /run/current-system/sw/bin/rm -- "$f"'
    run('systemd-run','--quiet','--wait','--collect','--unit=dashcam-cache-write-check',
        '-p','User=brandon','-p','Group=users','-p','ProtectSystem=strict',
        '-p','ProtectHome=true','-p','ReadWritePaths='+str(D),
        '-p','RequiresMountsFor='+str(D),'/run/current-system/sw/bin/bash','-c',probe)
    playback()
    mounted()
    assert inventory(S)==before, 'Old source unexpectedly changed; no removal'
    say('Phase 3: remove only verified old cache files; originals are outside this tree.')
    # Per-entry unlink, not recursive force removal: unexpected additions remain intact.
    for rel, old in before.items():
        if stat.S_ISREG(old[0]):
            p=S/rel; st=p.lstat()
            assert [st.st_mode,st.st_size,st.st_mtime_ns,st.st_ino]==old, f'Changed source: {p}'
            p.unlink()
    for rel, old in sorted(before.items(),key=lambda kv:len(pathlib.Path(kv[0]).parts),reverse=True):
        if stat.S_ISDIR(old[0]): (S/rel).rmdir()
    S.rmdir()
    run('systemctl','start',TIMER)
    paused=False
    (STATE/'complete.json').write_text(json.dumps({'completed':time.time(),'destination':str(D),'verified_file_bytes':needed}))
    say('Migration completed. Existing preprocessing policy resumed.')
    run('df','-h','/','/earth')
    run('du','-sh',str(D))
except BaseException:
    say('STOPPED: inspect error; unremoved old cache files are preserved. No originals were targeted.')
    if paused and not activated:
        # If no overrides were installed, restore service availability on the original cache.
        if not any((pathlib.Path('/etc/systemd/system.control')/(u+'.d')/DROP).exists() for u in UNITS):
            run('systemctl','start',UNITS[0],check=False)
            run('systemctl','start',TIMER,check=False)
    raise
