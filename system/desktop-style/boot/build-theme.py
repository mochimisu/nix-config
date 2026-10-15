"""Build small, deterministic RGB PNG assets using only Python's standard library."""
import json
from pathlib import Path
import struct
import sys
import zlib

palette_path, template_path, output_path = map(Path, sys.argv[1:4])
hostname = sys.argv[4]
palette = json.loads(palette_path.read_text())
output_path.mkdir(parents=True, exist_ok=True)


def png(name, color, accent=False):
    rgb = bytes.fromhex(color.removeprefix("#"))
    teal = bytes.fromhex(palette["teal"].removeprefix("#"))
    pixels = b"".join(b"\0" + ((teal * 2 + rgb * 6) if accent else rgb * 8) for _ in range(8))

    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))

    data = b"\x89PNG\r\n\x1a\n"
    data += chunk(b"IHDR", struct.pack(">IIBBBBB", 8, 8, 8, 2, 0, 0, 0))
    data += chunk(b"IDAT", zlib.compress(pixels)) + chunk(b"IEND", b"")
    (output_path / name).write_bytes(data)


png("background.png", palette["background"])
for tile in ("nw", "n", "ne", "w", "c", "e", "sw", "s", "se"):
    png(f"select_{tile}.png", palette["selection"], tile in ("nw", "w", "sw"))

theme = template_path.read_text().replace("@hostname@", " ".join(hostname.upper()))
for name, value in palette.items():
    theme = theme.replace(f"@{name}@", value)
assert "@" not in theme, "Unresolved palette placeholder"
(output_path / "theme.txt").write_text(theme)
