import os,sys,subprocess,pathlib,tempfile,re,shutil
import argparse
ap=argparse.ArgumentParser(description='Private launcher early-input regression; no live display or actions.')
ap.add_argument('--repo',type=pathlib.Path,default=pathlib.Path(__file__).resolve().parents[2])
ap.add_argument('--quickshell-wrapper',required=True)
args=ap.parse_args()
repo=args.repo;base=repo/'home/apps/quickshell/phone-launcher'
out=pathlib.Path(__file__).resolve().parent
with tempfile.TemporaryDirectory(prefix='launcher-input-') as d:
 t=pathlib.Path(d)
 for p in base.iterdir():
  if p.suffix in ['.qml','.js']:shutil.copy(p,t/p.name)
 helper=t/'context.py';helper.write_text('import time,json;time.sleep(.5);print(json.dumps({"monitor":"","wallpaper":"","video":False}))')
 s=(t/'shell.qml').read_text().replace('import QtQuick\n','import QtQuick\nimport QtTest\n',1)
 s=s.replace('command: ["@context@"]',f'command: ["{sys.executable}", "{helper}"]')
 s=s.replace('Quickshell.screens.find(s => s.name === context.monitor)','Quickshell.screens[0]')
 s=s.replace('PanelWindow {','FloatingWindow {').replace('        focusable: visible','        implicitWidth: 1200\n        implicitHeight: 900')
 s=s.replace('        anchors { top: true; bottom: true; left: true; right: true }','').replace('        exclusionMode: ExclusionMode.Ignore','')
 s=re.sub(r'^        WlrLayershell.*\n','',s,flags=re.M)
 s=s.replace('Status { id: status; active: window.visible }','Status { id: status; active: false }')
 checks='''
        TestCase {
            id: checks; when: false
            function eq(a,b) { if(a!==b) throw new Error("Expected "+b+", got "+a); }
            function type(text) { for (const c of text) keyClick(c); }
            function run() {
                root.open(); wait(30);
                eq(root.opening,true); eq(window.visible,true); eq(earlyInput.activeFocus,true);
                type("ste"); keyClick(Qt.Key_Backspace); type("eam");
                eq(earlyInput.text,"steam"); wait(600);
                eq(root.opening,false); eq(presentation.phone.query,"steam");
                keyClick(Qt.Key_Escape); eq(presentation.phone.query,"");
                keyClick(Qt.Key_Escape); wait(160); eq(window.visible,false);
                root.open(); wait(30); keyClick(Qt.Key_A,Qt.MetaModifier); keyClick(Qt.Key_Space,Qt.MetaModifier); keyClick(Qt.Key_B,Qt.MetaModifier);
                keyClick(Qt.Key_C,Qt.MetaModifier | Qt.AltModifier);
                eq(earlyInput.text,"abc"); wait(550); eq(presentation.phone.query,"abc");
                root.hide(); root.open(); wait(25); type("discard"); keyClick(Qt.Key_Escape);
                eq(window.visible,false); wait(600); eq(window.visible,false);
                root.open(); wait(20); type("old"); root.hide(); root.open(); wait(20); type("new");
                wait(1150); eq(presentation.phone.query,"new"); eq(window.visible,true);
                root.hide(); root.open(); wait(30); eq(earlyInput.text,"");
                root.hide(); wait(600); eq(window.visible,false);
                // Animation accepts buffered text without clearing it.
                window.visible=true; root.opening=false; presentation.open("fast");
                type("type"); eq(presentation.phone.query,"fasttype");
                wait(350); eq(presentation.phone.query,"fasttype");
                root.hide(); console.log("INPUT TESTS PASSED"); Qt.quit();
            }
        }
        Timer { interval: 50; running: true; onTriggered: { try {checks.run();} catch(e) { console.error(e); Qt.exit(1); } } }
'''
 s=s.replace('        // Local text input',checks+'        // Local text input')
 (t/'shell.qml').write_text(s)
 env=dict(os.environ)
 for k in ['WAYLAND_DISPLAY','DISPLAY','HYPRLAND_INSTANCE_SIGNATURE','DBUS_SESSION_BUS_ADDRESS','SWAYSOCK']:env.pop(k,None)
 runtime=t/'runtime';runtime.mkdir(mode=0o700)
 env.update(XDG_RUNTIME_DIR=str(runtime),XDG_CONFIG_HOME=str(t/'config'),XDG_CACHE_HOME=str(t/'cache'),DBUS_SYSTEM_BUS_ADDRESS='unix:path=/nonexistent',QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software')
 # The same package wrapper supplies QtMultimedia, but no live bus or display.
 wrapper=args.quickshell_wrapper
 r=subprocess.run(['dbus-run-session','--',wrapper,'-n','-p',str(t/'shell.qml')],env=env,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=20)
 print(r.stdout[-6000:]);assert r.returncode==0 and 'INPUT TESTS PASSED' in r.stdout
