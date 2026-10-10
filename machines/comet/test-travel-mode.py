import importlib.util,unittest,time,threading
from pathlib import Path
spec=importlib.util.spec_from_file_location('travel',Path(__file__).with_name('travel-mode.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
class Fixture:
 def __init__(self):self.value=False;self.writes=[];self.fail=False;self.gate=None
 def read(self):
  if self.gate:self.gate.wait(2)
  if self.fail:raise RuntimeError('Fixture unavailable')
  return self.value
 def set(self,v):
  if self.fail:raise RuntimeError('Fixture write failed')
  self.writes.append(v);self.value=v;return self.read()
def finish(c):
 for _ in range(100):
  if c.collect():return
  time.sleep(.01)
 raise AssertionError('Worker did not finish')
class Tests(unittest.TestCase):
 def test_open_close_never_writes(self):
  b=Fixture();c=m.Controller(b);self.assertTrue(c.request());finish(c);self.assertFalse(c.value);c.close();self.assertFalse(c.request(True));self.assertEqual(b.writes,[])
 def test_explicit_on_off_and_repeated_current(self):
  b=Fixture();c=m.Controller(b);c.request();finish(c)
  for target in [True,False]:
   self.assertTrue(c.request(target));finish(c);self.assertIs(c.value,target);self.assertFalse(c.request(target))
  self.assertEqual(b.writes,[True,False])
 def test_busy_rejects_clicks(self):
  b=Fixture();b.gate=threading.Event();c=m.Controller(b);c.request();self.assertFalse(c.request(True));self.assertFalse(c.request(False));b.gate.set();finish(c);self.assertEqual(b.writes,[])
 def test_unavailable_disables_writes_and_recovers(self):
  b=Fixture();b.fail=True;c=m.Controller(b);c.request();finish(c);self.assertIsNone(c.value);self.assertFalse(c.request(True));b.fail=False;c.request();finish(c);self.assertFalse(c.value)
 def test_failed_write_does_not_claim_success(self):
  b=Fixture();c=m.Controller(b);c.request();finish(c);b.fail=True;c.request(True);finish(c);self.assertIsNone(c.value);self.assertIn('failed',c.error)
 def test_backend_whitelist_and_noop(self):
  class Client:
   def __init__(self):self.value=False;self.calls=[]
   def evaluate(self,s):
    self.calls.append(s);assert m.PROPERTY in s
    if '.SetBoolPathProperty(' in s:self.value=s.endswith(', true)');return None
    return self.value
  client=Client();b=m.Backend(client);self.assertFalse(b.set(False));self.assertTrue(b.set(True));self.assertEqual(sum('SetBoolPathProperty' in s for s in client.calls),1)
 def test_backend_bad_readback(self):
  class Client:
   def evaluate(self,s):return None if 'SetBool' in s else False
  old=m.time.sleep;m.time.sleep=lambda _:None
  try:
   with self.assertRaisesRegex(RuntimeError,'did not confirm'):m.Backend(Client()).set(True)
  finally:m.time.sleep=old
if __name__=='__main__':unittest.main()
