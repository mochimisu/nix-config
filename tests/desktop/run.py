"""Exercise real QML/Eww widgets on private displays, never the user's desktop."""
import argparse
from PIL import Image
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import time


def block_end(text, start):
    pos = text.index('{', start) + 1
    depth = 1
    while depth:
        depth += (text[pos] == '{') - (text[pos] == '}')
        pos += 1
    return pos


def sidebar(source, repo, fixtures, height, themed, output):
    s = source.read_text()
    app = json.loads((repo/'home/theme/app-palette.json').read_text())
    palette = json.loads((repo/'home/theme/sekai-palette.json').read_text())
    palette.update(railForeground=app['text'], railMuted=app['muted'])
    values = dict(sessionControlsEnabled='true', sidebarScreensJson='["0"]',
                  hostName='blackmoon' if themed else 'oasis', mediaFeedbackEnabled=str(themed).lower(),
                  blockedAudioDescriptionsJson='[]', pttStateFile='', iconSize='16', fontSize='13px',
                  workspaceHeight='18', workspaceSpacing='2', themePaletteJson=json.dumps(palette if themed else {}))
    for key in re.findall(r'@(\w+)@', s):
        s = s.replace('@'+key+'@', values.get(key, '/nonexistent/test-helper-disabled'))
    # No real action or script producer may run in a fixture.
    for name, param, record in [('dispatchWorkspace','workspace','"workspace:" + workspace.id'),
            ('setDefaultSink','node','"sink:" + node.id'), ('toggleMute','','"mute"'),
            ('adjustVolume','delta','"volume:" + delta'), ('adjustBrightness','delta','"brightness:" + delta'),
            ('cyclePowerProfile','','"profile"'), ('toggleWifi','','"wifi"'),
            ('lockSession','','"lock"'), ('suspendSession','','"suspend"'), ('shutdownSession','','"shutdown"')]:
        start = s.index('    function '+name+'(')
        s = s[:start] + f'    function {name}({param}) {{ root.calls.push({record}); }}' + s[block_end(s,start):]
    s = s.replace('Networking.wifiEnabled', 'true')  # Explicit fixture state, no live system bus.
    start = s.index('                // New notification toast')
    end = block_end(s, s.index('PanelWindow {',start))
    s = s[:start]+s[end:]
    s = s.replace('import QtQuick\n','import QtQuick\nimport QtTest\n',1)
    s = s.replace('    id: root', '''    id: root
    property var calls: []
    property var fixtureSinks: [{id:1,description:"Desk speakers",isSink:true,isStream:false,audio:{volume:.42,muted:false}}, {id:2,description:"Headphones",isSink:true,isStream:false,audio:{volume:.5,muted:false}}]''',1)
    s = s.replace('model: Pipewire.nodes','model: root.fixtureSinks')
    s = s.replace('readonly property var defaultSink: Pipewire.defaultAudioSink','readonly property var defaultSink: fixtureSinks[0]')
    s = s.replace('PanelWindow {','FloatingWindow {',1)
    for line in ['            screen: modelData\n','            exclusiveZone: root.sidebarWidth\n','            focusable: false\n']:
        s = s.replace(line,'')
    s = s.replace('''            anchors {
                top: true
                bottom: true
                right: true
            }
''','')
    s = s.replace('            implicitWidth: root.sidebarWidth',f'            implicitHeight: {height}\n            implicitWidth: root.sidebarWidth',1)
    s = re.sub(r'^            WlrLayershell\..*\n','',s,flags=re.M)
    s = s.replace('running: true\n        command:', 'running: false\n        command:')
    checks = (fixtures/'sidebar-checks.qml.inc').read_text()
    fixture = '''
            Timer {
                interval: 300; running: true
                onTriggered: {
                    const name=panel.modelData.name;
                    root.workspacesState = {[name]: {workspaces: [{id:1,name:"1",active:true},{id:2,name:"2",active:false},{id:3,name:"3",active:false,urgent:true}]}};
                    root.windowState = {[name]: {title:"Desktop regression fixture"}};
                    root.clockState = {hour:"03",minute:"45",ampm:"pm",date:"10/14"};
                    root.networkState = {eth:"fixture"}; root.cavaBars="▂▄▆▃▅";
                    controlCenterPopup.visible=true; audioPopup.visible=true;
                    checkTimer.start();
                }
            }
            Timer {
                id: checkTimer; interval: 200
                onTriggered: {
                    controlCard.grabToImage(r => {
                        if (!r.saveToFile("@output@")) { console.error("Capture failed"); Qt.exit(1); return; }
                        try { tests.runChecks(); console.log("TESTS PASSED"); Qt.quit(); }
                        catch (e) { console.error(e); Qt.exit(1); }
                    });
                }
            }
'''.replace('@output@', str(output))
    return s.replace('            id: panel','            id: panel\n'+checks+fixture,1)


def run_qml(path, env, output):
    (output/(path.stem+".qml")).write_text(path.read_text())
    result = subprocess.run(['dbus-run-session','--','qs','-n','-p',str(path)], env=env,
                            text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=35)
    (output/(path.stem+'.log')).write_text(result.stdout)
    if result.returncode or 'TESTS PASSED' not in result.stdout or 'ASSERT' in result.stdout:
        raise RuntimeError(f'{path.name} failed: {result.stdout[-5000:]}')
    print('PASS',path.stem,flush=True)


def test_eww(repo, generation, env, output, temp):
    config = temp/'sway.conf'
    config.write_text('output HEADLESS-1 mode 1440x112\nseat seat0 hide_cursor 100\n')
    e = dict(env, WLR_BACKENDS='headless', WLR_RENDERER='pixman', WLR_LIBINPUT_NO_DEVICES='1',
             WLR_HEADLESS_OUTPUTS='1', GDK_BACKEND='wayland')
    e.pop('DISPLAY',None)
    log = open(output/'sway.log','w')
    proc = subprocess.Popen(['sway','--unsupported-gpu','-c',str(config)],env=e,stdout=log,stderr=log)
    try:
        for _ in range(100):
            sockets = [p for p in Path(e['XDG_RUNTIME_DIR']).glob('wayland-*') if not p.name.endswith('.lock')]
            if sockets: break
            if proc.poll() is not None: raise RuntimeError('Headless Sway failed; see sway.log')
            time.sleep(.1)
        else: raise RuntimeError('No private Wayland socket')
        e['WAYLAND_DISPLAY'] = sockets[0].name
        cfg=temp/'eww';cfg.mkdir()
        y=(generation/'home-files/.config/eww/sysmon/eww.yuck').read_text()
        y=re.sub(r'\(defpoll uptime.*?(?=\(defwidget history-graph)', '(defvar uptime "365d 23h 59m")\n',y,flags=re.S)
        values={'procs':{'total':12345,'running':128,'capacity':3200,**{f'top{i}':{'name':'synthetic-long-process-name-for-layout-'+str(i),'cpu':v} for i,v in enumerate(['0','100','800','1600','3200','0','0'],1)}},
                'sensors':{'gpu_temp':119,'flow_rate':999.9,'fan_speed':4999,'pump_speed':4999},'net':{'down':'999.9M','up':'999.9M'}}
        for key,value in values.items():y=re.sub(r'\(deflisten '+key+r' [^\n]+', '(defvar '+key+" '"+json.dumps(value)+"')",y)
        # Built-in values become deterministic fixture values, not measurements.
        y=y.replace('EWW_TEMPS.CORETEMP_PACKAGE_ID_0','119.25').replace('EWW_TEMPS.HIGHFLOWNEXT_COOLANT_TEMP','59.75')
        y=y.replace(':monitor "DP-1"',':monitor "HEADLESS-1"')
        (cfg/'eww.yuck').write_text(y)
        (cfg/'eww.scss').write_text((generation/'home-files/.config/eww/sysmon/eww.scss').read_text())
        command=['eww','--config',str(cfg)]
        with open(output/'eww.log','w') as ewlog:
            subprocess.run(command+['daemon'],env=dict(e,WAYLAND_DEBUG='client'),stdout=ewlog,stderr=ewlog,check=True)
            try:
                subprocess.run(command+['open','sysmon'],env=e,check=True,capture_output=True)
                time.sleep(1)
                subprocess.run(['grim','-o','HEADLESS-1',str(output/'process-overflow.png')],env=e,check=True)
            finally:subprocess.run(command+['kill'],env=e,capture_output=True)
        trace=(output/'eww.log').read_text()
        sizes=re.findall(r'zwlr_layer_surface_v1[^\n]*\.configure\(\d+, (\d+), (\d+)\)',trace)
        if not sizes or sizes[-1]!=('1440','112'):raise RuntimeError(f'Unexpected Eww surface size: {sizes}')
        print('PASS process-overflow 1440x112; tracks at 0, 100, 800, 1600, 3200%',flush=True)
    finally:
        proc.terminate();proc.wait(timeout=10);log.close()


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--repo',type=Path,default=Path.cwd());ap.add_argument('--fixtures',type=Path,required=True)
    ap.add_argument('--generation',type=Path,required=True,help='Built Blackmoon Home Manager generation')
    ap.add_argument('--output',type=Path,required=True);ap.add_argument('--baseline-sidebar',type=Path)
    args=ap.parse_args();repo=args.repo.resolve();out=args.output.resolve();out.mkdir(parents=True,exist_ok=True)
    for script in ['home/apps/quickshell/phone-launcher/test_context.py','machines/blackmoon/sddm/test_rotate_displays.py','home/theme/media-osd/test_media_osd.py']:
        subprocess.run(['python3',str(repo/script)],env=dict(os.environ,PYTHONDONTWRITEBYTECODE='1'),check=True)
    subprocess.run(['node',str(repo/'home/apps/quickshell/phone-launcher/test-search.cjs')],check=True)
    with tempfile.TemporaryDirectory(prefix='desktop-style-') as directory:
        temp=Path(directory);runtime=temp/'runtime';runtime.mkdir(mode=0o700)
        env=dict(os.environ)
        for name in ['WAYLAND_DISPLAY','HYPRLAND_INSTANCE_SIGNATURE','DBUS_SESSION_BUS_ADDRESS','SWAYSOCK','QT_STYLE_OVERRIDE','QT_PLUGIN_PATH','QML_IMPORT_PATH','QML2_IMPORT_PATH']:
            env.pop(name,None)
        env.update(XDG_RUNTIME_DIR=str(runtime),XDG_CONFIG_HOME=str(temp/'config'),XDG_CACHE_HOME=str(temp/'cache'),
                   XDG_DATA_HOME=str(temp/'data'),DBUS_SYSTEM_BUS_ADDRESS='unix:path=/nonexistent/test-bus',
                   QT_QPA_PLATFORM='xcb',QT_QUICK_BACKEND='rhi',QSG_RHI_BACKEND='opengl',
                   QML_IMPORT_PATH=os.environ['DESKTOP_QML_IMPORTS'],QT_PLUGIN_PATH=os.environ['DESKTOP_QT_PLUGINS'])
        read,write=os.pipe()
        xvfb=subprocess.Popen(['Xvfb','-displayfd',str(write),'-screen','0','1600x1000x24','-nolisten','tcp'],pass_fds=[write],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        os.close(write);env['DISPLAY']=':'+os.read(read,32).decode().strip();os.close(read)
        try:
            for themed,height in [(True,850),(True,420),(True,220),(False,850)]:
                name=f'sidebar-{themed}-{height}';path=temp/(name+'.qml')
                path.write_text(sidebar(repo/'home/apps/quickshell/sidebar/shell.qml',repo,args.fixtures,height,themed,out/(name+'.png')))
                run_qml(path,env,out)
                if args.baseline_sidebar:
                    path=temp/(name+'-before.qml');path.write_text(sidebar(args.baseline_sidebar,repo,args.fixtures,height,themed,out/(name+'-before.png')))
                    run_qml(path,env,out)
                    a=Image.open(out/(name+'.png')).convert('RGBA');b=Image.open(out/(name+'-before.png')).convert('RGBA')
                    assert a.size == b.size, name
                    differences=[abs(x-y) for x,y in zip(a.tobytes(),b.tobytes()) if x!=y]
                    # GPU edge rounding can differ by one 8-bit level between runs.
                    if differences and (max(differences)>1 or len(differences)>len(a.tobytes())*.001):
                        raise RuntimeError(f'{name}: {len(differences)} image channels differ; maximum {max(differences)}')
                    print(f'PASS {name} visual equivalence: {len(differences)} channels differ, max {max(differences, default=0)}/255',flush=True)
            for width,height in [(560,900),(390,580)]:
                q=(args.fixtures/'launcher.qml.in').read_text().replace('@launcher@',(repo/'home/apps/quickshell/phone-launcher').as_uri()).replace('@width@',str(width)).replace('@height@',str(height))
                path=temp/f'launcher-{width}-{height}.qml';path.write_text(q);run_qml(path,env,out)
            test_eww(repo,args.generation.resolve(),env,out,temp)
        finally:xvfb.terminate();xvfb.wait(timeout=10)
    print('All desktop style checks passed. No live session was changed.')


if __name__=='__main__':main()
