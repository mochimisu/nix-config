"""Pointer selection regression coverage: rotated/scaled/negative-origin outputs."""
import unittest
from context import pointer_output


class PointerOutputTest(unittest.TestCase):
    def setUp(self):
        self.monitors = [
            dict(name="DP-3", x=0, y=0, width=3440, height=1440, scale=1, transform=0),
            dict(name="DP-1", x=3440, y=-560, width=2560, height=1440, scale=1, transform=1),
        ]

    def test_rotated_output_and_repeated_fresh_selection(self):
        for x, y, expected in [(100, 100, "DP-3"), (4000, -300, "DP-1"),
                               (4000, 1800, "DP-1"), (3439, 100, "DP-3"),
                               (3440, 100, "DP-1"), (100, 100, "DP-3")]:
            self.assertEqual(pointer_output(self.monitors, dict(x=x, y=y)), expected)

    def test_scale_and_flipped_rotation(self):
        self.monitors[1].update(scale=2, transform=5)
        self.assertEqual(pointer_output(self.monitors, dict(x=4159, y=719)), "DP-1")
        with self.assertRaises(RuntimeError):
            pointer_output(self.monitors, dict(x=4160, y=720))

    def test_disconnected_output_has_no_stale_fallback(self):
        self.monitors[1]["disabled"] = True
        with self.assertRaises(RuntimeError):
            pointer_output(self.monitors, dict(x=4000, y=100))


if __name__ == "__main__":
    unittest.main()
