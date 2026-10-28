import os,subprocess,time,tempfile,json,argparse,sys,shutil
from pathlib import Path
parser=argparse.ArgumentParser(description="Mako rendering regression on private headless Wayland and D-Bus")
parser.add_argument('--mako',required=True,type=Path)
parser.add_argument('--sway',required=True,type=Path)
parser.add_argument('--output',required=True,type=Path)
parser.add_argument('--scale',type=int,default=1,choices=[1,2])
options=parser.parse_args()
if not os.environ.get('KIRAKIRA_PRIVATE_BUS'):
    raise SystemExit(subprocess.call(['dbus-run-session','--',sys.executable,__file__,*sys.argv[1:]],env=dict(os.environ,KIRAKIRA_PRIVATE_BUS='1')))
scale=options.scale;out=options.output.resolve();out.mkdir(parents=True,exist_ok=True)
notify=shutil.which('notify-send');assert notify, 'notify-send must be on PATH'
with tempfile.TemporaryDirectory(prefix='kirakira-notification-test-') as tmp:
 t=Path(tmp);runtime=t/'runtime';runtime.mkdir(mode=0o700)
 env=dict(os.environ,XDG_RUNTIME_DIR=str(runtime),WLR_BACKENDS='headless',WLR_HEADLESS_OUTPUTS='1',WLR_RENDERER='pixman',WLR_LIBINPUT_NO_DEVICES='1',DBUS_SYSTEM_BUS_ADDRESS='unix:path=/nonexistent/test-bus',XDG_CONFIG_HOME=str(t/'config'))
 for key in ['WAYLAND_DISPLAY','DISPLAY','HYPRLAND_INSTANCE_SIGNATURE','SWAYSOCK']:env.pop(key,None)
 cfg=t/'sway.conf';cfg.write_text('xwayland disable\noutput HEADLESS-1 mode '+str(800*scale)+'x'+str(600*scale)+'\noutput HEADLESS-1 scale '+str(scale)+'\noutput * bg #202c32 solid_color\nseat seat0 fallback true\n')
 log=open(out/'sway.log','w');sway=subprocess.Popen([str(options.sway),'-c',str(cfg)],env=env,stdout=log,stderr=log)
 mako=None
 try:
  for _ in range(50):
   sockets=[p for p in runtime.glob('wayland-*') if not p.name.endswith('.lock')]
   if sockets:break
   if sway.poll() is not None:raise RuntimeError((out/'sway.log').read_text())
   time.sleep(.1)
  assert sockets
  env['WAYLAND_DISPLAY']=sockets[0].name
  config=t/'mako.conf';config.write_text('font=Montserrat 12\nanchor=top-right\nwidth=340\nheight=140\nmargin=12,24\npadding=12,14\nbackground-color=#181d2199\ntext-color=#ffffff\nborder-color=#63c6c0\nborder-size=2\nborder-radius=16\nmax-visible=5\n[mode=do-not-disturb]\ninvisible=true\n[urgency=critical]\nborder-color=#f08090\n')
  ml=open(out/'mako.log','w');mako=subprocess.Popen([str(options.mako),'-c',str(config)],env=env,stdout=ml,stderr=ml)
  def ctl(*args):return subprocess.check_output([str(options.mako.with_name('makoctl')),*args],env=env,text=True)
  def send(title,timeout=0,replace=None,extra=[]):
   args=[notify,'-p','-t',str(timeout),*extra]
   if replace:args+=['-r',str(replace)]
   return int(subprocess.check_output(args+[title,'Safe isolated rendering fixture'],env=env,text=True).strip())
  def capture(name):subprocess.run(['grim','-o','HEADLESS-1',str(out/(name+'.png'))],env=env,check=True,capture_output=True)
  time.sleep(.3)
  first=send('Kirakira · hello');time.sleep(.04);capture('entrance-early');time.sleep(.10);capture('entrance-middle');time.sleep(.45);capture('settled')
  assert send('Replacement · same identity',replace=first)==first
  second=send('Critical · stays visible',extra=['-u','critical']);time.sleep(.5);capture('stack-critical')
  ctl('dismiss','-n',str(first));time.sleep(.04);capture('exit-middle');time.sleep(.25)
  assert 'Critical' in ctl('list') and 'Replacement' not in ctl('list')
  ctl('mode','-a','do-not-disturb');time.sleep(.08);capture('dnd-hidden')
  assert 'Critical' in ctl('list')
  ctl('mode','-r','do-not-disturb');time.sleep(.5);capture('dnd-restored')
  ctl('dismiss','-a');time.sleep(.65);capture('empty')
  action=subprocess.Popen([notify,'-p','-t','0','-A','default=Mock action','Action fixture','Private bus only'],env=env,text=True,stdout=subprocess.PIPE)
  aid=int(action.stdout.readline().strip());time.sleep(.1);ctl('invoke','-n',str(aid),'default')
  remaining=action.communicate(timeout=3)[0];assert 'default' in remaining,remaining

  bottom=send('Stable lower card');top=send('Departing upper card');time.sleep(.9)
  ctl('dismiss','-n',str(top));time.sleep(.06);capture('stack-collapse-early');time.sleep(.65);capture('stack-collapse-settled')
  ctl('dismiss','-a');time.sleep(.65)
  send('Expires normally',timeout=180);time.sleep(.9);assert 'Expires normally' not in ctl('list');capture('timeout-empty')
  for i in range(16):send('Rapid fixture '+str(i),timeout=200)
  time.sleep(1.1);assert 'Rapid fixture' not in ctl('list');capture('burst-empty')
  def ticks():
   stat=Path('/proc')/str(mako.pid)/'stat';values=stat.read_text().split();return int(values[13])+int(values[14])
  before=ticks();time.sleep(1);delta=ticks()-before;assert delta<=2,delta
  assert mako.poll() is None
  (out/'results.json').write_text(json.dumps({'action_invocation':True,'replacement_identity':True,'critical_preserved':True,'dnd_preserved':True,'timeout_preserved':True,'burst_16':True,'idle_cpu_ticks_1s':delta},indent=2))
  print((out/'results.json').read_text())
 finally:
  if mako: mako.terminate();mako.wait(timeout=5);ml.close()
  sway.terminate();sway.wait(timeout=5);log.close()
