import copy
import importlib.util
from pathlib import Path
import unittest

path = Path(__file__).resolve().parents[1] / "machines/blackmoon/home/steam-capture-output.py"
spec = importlib.util.spec_from_file_location("capture", path)
capture = importlib.util.module_from_spec(spec)
spec.loader.exec_module(capture)


def record(output="DP-1"):
    return {"type": "a{sas}v", "data": [
        {"": ["yes"]}, {"type": "(suv)", "data": ["hyprland", 3, {
            "type": "a{sv}", "data": {
                "withCursor": {"type": "u", "data": 1},
                "timeIssued": {"type": "t", "data": 1793511378},
                "token": {"type": "s", "data": "todo"},
                "output": {"type": "s", "data": output}}}]}]}


class CaptureTest(unittest.TestCase):
    def test_hardware_identity_survives_connector_change(self):
        monitors = [{"name": "DP-1", "make": "Acer Technologies", "model": "XB271HU"},
                    {"name": "DP-7", "make": "Dell Inc.", "model": "Dell AW3423DW"}]
        self.assertEqual(capture.target_output(monitors), "DP-7")

    def test_missing_disabled_or_ambiguous_dell_fails(self):
        dell = {"name": "DP-3", "make": "Dell Inc.", "model": "Dell AW3423DW"}
        for monitors in ([], [dict(dell, disabled=True)], [dell, dell]):
            with self.assertRaises(ValueError):
                capture.target_output(monitors)

    def test_changes_output_only_without_mutating_original(self):
        before = record()
        saved = copy.deepcopy(before)
        args = capture.replacement(before, "DP-3")
        self.assertEqual(args, ["(suv)", "hyprland", "3", "a{sv}", "4",
                               "withCursor", "u", "1", "timeIssued", "t", "1793511378",
                               "token", "s", "todo", "output", "s", "DP-3"])
        self.assertEqual(before, saved)

    def test_idempotent(self):
        self.assertIsNone(capture.replacement(record("DP-3"), "DP-3"))

    def test_unapproved_or_unknown_schema_fails(self):
        denied = record()
        denied["data"][0] = {"": ["no"]}
        unknown = record()
        unknown["data"][1]["data"][1] = 4
        new_field = record()
        new_field["data"][1]["data"][2]["data"]["future"] = {"type": "s", "data": "preserve"}
        for value in (denied, unknown, new_field):
            with self.assertRaises(ValueError):
                capture.replacement(value, "DP-3")


if __name__ == "__main__":
    unittest.main()
