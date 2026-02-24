#!/usr/bin/env python3
import argparse
import asyncio
import base64
import json
import math
import os
import re
import shutil
import subprocess
import sys
import unicodedata
import urllib.error
import urllib.request
from datetime import datetime

import websockets

WS_URL_DEFAULT = "ws://127.0.0.1:5580/ws"

GREEN = "\033[32m"
YELLOW = "\033[33m"
ORANGE = "\033[38;5;208m"
RED = "\033[31m"
RESET = "\033[0m"
ANSI_RE = re.compile(r"\x1b\[[0-9;]*m")


def _b64_to_bytes(value: str) -> bytes | None:
    try:
        return base64.b64decode(value + "===")
    except Exception:
        return None


def _mac_from_attrs(attrs: dict) -> str | None:
    for entry in (attrs.get("0/51/0") or []):
        hw = entry.get("4")
        if isinstance(hw, str) and hw:
            decoded = _b64_to_bytes(hw)
            if decoded and len(decoded) >= 6:
                return ":".join(f"{byte:02x}" for byte in decoded[:6])
    return None


def _parse_attr_path(path: str) -> tuple[int, int, int] | None:
    parts = path.split("/")
    if len(parts) != 3:
        return None
    try:
        return int(parts[0]), int(parts[1]), int(parts[2])
    except Exception:
        return None


def _cluster_attr_value(attrs: dict, cluster: int, attr: int):
    candidates: list[tuple[int, object]] = []
    for key, value in attrs.items():
        if not isinstance(key, str):
            continue
        parsed = _parse_attr_path(key)
        if not parsed:
            continue
        endpoint, got_cluster, got_attr = parsed
        if got_cluster == cluster and got_attr == attr:
            candidates.append((endpoint, value))

    if not candidates:
        return None

    # Prefer non-root endpoints.
    candidates.sort(key=lambda item: (item[0] == 0, item[0]))
    return candidates[0][1]


def _walk_values(value, path: str = ""):
    if isinstance(value, dict):
        for key, inner in value.items():
            key_s = str(key).lower()
            next_path = f"{path}/{key_s}" if path else key_s
            yield next_path, inner
            yield from _walk_values(inner, next_path)
    elif isinstance(value, (list, tuple)):
        for idx, inner in enumerate(value):
            next_path = f"{path}/{idx}" if path else str(idx)
            yield next_path, inner
            yield from _walk_values(inner, next_path)


def _thread_link_metrics(attrs: dict) -> tuple[str, str]:
    def parse_rssi(value: int) -> int | None:
        # Some devices report RSSI as unsigned int8; convert to signed dBm.
        # RSSI in dBm should be <= 0 in normal reporting.
        if -127 <= value <= 0:
            return value
        if 128 <= value <= 255:
            signed = value - 256
            if -127 <= signed <= 0:
                return signed
        return None

    lqi_values: list[int] = []
    rssi_values: list[int] = []

    # Prefer Thread neighbor table entries (0/53/7), where field "6" is RSSI.
    neighbor_table = attrs.get("0/53/7")
    if isinstance(neighbor_table, list):
        for entry in neighbor_table:
            if not isinstance(entry, dict):
                continue
            raw_rssi = entry.get("6")
            if isinstance(raw_rssi, (int, float)):
                parsed = parse_rssi(int(raw_rssi))
                if parsed is not None:
                    rssi_values.append(parsed)

    # Keep generic parsing for vendor-specific keys that explicitly contain
    # "lqi"/"rssi" in their names.
    for key, value in attrs.items():
        if not isinstance(key, str):
            continue
        # Thread Network Diagnostics cluster (53) and nearby diagnostics data.
        if not (key.startswith("0/53/") or key.startswith("0/54/")):
            continue

        key_l = key.lower()
        if isinstance(value, (int, float)):
            iv = int(value)
            if "lqi" in key_l and 0 <= iv <= 255:
                lqi_values.append(iv)
            if "rssi" in key_l:
                parsed = parse_rssi(iv)
                if parsed is not None:
                    rssi_values.append(parsed)

        for path, inner in _walk_values(value, key_l):
            if not isinstance(inner, (int, float)):
                continue
            iv = int(inner)
            if "lqi" in path and 0 <= iv <= 255:
                lqi_values.append(iv)
            if "rssi" in path:
                parsed = parse_rssi(iv)
                if parsed is not None:
                    rssi_values.append(parsed)

    lqi = str(max(lqi_values)) if lqi_values else ""
    rssi = str(max(rssi_values)) if rssi_values else ""
    return lqi, rssi


def _fetch_solar(api_url: str, timeout_sec: float = 0.7) -> dict | None:
    try:
        with urllib.request.urlopen(api_url, timeout=timeout_sec) as resp:
            if resp.status != 200:
                return None
            raw = resp.read()
    except (urllib.error.URLError, TimeoutError, ValueError):
        return None
    except Exception:
        return None
    try:
        data = json.loads(raw.decode("utf-8"))
    except Exception:
        return None
    return data if isinstance(data, dict) else None


def _device_status(vendor: str, product: str, label: str, attrs: dict, color: bool) -> str:
    vendor_l = (vendor or "").lower()
    product_l = (product or "").lower()
    label_l = (label or "").lower()

    if "inovelli" in vendor_l or "vtm31" in product_l:
        onoff = _cluster_attr_value(attrs, 6, 0)
        on_symbol = f"{GREEN}●{RESET}" if color else "●"
        off_symbol = "◯"
        if isinstance(onoff, bool):
            return on_symbol if onoff else off_symbol
        if isinstance(onoff, (int, float)):
            return on_symbol if int(onoff) != 0 else off_symbol

    if ("meross" in vendor_l) and ("presence sensor" in product_l or "presence" in label_l):
        occ = _cluster_attr_value(attrs, 1030, 0)
        if occ is None:
            occ = _cluster_attr_value(attrs, 1066, 0)
        present = None
        if isinstance(occ, bool):
            present = occ
        if isinstance(occ, (int, float)):
            present = (int(occ) & 0x1) != 0

        icon = "◯"
        if present is True:
            icon = "👤"

        lux_text = ""
        illum = _cluster_attr_value(attrs, 1024, 0)
        if isinstance(illum, (int, float)):
            raw = float(illum)
            lux = 0.0 if raw <= 0 else math.pow(10.0, (raw - 1.0) / 10000.0)
            lux_text = f"/{int(round(lux))}lx"

        return f"{icon}{lux_text}"

    return ""


async def _call(ws, message_id: str, command: str, args: dict | None = None) -> dict:
    payload = {"message_id": message_id, "command": command, "args": args or {}}
    await ws.send(json.dumps(payload))
    while True:
        message = json.loads(await ws.recv())
        if message.get("event"):
            continue
        if message.get("message_id") == message_id:
            return message


def _render(text: str, first: bool) -> None:
    if first:
        # First paint clears any existing scrollback noise.
        print("\033[2J\033[H", end="")
    else:
        # Subsequent paints update in place to avoid flash.
        print("\033[H", end="")
    print(text, end="")
    print("\033[J", end="")
    sys.stdout.flush()


def _fmt_state(available: bool, color: bool) -> str:
    symbol = "✓" if available else "✗"
    if not color:
        return symbol
    return f"{GREEN}{symbol}{RESET}" if available else f"{RED}{symbol}{RESET}"


def _strip_ansi(text: str) -> str:
    return ANSI_RE.sub("", text)


def _display_width(text: str) -> int:
    width = 0
    for ch in _strip_ansi(text):
        # Zero-width/control characters do not consume terminal columns.
        if ch in ("\u200d", "\ufe0f"):
            continue
        if unicodedata.combining(ch):
            continue
        cat = unicodedata.category(ch)
        if cat.startswith("C") and ch not in ("\t",):
            continue
        width += 2 if unicodedata.east_asian_width(ch) in ("W", "F") else 1
    return width


def _pad(text: str, width: int) -> str:
    visible = _display_width(text)
    if visible >= width:
        return text
    return text + (" " * (width - visible))


def _service_last_started(service: str) -> str:
    try:
        result = subprocess.run(
            [
                "systemctl",
                "show",
                service,
                "--property=ActiveEnterTimestamp",
                "--value",
            ],
            check=False,
            capture_output=True,
            text=True,
        )
    except Exception:
        return "unknown"

    if result.returncode != 0:
        return "unknown"

    value = result.stdout.strip()
    return value or "unknown"


def _color_lqi(value_text: str, color: bool) -> str:
    if not color or not value_text:
        return value_text
    try:
        value = int(value_text)
    except Exception:
        return value_text
    if value >= 180:
        return f"{GREEN}{value_text}{RESET}"
    if value >= 120:
        return f"{YELLOW}{value_text}{RESET}"
    if value >= 80:
        return f"{ORANGE}{value_text}{RESET}"
    return f"{RED}{value_text}{RESET}"


def _color_rssi(value_text: str, color: bool) -> str:
    if not color or not value_text:
        return value_text
    try:
        value = int(value_text)
    except Exception:
        return value_text
    if value >= -65:
        return f"{GREEN}{value_text}{RESET}"
    if value >= -75:
        return f"{YELLOW}{value_text}{RESET}"
    if value >= -85:
        return f"{ORANGE}{value_text}{RESET}"
    return f"{RED}{value_text}{RESET}"


async def _poll(ws_url: str) -> list[dict]:
    async with websockets.connect(ws_url) as ws:
        await ws.recv()  # server_info
        start = await _call(ws, "start", "start_listening")
        if "error_code" in start:
            details = start.get("details") or "unknown error"
            raise RuntimeError(f"start_listening failed: {details}")
        return start.get("result") or []


def _table_text(
    nodes: list[dict],
    color: bool,
    ws_url: str,
    interval: float,
    solar_data: dict | None,
) -> str:
    width = shutil.get_terminal_size((120, 40)).columns
    now = datetime.now().isoformat(timespec="seconds")

    solar_line = "Solar: unknown (matter-solar-api unavailable)"
    facade_line = "Sun@Facade: unknown"
    if solar_data and isinstance(solar_data.get("solar"), dict):
        solar = solar_data["solar"]
        day_night = solar.get("day_night") or "unknown"
        sunrise = (solar.get("sunrise_local") or "unknown")
        sunset = (solar.get("sunset_local") or "unknown")
        sunrise_t = sunrise[11:16] if isinstance(sunrise, str) and len(sunrise) >= 16 else sunrise
        sunset_t = sunset[11:16] if isinstance(sunset, str) and len(sunset) >= 16 else sunset
        solar_line = f"Solar: {day_night}  Sunrise: {sunrise_t}  Sunset: {sunset_t}"

        sun = solar.get("sun") or {}
        facade = solar.get("facade") or {}
        az = sun.get("azimuth_deg")
        el = sun.get("elevation_deg")
        h = facade.get("horizontal_offset_deg")
        v = facade.get("vertical_deg")
        front = facade.get("in_front_of_facade")
        if all(isinstance(x, (int, float)) for x in [az, el, h, v]):
            front_text = "front" if front else "back"
            facade_line = (
                f"Sun@Facade: az={az:.1f}° el={el:.1f}°  horiz={h:.1f}° vert={v:.1f}° ({front_text})"
            )

    lines = [
        f"Matter device connectivity  ({now})",
        f"WS: {ws_url}",
        solar_line,
        facade_line,
        f"Matter last started: {_service_last_started('podman-matter-server.service')}",
        f"OTBR last started:   {_service_last_started('podman-otbr.service')}",
        f"Polling every {interval:.1f}s. Press Ctrl+C to stop.",
        "-" * min(width, 160),
        f"{'Node':<6}  {'State':<5}  {'Status':<10}  {'LQI':<4}  {'RSSI':<5}  {'Label':<24}  {'MAC':<17}  Device",
        f"{'----':<6}  {'-----':<5}  {'------':<10}  {'---':<4}  {'----':<5}  {'-----':<24}  {'---':<17}  ------",
    ]

    for node in sorted(nodes, key=lambda n: n.get("node_id", 0)):
        node_id = node.get("node_id")
        available = bool(node.get("available"))
        attrs = node.get("attributes") or {}
        label = attrs.get("0/40/5") or "(no label)"
        vendor = attrs.get("0/40/1") or ""
        product = attrs.get("0/40/3") or ""
        mac = _mac_from_attrs(attrs) or ""
        lqi, rssi = _thread_link_metrics(attrs)
        lqi_text = _color_lqi(lqi, color)
        rssi_text = _color_rssi(rssi, color)
        state = _fmt_state(available, color)
        status = _device_status(vendor, product, label, attrs, color)
        label_text = label[:24]
        if color:
            label_colored = f"{GREEN}{label_text}{RESET}" if available else f"{RED}{label_text}{RESET}"
        else:
            label_colored = label_text
        device = f"{vendor} {product}".strip()
        lines.append(
            f"{_pad(str(node_id), 6)}  "
            f"{_pad(state, 5)}  "
            f"{_pad(status, 10)}  "
            f"{_pad(lqi_text, 4)}  "
            f"{_pad(rssi_text, 5)}  "
            f"{_pad(label_colored, 24)}  "
            f"{_pad(mac, 17)}  "
            f"{device}"
        )

    return "\n".join(lines) + "\n"


async def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--ws-url", default=os.getenv("MATTER_WS_URL", WS_URL_DEFAULT))
    parser.add_argument("--solar-api-url", default=os.getenv("MATTER_SOLAR_API_URL", "http://127.0.0.1:8056/solar"))
    parser.add_argument("--interval", type=float, default=2.0)
    parser.add_argument("--no-color", action="store_true")
    args = parser.parse_args()

    use_color = (not args.no_color) and sys.stdout.isatty()
    first = True

    while True:
        try:
            nodes = await _poll(args.ws_url)
            solar_data = _fetch_solar(args.solar_api_url)
            _render(
                _table_text(nodes, use_color, args.ws_url, args.interval, solar_data),
                first,
            )
            first = False
        except Exception as err:
            _render(f"Matter watch error: {err}\n", first)
            first = False

        await asyncio.sleep(args.interval)


if __name__ == "__main__":
    try:
        raise SystemExit(asyncio.run(main()))
    except KeyboardInterrupt:
        print("\nstopped")
        raise SystemExit(0)
