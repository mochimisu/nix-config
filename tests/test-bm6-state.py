"""Exercise real decoded BM6 status bytes against the existing upstream mapping."""
import ast
from dataclasses import dataclass
from enum import Enum
from pathlib import Path
import sys
import unittest

root = Path(sys.argv.pop(1))
connect = ast.parse((root / 'bm6_connect.py').read_text())
battery = ast.parse((root / 'battery.py').read_text())
classes = [n for n in connect.body if isinstance(n, ast.ClassDef) and n.name in ('BM6RealTimeState', 'BM6RealTimeData')]
classes += [n for n in battery.body if isinstance(n, ast.ClassDef) and n.name == 'BatteryState']
battery_cls = next(n for n in battery.body if isinstance(n, ast.ClassDef) and n.name == 'Battery')
mapping = next(n for n in battery_cls.body if isinstance(n, ast.FunctionDef) and n.name == '_bm6_status_to_battery_state')
module = ast.Module(body=classes + [mapping], type_ignores=[])
ns = dict(Enum=Enum, dataclass=dataclass)
exec(compile(ast.fix_missing_locations(module), '<BM6 decoded-state mapping>', 'exec'), ns)

class StateTests(unittest.TestCase):
    def test_existing_upstream_states_from_actual_frame_layout(self):
        for byte, name in ((0, 'Ok'), (1, 'LowVoltage'), (2, 'Charging')):
            with self.subTest(state=byte):
                frame = bytearray.fromhex('d1550700190064050000000000000000')
                frame[5] = byte
                decoded = ns['BM6RealTimeData'](frame.hex())
                self.assertEqual(decoded.Voltage,12.8)
                self.assertEqual(decoded.Temperature,25)
                self.assertEqual(ns['_bm6_status_to_battery_state'](None, decoded.State), getattr(ns['BatteryState'],name))

    def test_unrecognized_state_remains_unknown(self):
        for value in (3,255,None):
            with self.subTest(state=value):
                self.assertEqual(ns['_bm6_status_to_battery_state'](None,value),ns['BatteryState'].Unknown)

unittest.main()
