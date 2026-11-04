import ast,asyncio,io,json,re,subprocess,tempfile,time,unittest,sys
from pathlib import Path
REPO = Path(__file__).resolve().parents[1]
COORDINATOR = Path(sys.argv.pop(1))
from types import SimpleNamespace as NS
from unittest.mock import patch

class LastSeenTests(unittest.TestCase):
 def setUp(self):
  self.temp=tempfile.TemporaryDirectory(); self.root=Path(self.temp.name)
  token=self.root/'ha.env';token.write_text('MATTER_HA_TOKEN=not-a-real-token')
  source=(REPO/'machines/gaia/homepage/stats.py.in').read_text().replace('@haEnvFile@',str(token));source=re.sub(r'@[A-Za-z]+@','[]',source)
  self.ns={'__name__':'test'};exec(compile(source,'collector','exec'),self.ns)
  self.ns['boxster_cache_file']=self.root/'state'/'sample.json'
  self.now=time.time();self.stamp=self.now-5
 def tearDown(self):self.temp.cleanup()
 def query(self, stamp=None, state='12.8', fail=False):
  values=[{'entity_id':'sensor.bm6_test_tension','state':state,'attributes':{'last_successful_read':self.stamp if stamp is None else stamp,'voltage_device':12.8,'temperature_device':24,'device_percentage':100}}]
  with patch('urllib.request.urlopen',side_effect=OSError() if fail else None,return_value=io.StringIO(json.dumps(values))):return self.ns['read_boxster']()
 def test_equal_success_advances_and_disconnect_retains(self):
  a=self.query();b=self.query(self.stamp+1);self.assertGreater(b['lastSeen'],a['lastSeen']);self.assertEqual(a['metrics'],b['metrics'])
  offline=self.query(self.stamp+1,state='unavailable');self.assertEqual(offline['status'],'disconnected');self.assertEqual(offline['lastSeen'],b['lastSeen']);self.assertEqual(offline['metrics']['charge'],100)
 def test_restart_backend_unreachable_and_reconnect(self):
  first=self.query();cache=json.loads(self.ns['boxster_cache_file'].read_text());self.assertEqual(cache['lastSeen'],first['lastSeen'])
  # Every query reloads the disk cache, matching a new collector process.
  failed=self.query(fail=True);self.assertEqual(failed['status'],'backend_unavailable');self.assertEqual(failed['lastSeen'],first['lastSeen'])
  self.assertTrue(self.query(self.stamp+2)['ok'])
 def test_no_prior(self):
  r=self.query(fail=True);self.assertIsNone(r['lastSeen']);self.assertEqual(r['metrics'],{})
 def test_bad_future_and_regression_do_not_replace(self):
  first=self.query()
  for stamp in ['bad',float('nan'),True,self.now+3600,0]:
   r=self.query(stamp);self.assertFalse(r['ok']);self.assertEqual(r['lastSeen'],first['lastSeen'])
  self.assertEqual(self.query(self.stamp-2)['lastSeen'],first['lastSeen'])
 def test_stale_success_is_not_connected(self):
  self.assertEqual(self.query(self.now-400)['status'],'stale')
 def test_invalid_persistent_cache(self):
  p=self.ns['boxster_cache_file'];p.parent.mkdir();p.write_text('{broken');self.assertIsNone(self.query(fail=True)['lastSeen'])
  p.write_text(json.dumps({'lastSeen':self.now+100,'metrics':{'charge':100,'voltage':12.8,'temperature':24}}));self.assertIsNone(self.query(fail=True)['lastSeen'])
 def test_coordinator_records_each_success_only(self):
  tree=ast.parse(COORDINATOR.read_text());method=next(n for n in ast.walk(tree) if isinstance(n,ast.AsyncFunctionDef) and n.name=='_async_update_data')
  ns={name:name for name in set(re.findall(r'\b(?:KEY|CONF)_[A-Z_]+\b',ast.unparse(method)))}
  real=NS(Voltage=12.8,Temperature=24,Percent=100,State=0,RapidAcceleration=0,RapidDeceleration=0)
  class Connector:
   def __init__(self,**kw):pass
   async def get_data(self):return NS(RealTime=real,Advertisement=NS(RSSI=-70,Scanner='proxy'))
  ns.update(BM6Connector=Connector,convert_temperature=lambda v,u:v,time=time,BM6DeviceError=ValueError,UpdateFailed=RuntimeError,_LOGGER=NS(error=lambda *a:None))
  exec(compile(ast.Module(body=[method],type_ignores=[]),'coordinator','exec'),ns)
  bounds=NS(min=0,max=100);battery=NS(update=lambda *a:None,percent=100,state=NS(value='ok'),range=NS(dvr=bounds,cvr=bounds,sod=bounds,soc=bounds),info=NS(state_algorithm=NS(value='by_device')))
  obj=NS(hass=None,device_address='test',config_entry=NS(data={'CONF_VOLTAGE_OFFSET':0,'CONF_TEMPERATURE_OFFSET':0,'CONF_TEMPERATURE_UNIT':'C'}),_battery=battery)
  with patch('time.time',side_effect=[1000,1001]):
   a=asyncio.run(ns['_async_update_data'](obj));b=asyncio.run(ns['_async_update_data'](obj))
  self.assertEqual(a['last_successful_read'],1000);self.assertEqual(b['last_successful_read'],1001)
  with patch.object(Connector,'get_data',side_effect=ValueError('offline')),patch('time.time') as clock:
   with self.assertRaises(RuntimeError):asyncio.run(ns['_async_update_data'](obj))
   clock.assert_not_called()

unittest.main()
