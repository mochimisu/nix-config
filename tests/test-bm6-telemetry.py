"""Offline regression checks for the pinned BM6 connector; no Bluetooth access."""
import ast
import asyncio
import logging
from pathlib import Path
from types import SimpleNamespace
import sys
import unittest

source = Path(sys.argv.pop(1)).read_text()
tree = ast.parse(source)
node = next(n for n in tree.body if isinstance(n, ast.ClassDef) and n.name == 'BM6Connector')
module = ast.Module(body=[ast.ImportFrom(module='__future__', names=[ast.alias(name='annotations')], level=0), node], type_ignores=[])
namespace = dict(asyncio=asyncio, _LOGGER=logging.getLogger('test'), BM6DeviceError=RuntimeError,
    BM6Data=lambda *args: SimpleNamespace(RealTime=None), BLEAK_CLIENT_TIMEOUT=0.02,
    CHARACTERISTIC_UUID_WRITE='FFF3', CHARACTERISTIC_UUID_NOTIFY='FFF4',
    GATT_DATA_REALTIME='d1550700000000000000000000000000')
exec(compile(ast.fix_missing_locations(module), '<pinned BM6Connector>', 'exec'), namespace)
Connector = namespace['BM6Connector']

class PollingTests(unittest.IsolatedAsyncioTestCase):
    async def run_poll(self, outcomes):
        connector = Connector.__new__(Connector)
        connector._address = 'test-device'
        connector._data = None
        connector._encrypt = lambda value: value
        connector._scanners = [SimpleNamespace(ble_device=i, advertisement=None, scanner=SimpleNamespace(name=f'scanner{i}')) for i in range(len(outcomes))]
        events=[]
        class Client:
            def __init__(self, index, **kwargs): self.index=index
            async def __aenter__(self):
                events.append(('connect',self.index)); return self
            async def __aexit__(self,*args): events.append(('disconnect',self.index))
            async def start_notify(self, uuid, callback): events.append(('subscribe',uuid))
            async def stop_notify(self, uuid): events.append(('unsubscribe',uuid))
            async def write_gatt_char(self,uuid,data,response):
                events.append(('write',uuid,bytes(data),response))
                if outcomes[self.index]=='error': raise OSError('unreachable')
                if outcomes[self.index]=='success': connector._data.RealTime=SimpleNamespace(Voltage=12.6)
        namespace['BleakClient']=Client
        try: result=await asyncio.wait_for(connector.get_data(),1)
        except RuntimeError: result=None
        return result,events

    async def test_acknowledgement_is_not_a_measurement(self):
        connector = Connector.__new__(Connector)
        connector._address = 'test-device'
        connector._data = SimpleNamespace(RealTime=None)
        connector._decrypt = lambda value: value
        namespace['GATT_NOTIFY_REALTIME_PREFIX'] = 'd15507'
        namespace['BM6RealTimeData'] = lambda value: value
        await connector._notify_callback(None, bytes.fromhex('d15507ff000000000000000000000000'))
        self.assertIsNone(connector._data.RealTime)
        frame = 'd155070019006404ec00000000000000'
        await connector._notify_callback(None, bytes.fromhex(frame))
        self.assertEqual(connector._data.RealTime, frame)

    async def test_immediate_reply_and_single_telemetry_request(self):
        result,events=await self.run_poll(['success','success'])
        self.assertEqual(result.RealTime.Voltage,12.6)
        self.assertEqual([e for e in events if e[0]=='connect'],[('connect',0)])
        self.assertLess(next(i for i,e in enumerate(events) if e[0]=='subscribe'),next(i for i,e in enumerate(events) if e[0]=='write'))
        self.assertEqual([e for e in events if e[0]=='write'],[('write','FFF3',bytes.fromhex(namespace['GATT_DATA_REALTIME']),True)])
        self.assertEqual(events[-1],('disconnect',0))

    async def test_silent_device_times_out_and_disconnects(self):
        result,events=await self.run_poll(['silent'])
        self.assertIsNone(result)
        self.assertEqual(events[-1],('disconnect',0))

    async def test_failed_scanner_falls_back(self):
        result,events=await self.run_poll(['error','success'])
        self.assertEqual(result.RealTime.Voltage,12.6)
        self.assertEqual([e for e in events if e[0]=='connect'],[('connect',0),('connect',1)])

unittest.main()
