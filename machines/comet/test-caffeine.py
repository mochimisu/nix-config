import importlib.util
import os
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('caffeine', Path(__file__).with_name('caffeine.py'))
c = importlib.util.module_from_spec(spec)
spec.loader.exec_module(c)

class FakeSteam:
    def __init__(self):
        self.ac, self.battery, self.offline, self.fail_set = 3600, 900, False, False
        self.writes = []
    def read(self):
        if self.offline:
            raise ConnectionError('offline')
        return {'ac': self.ac, 'battery': self.battery}
    def set_ac(self, expected, value):
        if self.fail_set:
            raise ConnectionError('setter unavailable')
        if self.ac != expected:
            return False
        self.writes.append((expected, value))
        self.ac = value
        return True

class GuardTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.steam = FakeSteam()
        self.guard = c.Guard(self.root, self.steam)
    def tearDown(self):
        self.tmp.cleanup()
    def lease(self, name='one', pid=None):
        pid = os.getpid() if pid is None else pid
        c.atomic(self.root / f'lease-{name}.json', {'pid': pid, 'identity': c.identity(os.getpid())})
    def release(self, name='one'):
        (self.root / f'lease-{name}.json').unlink()
    def test_overlap_last_exit_restores_original(self):
        self.lease(); self.assertEqual(self.guard.step()[0], 'active')
        self.lease('two'); self.guard.step(); self.release(); self.guard.step()
        self.assertEqual(self.steam.ac, 0)
        self.release('two'); self.assertEqual(self.guard.step()[0], 'idle')
        self.assertEqual(self.steam.writes, [(3600, 0), (0, 3600)])
        self.assertEqual(self.steam.battery, 900)
    def test_manual_choice_wins_even_if_later_set_back_to_zero(self):
        self.lease(); self.guard.step(); self.steam.ac = 1800
        self.assertEqual(self.guard.step()[0], 'overridden')
        self.steam.ac = 0; self.release(); self.guard.step()
        self.assertEqual(self.steam.ac, 0)
        self.assertEqual(len(self.steam.writes), 1)
    def test_initial_steam_unavailable_does_not_create_restore_intent(self):
        self.lease(); self.steam.offline = True
        self.assertEqual(self.guard.step()[0], 'unavailable')
        self.assertFalse((self.root / 'restore.json').exists())
    def test_failed_setter_does_not_claim_active(self):
        self.lease(); self.steam.fail_set = True
        self.assertEqual(self.guard.step()[0], 'unavailable')
        self.release(); self.steam.fail_set = False; self.guard.step()
        self.assertEqual(self.steam.ac, 3600)
    def test_restore_retries_after_steam_returns(self):
        self.lease(); self.guard.step(); self.release(); self.steam.offline = True
        self.assertEqual(self.guard.step()[0], 'unavailable')
        self.assertTrue((self.root / 'restore.json').exists())
        self.steam.offline = False; self.guard.step()
        self.assertEqual(self.steam.ac, 3600)
    def test_guard_restart_recovers_dead_client(self):
        self.lease(); self.guard.step(); self.release(); self.lease(pid=99999999)
        fresh = c.Guard(self.root, self.steam)
        self.assertEqual(fresh.step()[0], 'idle')
        self.assertEqual(self.steam.ac, 3600)
    def test_preexisting_never_is_preserved(self):
        self.steam.ac = 0; self.lease(); self.guard.step(); self.release(); self.guard.step()
        self.assertEqual(self.steam.writes, [])
    def test_crash_after_saved_intent_before_write_preserves_setting(self):
        c.atomic(self.root / 'restore.json', {'previous': 3600, 'overridden': False})
        self.guard.step()
        self.assertEqual(self.steam.writes, [])

if __name__ == '__main__':
    unittest.main()
