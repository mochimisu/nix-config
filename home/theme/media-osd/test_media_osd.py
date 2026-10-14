"""Exercise real OSD shell logic with private, deterministic device/notification fakes."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).with_name("media-osd.sh")

class MediaOsdTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.state = self.root / "state.json"
        self.state.write_text(json.dumps({"volume": .42, "muted": False, "brightness": 50, "backlight": True}))
        fake = '''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
p=Path(os.environ["TEST_STATE"]); s=json.loads(p.read_text()); args=sys.argv[1:]
name=Path(sys.argv[0]).name
with open(os.environ["TEST_LOG"],"a") as f: f.write(json.dumps([name]+args)+"\\n")
if name=="wpctl":
 if args[0]=="get-volume": print("Volume:",s["volume"],"[MUTED]" if s["muted"] else "")
 elif args[0]=="set-mute": s["muted"]=not s["muted"]
 elif args[0]=="set-volume": s["volume"]=min(1.5,max(0,s["volume"]+(.05 if args[-1]=="5%+" else -.05)))
elif name=="brightnessctl":
 assert args[0]=="--class=backlight"
 if not s["backlight"]: sys.exit(1)
 if args[1]=="max": print(100)
 elif args[1]=="get": print(s["brightness"])
 elif args[1]=="set": s["brightness"]+=5 if args[2]=="+5%" else -5
p.write_text(json.dumps(s))
'''
        for name in ["wpctl", "brightnessctl", "notify-send"]:
            file = self.root / name
            file.write_text(fake)
            file.chmod(0o755)
        self.env = dict(os.environ, PATH=str(self.root) + ":" + os.environ["PATH"],
                        XDG_RUNTIME_DIR=str(self.root), TEST_STATE=str(self.state), TEST_LOG=str(self.root / "calls"))

    def tearDown(self):
        self.temp.cleanup()

    def run_osd(self, kind, action):
        return subprocess.run(["bash", "-euo", "pipefail", str(SCRIPT), kind, action], env=self.env, capture_output=True)

    def calls(self):
        return [json.loads(line) for line in (self.root / "calls").read_text().splitlines()]

    def test_volume_and_muting(self):
        self.assertEqual(self.run_osd("volume", "up").returncode, 0)
        notification = self.calls()[-1]
        self.assertIn("Volume · 47%", notification)
        self.assertIn("--hint=int:value:47", notification)
        self.assertIn("--hint=boolean:transient:true", notification)
        self.assertIn("--hint=string:x-canonical-private-synchronous:sekai-volume", notification)
        self.assertEqual(self.run_osd("volume", "mute").returncode, 0)
        self.assertIn("Volume · muted", self.calls()[-1])
        self.assertIn("--hint=int:value:0", self.calls()[-1])

    def test_brightness_failure_does_not_write_device(self):
        state = json.loads(self.state.read_text()); state["backlight"] = False; self.state.write_text(json.dumps(state))
        self.assertEqual(self.run_osd("brightness", "up").returncode, 1)
        self.assertIn("Brightness unavailable", self.calls()[-1])
        self.assertFalse(any("set" in call for call in self.calls()))
        self.assertFalse(any(arg.startswith("--hint=int:value") for arg in self.calls()[-1]))

    def test_brightness_progress(self):
        self.assertEqual(self.run_osd("brightness", "down").returncode, 0)
        self.assertIn("Brightness · 45%", self.calls()[-1])
        self.assertIn("--hint=int:value:45", self.calls()[-1])

    def test_amplified_volume_caps_only_progress(self):
        state = json.loads(self.state.read_text()); state["volume"] = 1.5; self.state.write_text(json.dumps(state))
        self.assertEqual(self.run_osd("volume", "show").returncode, 0)
        self.assertIn("Volume · 150%", self.calls()[-1])
        self.assertIn("--hint=int:value:100", self.calls()[-1])

    def test_bad_action_has_no_effect(self):
        self.assertEqual(self.run_osd("brightness", "delete").returncode, 2)
        self.assertFalse((self.root / "calls").exists())

    def test_key_repeat_is_serialized(self):
        procs = [subprocess.Popen(["bash", "-euo", "pipefail", str(SCRIPT), "volume", "up"], env=self.env) for _ in range(6)]
        self.assertEqual([p.wait() for p in procs], [0] * 6)
        self.assertAlmostEqual(json.loads(self.state.read_text())["volume"], .72)

if __name__ == "__main__": unittest.main()
