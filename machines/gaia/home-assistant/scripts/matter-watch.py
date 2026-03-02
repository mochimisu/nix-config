#!/usr/bin/env python3
import argparse
import asyncio
import base64
import glob
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
from pathlib import Path

import websockets

WS_URL_DEFAULT = "ws://127.0.0.1:5580/ws"
KEEPALIVE_LATENCY_FILE_DEFAULT = "/run/matter-keepalive-latency.json"
ZBT2_BYID_GLOB_DEFAULT = "/dev/serial/by-id/usb-Nabu_Casa_ZBT-2_*"
ZBT2_ROOM_DEFAULT = "Network Closet"

GREEN = "\033[32m"
YELLOW = "\033[33m"
ORANGE = "\033[38;5;208m"
RED = "\033[31m"
WHITE = "\033[37m"
BLUE = "\033[34m"
RESET = "\033[0m"
ANSI_RE = re.compile(r"\x1b\[[0-9;]*m")
THREAD_VENDOR_KEYWORDS = (
    "inovelli",
    "meross",
    "ikea of sweden",
    "smartwings",
    "aqara",
    "nanoleaf",
)


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


def _room_key_candidates(attrs: dict) -> list[str]:
    out: list[str] = []
    unique_id = attrs.get("0/40/18")
    if isinstance(unique_id, str) and unique_id:
        out.append(f"unique_id:{unique_id}")
    serial = attrs.get("0/40/15")
    if isinstance(serial, str) and serial:
        out.append(f"serial:{serial}")
    mac = _mac_from_attrs(attrs)
    if mac:
        out.append(f"mac:{mac.lower()}")
    return out


def _room_for_attrs(attrs: dict, rooms: dict[str, str], rooms_by_label: dict[str, str]) -> str:
    for key in _room_key_candidates(attrs):
        if key in rooms and isinstance(rooms[key], str) and rooms[key]:
            return rooms[key]

    label = attrs.get("0/40/5")
    if isinstance(label, str) and label and label in rooms_by_label:
        room = rooms_by_label.get(label)
        if isinstance(room, str) and room:
            return room

    return "Ungrouped"


def _expand_env_backed_rooms(raw: dict) -> dict[str, str]:
    out: dict[str, str] = {}
    for key, room in raw.items():
        if not isinstance(key, str) or not isinstance(room, str) or not room:
            continue
        if key.startswith("unique_id_env:"):
            env_name = key.split(":", 1)[1].strip()
            if not env_name:
                continue
            value = (os.getenv(env_name, "") or "").strip()
            if not value:
                continue
            out[f"unique_id:{value}"] = room
            continue
        if key.startswith("serial_env:"):
            env_name = key.split(":", 1)[1].strip()
            if not env_name:
                continue
            value = (os.getenv(env_name, "") or "").strip()
            if not value:
                continue
            out[f"serial:{value}"] = room
            continue
        if key.startswith("mac_env:"):
            env_name = key.split(":", 1)[1].strip()
            if not env_name:
                continue
            value = (os.getenv(env_name, "") or "").strip().lower()
            if not value:
                continue
            out[f"mac:{value}"] = room
            continue
        out[key] = room
    return out


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


def _is_thread_candidate(attrs: dict) -> bool:
    vendor = str(attrs.get("0/40/1") or "").strip().lower()
    product = str(attrs.get("0/40/3") or "").strip().lower()
    if any(keyword in vendor for keyword in THREAD_VENDOR_KEYWORDS):
        return True
    for path in attrs.keys():
        if isinstance(path, str) and (path.startswith("0/53/") or path.startswith("0/54/")):
            return True
    if "button" in product or "remote" in product:
        return True
    return False


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


def _load_keepalive_metrics(path: str) -> dict[str, dict]:
    try:
        raw = Path(path).read_text(encoding="utf-8")
    except Exception:
        return {}
    try:
        data = json.loads(raw)
    except Exception:
        return {}
    if not isinstance(data, dict):
        return {}
    nodes = data.get("nodes")
    return nodes if isinstance(nodes, dict) else {}


def _device_status(vendor: str, product: str, label: str, attrs: dict, color: bool) -> str:
    vendor_l = (vendor or "").lower()
    product_l = (product or "").lower()
    label_l = (label or "").lower()

    is_mbr_bed_light = ("nanoleaf" in vendor_l) and ("mbr bed light" in label_l)

    switch_like = (
        ("inovelli" in vendor_l)
        or ("vtm31" in product_l)
        or ("tapo" in vendor_l and ("smart wi-fi plug" in product_l or "plug" in label_l))
    )
    if switch_like or is_mbr_bed_light:
        onoff = _cluster_attr_value(attrs, 6, 0)
        on_symbol = f"{GREEN}●{RESET}" if color else "●"
        off_symbol = "◯"
        if isinstance(onoff, bool):
            return on_symbol if onoff else off_symbol
        if isinstance(onoff, (int, float)):
            return on_symbol if int(onoff) != 0 else off_symbol

    # Window covering icon state:
    # - fully open: empty box
    # - partially closed: half-filled box
    # - closed: full box
    covering_like = ("window covering" in product_l) or any(
        isinstance(path, str) and "/258/" in path for path in attrs.keys()
    )
    if covering_like:
        position_raw = _cluster_attr_value(attrs, 258, 14)
        if not isinstance(position_raw, (int, float)):
            position_raw = _cluster_attr_value(attrs, 258, 8)
        if isinstance(position_raw, (int, float)):
            pos = float(position_raw)
            # Matter can expose percent in 0..100 or 0..10000.
            closed_pct = (pos / 100.0) if pos > 100.0 else pos
            if closed_pct <= 5.0:
                return "□"
            if closed_pct >= 95.0:
                return "■"
            return "▌"

    def _first_cluster_value(cluster: int, attr_ids: tuple[int, ...]):
        for attr_id in attr_ids:
            value = _cluster_attr_value(attrs, cluster, attr_id)
            if isinstance(value, (int, float)):
                return float(value)
        return None

    def _thermostat_deg_f(raw: float | None) -> str:
        if raw is None:
            return "--"
        # Matter thermostat values are in 0.01C.
        c = raw / 100.0
        f = (c * 9.0 / 5.0) + 32.0
        return str(int(round(f)))

    thermostat_like = ("thermostat" in product_l) or any(
        isinstance(path, str) and "/513/" in path for path in attrs.keys()
    )
    if thermostat_like:
        heat_raw = _first_cluster_value(513, (18, 16))
        temp_raw = _first_cluster_value(513, (0,))
        cool_raw = _first_cluster_value(513, (17, 19))
        heat = _thermostat_deg_f(heat_raw)
        temp = _thermostat_deg_f(temp_raw)
        cool = _thermostat_deg_f(cool_raw)
        if color:
            return f"{RED}{heat}{RESET}/{WHITE}{temp}{RESET}/{BLUE}{cool}{RESET}"
        return f"{heat}/{temp}/{cool}"

    is_presence_sensor = (
        (("meross" in vendor_l) and ("presence sensor" in product_l or "presence" in label_l))
        or (("aqara" in vendor_l) and ("fp300" in product_l or "presence" in label_l))
    )
    if is_presence_sensor:
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

        humidity_text = ""
        humidity = _cluster_attr_value(attrs, 1029, 0)
        if isinstance(humidity, (int, float)):
            raw_h = float(humidity)
            # RelativeHumidityMeasurement.MeasuredValue is typically in 0.01%.
            pct = raw_h / 100.0 if raw_h > 100.0 else raw_h
            humidity_text = f"/{int(round(pct))}%"

        return f"{icon}{lux_text}{humidity_text}"

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


def _service_is_active(service: str) -> bool:
    try:
        result = subprocess.run(
            ["systemctl", "is-active", "--quiet", service],
            check=False,
            capture_output=True,
            text=True,
        )
    except Exception:
        return False
    return result.returncode == 0


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


def _battery_text(attrs: dict) -> str:
    # Power Source cluster (0x002F / 47):
    # - 0x000C (12): BatteryPercentRemaining (typically 0.5% units)
    # - 0x000B (11): BatteryVoltage (100 mV units)
    # - 0x000A (10): BatteryChargeLevel enum
    percent_remaining = _cluster_attr_value(attrs, 47, 12)
    if isinstance(percent_remaining, (int, float)):
        raw = float(percent_remaining)
        if raw >= 0:
            pct = raw / 2.0 if raw > 100.0 else raw
            if 0.0 <= pct <= 100.0:
                return f"{int(round(pct))}%"

    battery_voltage = _cluster_attr_value(attrs, 47, 11)
    if isinstance(battery_voltage, (int, float)):
        raw_v = float(battery_voltage)
        if raw_v > 0:
            volts = raw_v / 10.0
            return f"{volts:.1f}V"

    battery_level = _cluster_attr_value(attrs, 47, 10)
    if isinstance(battery_level, (int, float)):
        level_map = {
            0: "unk",
            1: "crit",
            2: "low",
            3: "ok",
        }
        return level_map.get(int(battery_level), "")

    return ""


def _last_ack_info(node_id: int, attrs: dict, keepalive_metrics: dict[str, dict]) -> tuple[str, float | None]:
    if not _is_thread_candidate(attrs):
        return "---", None
    entry = keepalive_metrics.get(str(node_id))
    if not isinstance(entry, dict):
        return "", None
    last_ack = entry.get("last_ack_epoch")
    if isinstance(last_ack, (int, float)):
        try:
            ack_epoch = float(last_ack)
            text = datetime.fromtimestamp(ack_epoch).strftime("%H:%M:%S")
            age_sec = max(0.0, datetime.now().timestamp() - ack_epoch)
            return text, age_sec
        except Exception:
            return "", None
    return "", None


def _color_last_ack(value_text: str, age_sec: float | None, color: bool) -> str:
    if not color or not value_text:
        return value_text
    if value_text == "---":
        return value_text
    if age_sec is None:
        return f"{RED}{value_text}{RESET}"
    if age_sec < 60.0:
        return f"{WHITE}{value_text}{RESET}"
    if age_sec <= 150.0:
        return f"{YELLOW}{value_text}{RESET}"
    return f"{RED}{value_text}{RESET}"


def _env_bool(name: str, default: bool) -> bool:
    raw = os.getenv(name)
    if raw is None:
        return default
    value = raw.strip().lower()
    if value in {"1", "true", "yes", "on"}:
        return True
    if value in {"0", "false", "no", "off"}:
        return False
    return default


def _zbt2_row(color: bool) -> tuple[str, dict] | None:
    if not _env_bool("MATTER_WATCH_ZBT2_ENABLE", True):
        return None

    byid_glob = (os.getenv("MATTER_WATCH_ZBT2_BYID_GLOB", ZBT2_BYID_GLOB_DEFAULT) or "").strip()
    room = (os.getenv("MATTER_WATCH_ZBT2_ROOM", ZBT2_ROOM_DEFAULT) or ZBT2_ROOM_DEFAULT).strip()
    room = room or ZBT2_ROOM_DEFAULT

    radio_present = bool(byid_glob) and bool(glob.glob(byid_glob))
    otbr_active = _service_is_active("podman-otbr.service")
    available = radio_present and otbr_active

    if available:
        status = "ready"
    elif radio_present and not otbr_active:
        status = "otbr down"
    elif otbr_active and not radio_present:
        status = "usb missing"
    else:
        status = "down"

    label = "ZBT-2"
    label_colored = label
    if color:
        label_colored = f"{GREEN}{label}{RESET}" if available else f"{RED}{label}{RESET}"

    row = {
        "node": "zbt2",
        "status": status,
        "rssi": "",
        "label": label_colored,
        "last_ack": "---",
        "battery": "",
        "device": "Nabu Casa ZBT-2 (OTBR host radio)",
    }
    return room, row


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
    rooms: dict[str, str],
    rooms_by_label: dict[str, str],
    keepalive_metrics: dict[str, dict],
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

    lines: list[str] = [
        f"Matter device connectivity  ({now})",
        f"WS: {ws_url}",
        solar_line,
        facade_line,
        f"Matter last started: {_service_last_started('podman-matter-server.service')}",
        f"OTBR last started:   {_service_last_started('podman-otbr.service')}",
        f"Polling every {interval:.1f}s. Press Ctrl+C to stop.",
        "-" * min(width, 160),
    ]

    grouped: dict[str, list[dict]] = {}
    for node in sorted(nodes, key=lambda n: n.get("node_id", 0)):
        attrs = node.get("attributes") or {}
        room = _room_for_attrs(attrs, rooms, rooms_by_label)
        grouped.setdefault(room, []).append(node)

    synthetic_grouped: dict[str, list[dict]] = {}
    zbt2 = _zbt2_row(color)
    if zbt2:
        room, row = zbt2
        synthetic_grouped.setdefault(room, []).append(row)

    preferred_order = [
        "Office",
        "Nursery",
        "MBR Bathroom",
        "Downstairs",
        "Upstairs",
        "Network Closet",
        "Ungrouped",
    ]
    room_order = sorted(
        (set(grouped.keys()) | set(synthetic_grouped.keys())),
        key=lambda r: (preferred_order.index(r) if r in preferred_order else 1000, r),
    )

    header = (
        f"{'Node':<6}  {'Status':<14}  "
        f"{'RSSI':<5}  {'Label':<24}  {'LastAck':<8}  {'Battery':<7}  Device"
    )
    header_sep = (
        f"{'----':<6}  {'------':<14}  "
        f"{'----':<5}  {'-----':<24}  {'-------':<8}  {'-------':<7}  ------"
    )

    for room in room_order:
        room_nodes = grouped.get(room, [])
        row_lines: list[str] = [header, header_sep]
        for node in room_nodes:
            node_id = node.get("node_id")
            available = bool(node.get("available"))
            attrs = node.get("attributes") or {}
            label = attrs.get("0/40/5") or "(no label)"
            vendor = attrs.get("0/40/1") or ""
            product = attrs.get("0/40/3") or ""
            _, rssi = _thread_link_metrics(attrs)
            rssi_text = _color_rssi(rssi, color)
            ack_source_id = node_id if isinstance(node_id, int) else -1
            ack_raw, ack_age = _last_ack_info(ack_source_id, attrs, keepalive_metrics)
            ack_text = _color_last_ack(ack_raw, ack_age, color)
            battery_text = _battery_text(attrs)
            status = _device_status(vendor, product, label, attrs, color)
            label_text = label[:24]
            if color:
                label_colored = f"{GREEN}{label_text}{RESET}" if available else f"{RED}{label_text}{RESET}"
            else:
                label_colored = label_text
            device = f"{vendor} {product}".strip()
            row_lines.append(
                f"{_pad(str(node_id), 6)}  "
                f"{_pad(status, 14)}  "
                f"{_pad(rssi_text, 5)}  "
                f"{_pad(label_colored, 24)}  "
                f"{_pad(ack_text, 8)}  "
                f"{_pad(battery_text, 7)}  "
                f"{device}"
            )

        for row in synthetic_grouped.get(room, []):
            row_lines.append(
                f"{_pad(str(row['node']), 6)}  "
                f"{_pad(row['status'], 14)}  "
                f"{_pad(row['rssi'], 5)}  "
                f"{_pad(row['label'], 24)}  "
                f"{_pad(row['last_ack'], 8)}  "
                f"{_pad(row['battery'], 7)}  "
                f"{row['device']}"
            )

        content_width = max((_display_width(x) for x in row_lines), default=0)
        room_title = f"─ {room} "
        room_title_width = _display_width(room_title)
        content_width = max(content_width, room_title_width)
        top_fill = max(0, (content_width + 2) - room_title_width)
        top = "┌" + room_title + ("─" * top_fill) + "┐"
        bottom = "└" + ("─" * (content_width + 2)) + "┘"
        lines.append(top)
        for row in row_lines:
            lines.append(f"│ {_pad(row, content_width)} │")
        lines.append(bottom)

    return "\n".join(lines) + "\n"


async def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--ws-url", default=os.getenv("MATTER_WS_URL", WS_URL_DEFAULT))
    parser.add_argument("--solar-api-url", default=os.getenv("MATTER_SOLAR_API_URL", "http://127.0.0.1:8056/solar"))
    parser.add_argument("--keepalive-latency-file", default=os.getenv("MATTER_KEEPALIVE_LATENCY_FILE", KEEPALIVE_LATENCY_FILE_DEFAULT))
    parser.add_argument("--interval", type=float, default=2.0)
    parser.add_argument("--no-color", action="store_true")
    args = parser.parse_args()

    use_color = (not args.no_color) and sys.stdout.isatty()
    first = True

    try:
        rooms_raw = os.getenv("MATTER_NODE_ROOMS_JSON", "{}")
        parsed_rooms = json.loads(rooms_raw)
        node_rooms = _expand_env_backed_rooms(parsed_rooms if isinstance(parsed_rooms, dict) else {})
    except Exception:
        node_rooms = {}

    try:
        rooms_by_label_raw = os.getenv("MATTER_NODE_ROOMS_BY_LABEL_JSON", "{}")
        parsed_rooms_by_label = json.loads(rooms_by_label_raw)
        node_rooms_by_label = parsed_rooms_by_label if isinstance(parsed_rooms_by_label, dict) else {}
    except Exception:
        node_rooms_by_label = {}

    while True:
        try:
            nodes = await _poll(args.ws_url)
            solar_data = _fetch_solar(args.solar_api_url)
            keepalive_metrics = _load_keepalive_metrics(args.keepalive_latency_file)
            _render(
                _table_text(
                    nodes,
                    use_color,
                    args.ws_url,
                    args.interval,
                    solar_data,
                    node_rooms,
                    node_rooms_by_label,
                    keepalive_metrics,
                ),
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
