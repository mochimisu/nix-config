"""Test EDID parsing and safe layout selection without touching an X server."""
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("rotation", Path(__file__).with_name("rotate-displays.py"))
rotation = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rotation)


class DisplayRotationTest(unittest.TestCase):
    def test_arbitrary_xorg_names(self):
        result = rotation.arguments({"DP-6": rotation.ACER, "DP-2": rotation.DELL})
        self.assertEqual(result, ["--output", "DP-6", "--rotate", "left", "--right-of", "DP-2",
                                  "--output", "DP-2", "--rotate", "normal", "--primary"])

    def test_missing_or_ambiguous_identity(self):
        self.assertEqual(rotation.arguments({"DP-1": "different-display"}), [])
        self.assertEqual(rotation.arguments({"DP-1": rotation.ACER, "DP-2": rotation.ACER}), [])
        self.assertEqual(rotation.arguments({"DP-9": rotation.ACER}), ["--output", "DP-9", "--rotate", "left"])

    def test_parser_ignores_disconnected_and_unrelated_properties(self):
        data = bytes(range(128))
        import hashlib
        lines = "\n".join("\t\t" + data[i:i + 16].hex() for i in range(0, 128, 16))
        text = "DP-9 connected primary 2560x1440+0+0\n\tEDID:\n" + lines
        text += "\n\tBorderDimensions: 4\nDP-1 disconnected\n\tEDID:\n" + lines
        self.assertEqual(rotation.connected_edids(text), {"DP-9": hashlib.sha256(data).hexdigest()})


if __name__ == "__main__":
    unittest.main()
