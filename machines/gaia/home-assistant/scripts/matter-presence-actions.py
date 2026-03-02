#!/usr/bin/env python3
import asyncio
import base64
import datetime
import json
import math
import os
from pathlib import Path
import sys
import time

import websockets
from solar_window import is_now_in_solar_window

WS_URL_DEFAULT = "ws://127.0.0.1:5580/ws"
DEFAULT_PRESENCE_PATHS = [
    "1/1030/0",
    "2/1030/0",
    "0/1030/0",
]
DEFAULT_LUMINANCE_PATHS = [
    "1/1024/0",
    "2/1024/0",
    "0/1024/0",
]
SWITCH_CLUSTER_ID = 59
SWITCH_EVENT_MULTI_PRESS_COMPLETE = 6
SWITCH_SINGLE_PRESS_COUNT = 1
SWITCH_UP_ENDPOINT_IDS = {1, 3}
SWITCH_DOWN_ENDPOINT_IDS = {2, 4}
DEFAULT_MANUAL_OVERRIDE_TIMEOUT_SEC = 30.0 * 60.0


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


def _node_key(attrs: dict) -> str | None:
    unique_id = attrs.get("0/40/18")
    if isinstance(unique_id, str) and unique_id:
        return f"unique_id:{unique_id}"
    serial = attrs.get("0/40/15")
    if isinstance(serial, str) and serial:
        return f"serial:{serial}"
    mac = _mac_from_attrs(attrs)
    if mac:
        return f"mac:{mac}"
    return None


def _as_present(value) -> bool:
    if isinstance(value, bool):
        return value
    if isinstance(value, int):
        return value != 0
    return False


def _as_bool(value) -> bool | None:
    if isinstance(value, bool):
        return value
    if isinstance(value, int):
        return value != 0
    return None


def _as_int(value) -> int | None:
    if isinstance(value, bool):
        return int(value)
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        if value.is_integer():
            return int(value)
        return None
    if isinstance(value, str):
        text = value.strip()
        if not text:
            return None
        try:
            return int(text)
        except ValueError:
            return None
    return None


def _presence_from_attrs(
    attrs: dict,
    candidate_paths: list[str],
    *,
    allow_any_fallback: bool = True,
) -> bool | None:
    for path in candidate_paths:
        if path in attrs:
            return _as_present(attrs.get(path))

    if not allow_any_fallback:
        return None

    # Fallback for sensors that expose Occupancy at a non-standard endpoint.
    for path, value in attrs.items():
        if isinstance(path, str) and path.endswith("/1030/0"):
            return _as_present(value)
    return None


def _target_light_onoff_from_attrs(attrs: dict, preferred_path: str | None) -> bool | None:
    if isinstance(preferred_path, str) and preferred_path:
        if preferred_path in attrs:
            return _as_bool(attrs.get(preferred_path))

    for path, value in attrs.items():
        if isinstance(path, str) and path.endswith("/6/0"):
            parsed = _as_bool(value)
            if parsed is not None:
                return parsed
    return None


def _set_target_light_onoff_in_attrs(
    attrs: dict,
    preferred_path: str | None,
    value: bool,
) -> None:
    if isinstance(preferred_path, str) and preferred_path:
        attrs[preferred_path] = value
        return

    for path in attrs.keys():
        if isinstance(path, str) and path.endswith("/6/0"):
            attrs[path] = value
            return


def _command_desired_onoff(command_name: str) -> bool | None:
    name = (command_name or "").strip().lower()
    if name == "on":
        return True
    if name == "off":
        return False
    return None


def _supports_manual_indicator(attrs: dict) -> bool:
    # Inovelli dimmers expose an auxiliary indicator LED on endpoint 6 with
    # OnOff/Level/ColorControl clusters.
    return (
        "6/6/0" in attrs
        and "6/8/0" in attrs
        and any(isinstance(path, str) and path.startswith("6/768/") for path in attrs.keys())
    )


def _as_float(value) -> float | None:
    if isinstance(value, (int, float)):
        return float(value)
    if isinstance(value, str):
        text = value.strip()
        if not text:
            return None
        try:
            return float(text)
        except ValueError:
            return None
    return None


async def _set_manual_indicator(
    ws,
    *,
    node_id: int,
    enabled: bool,
) -> None:
    if enabled:
        # Turn on endpoint-6 indicator and set it to green.
        await _device_command(
            ws,
            node_id=node_id,
            endpoint_id=6,
            cluster_id=6,
            command_name="On",
            payload={},
        )
        await _device_command(
            ws,
            node_id=node_id,
            endpoint_id=6,
            cluster_id=8,
            command_name="MoveToLevelWithOnOff",
            payload={
                "level": 254,
                "transitionTime": 0,
                "optionsMask": 0,
                "optionsOverride": 0,
            },
        )
        await _device_command(
            ws,
            node_id=node_id,
            endpoint_id=6,
            cluster_id=768,
            command_name="MoveToHueAndSaturation",
            payload={
                "hue": 85,  # green
                "saturation": 254,
                "transitionTime": 0,
                "optionsMask": 0,
                "optionsOverride": 0,
            },
        )
        return

    await _device_command(
        ws,
        node_id=node_id,
        endpoint_id=6,
        cluster_id=6,
        command_name="Off",
        payload={},
    )


def _manual_override_from_event(event_data: dict | None, *, target_node_id: int) -> bool | None:
    if not isinstance(event_data, dict):
        return None
    if _as_int(event_data.get("node_id")) != target_node_id:
        return None
    if _as_int(event_data.get("cluster_id")) != SWITCH_CLUSTER_ID:
        return None
    if _as_int(event_data.get("event_id")) != SWITCH_EVENT_MULTI_PRESS_COMPLETE:
        return None

    payload = event_data.get("data")
    if isinstance(payload, dict):
        press_count = payload.get("totalNumberOfPressesCounted")
        parsed_press_count = _as_int(press_count)
        if parsed_press_count is not None and parsed_press_count != SWITCH_SINGLE_PRESS_COUNT:
            return None

    endpoint_id = _as_int(event_data.get("endpoint_id"))
    if endpoint_id in SWITCH_UP_ENDPOINT_IDS:
        return True
    if endpoint_id in SWITCH_DOWN_ENDPOINT_IDS:
        return False
    return None


def _parse_hhmm(value: str) -> int | None:
    if not isinstance(value, str):
        return None
    parts = value.split(":")
    if len(parts) != 2:
        return None
    try:
        hour = int(parts[0])
        minute = int(parts[1])
    except ValueError:
        return None
    if hour < 0 or hour > 23 or minute < 0 or minute > 59:
        return None
    return (hour * 60) + minute


def _parse_time_windows(raw_windows) -> list[tuple[int, int]]:
    windows: list[tuple[int, int]] = []
    if not isinstance(raw_windows, list):
        return windows
    for item in raw_windows:
        if not isinstance(item, dict):
            continue
        start = _parse_hhmm(item.get("start"))
        end = _parse_hhmm(item.get("end"))
        if start is None or end is None:
            continue
        windows.append((start, end))
    return windows


def _as_nonempty_str(value) -> str | None:
    if isinstance(value, str):
        text = value.strip()
        if text:
            return text
    return None


def _node_key_from_env_name(env_name: str | None) -> str | None:
    if not isinstance(env_name, str) or not env_name:
        return None
    raw = os.getenv(env_name, "").strip()
    if not raw:
        return None
    if raw.startswith("unique_id:") or raw.startswith("serial:") or raw.startswith("mac:"):
        return raw
    return f"unique_id:{raw}"


def _resolve_node_key(raw_key: str | None) -> str | None:
    if not isinstance(raw_key, str):
        return None
    key = raw_key.strip()
    if not key:
        return None

    if key.startswith("unique_id_env:"):
        env_name = key.split(":", 1)[1].strip()
        value = (os.getenv(env_name, "") or "").strip()
        return f"unique_id:{value}" if value else None
    if key.startswith("serial_env:"):
        env_name = key.split(":", 1)[1].strip()
        value = (os.getenv(env_name, "") or "").strip()
        return f"serial:{value}" if value else None
    if key.startswith("mac_env:"):
        env_name = key.split(":", 1)[1].strip()
        value = (os.getenv(env_name, "") or "").strip().lower()
        return f"mac:{value}" if value else None
    return key


def _parse_solar_window(raw) -> dict | None:
    if not isinstance(raw, dict):
        return None

    mode = _as_nonempty_str(raw.get("mode")) or "sunset_to_sunrise"
    latitude = _as_float(raw.get("latitude"))
    longitude = _as_float(raw.get("longitude"))
    timezone_name = _as_nonempty_str(raw.get("timezone"))

    return {
        "mode": mode,
        "latitude": latitude,
        "longitude": longitude,
        "timezone": timezone_name,
        "latitude_env": _as_nonempty_str(raw.get("latitude_env")),
        "longitude_env": _as_nonempty_str(raw.get("longitude_env")),
        "timezone_env": _as_nonempty_str(raw.get("timezone_env")),
    }


def _resolve_solar_window(raw_config: dict | None) -> dict | None:
    if not raw_config:
        return None

    lat = raw_config.get("latitude")
    lon = raw_config.get("longitude")
    tz_name = raw_config.get("timezone")

    if lat is None and raw_config.get("latitude_env"):
        lat = _as_float(os.getenv(raw_config["latitude_env"], ""))
    if lon is None and raw_config.get("longitude_env"):
        lon = _as_float(os.getenv(raw_config["longitude_env"], ""))
    if tz_name is None and raw_config.get("timezone_env"):
        tz_name = _as_nonempty_str(os.getenv(raw_config["timezone_env"], ""))
    if tz_name is None:
        tz_name = _as_nonempty_str(os.getenv("TZ", ""))
    if tz_name is None:
        # Derive timezone name from /etc/localtime symlink when possible.
        try:
            localtime_target = Path("/etc/localtime").resolve()
            parts = localtime_target.parts
            if "zoneinfo" in parts:
                idx = parts.index("zoneinfo")
                candidate = "/".join(parts[idx + 1 :])
                tz_name = _as_nonempty_str(candidate)
        except Exception:
            pass
    if tz_name is None:
        tz_name = "America/Los_Angeles"

    if lat is None or lon is None or tz_name is None:
        return None

    return {
        "mode": raw_config["mode"],
        "latitude": lat,
        "longitude": lon,
        "timezone": tz_name,
    }


def _is_in_time_window(now_minute: int, start_minute: int, end_minute: int) -> bool:
    if start_minute == end_minute:
        return True
    if start_minute < end_minute:
        return start_minute <= now_minute < end_minute
    return now_minute >= start_minute or now_minute < end_minute


def _is_now_in_any_window(windows: list[tuple[int, int]]) -> bool:
    if not windows:
        return True
    now = datetime.datetime.now().time()
    now_minute = (now.hour * 60) + now.minute
    return any(_is_in_time_window(now_minute, start, end) for start, end in windows)


def _matter_illuminance_to_lux(measured_value: float) -> float:
    # Illuminance Measurement cluster (0x0400): measured_value is logarithmic.
    # lux = 10 ^ ((measured_value - 1) / 10000)
    if measured_value <= 0:
        return 0.0
    return math.pow(10.0, (measured_value - 1.0) / 10000.0)


def _luminance_lux_from_attrs(attrs: dict, candidate_paths: list[str], mode: str) -> float | None:
    for path in candidate_paths:
        if path not in attrs:
            continue
        raw = _as_float(attrs.get(path))
        if raw is None:
            continue
        if mode == "raw_lux":
            return raw
        # Default: Matter illuminance measured value.
        return _matter_illuminance_to_lux(raw)

    # Fallback: any endpoint with illuminance measured value attribute.
    for path, value in attrs.items():
        if not (isinstance(path, str) and path.endswith("/1024/0")):
            continue
        raw = _as_float(value)
        if raw is None:
            continue
        if mode == "raw_lux":
            return raw
        return _matter_illuminance_to_lux(raw)
    return None


def _normalize_rule(raw: dict, index: int) -> dict | None:
    if not isinstance(raw, dict):
        return None
    source_key = raw.get("source_key")
    source_keys = raw.get("source_keys")
    source_key_env = raw.get("source_key_env")
    source_keys_env = raw.get("source_keys_env")
    target_key = raw.get("target_key")
    target_key_env = raw.get("target_key_env")
    if not isinstance(target_key, str) or not target_key:
        target_key = _node_key_from_env_name(target_key_env)
    target_key = _resolve_node_key(target_key if isinstance(target_key, str) else None)
    if not isinstance(target_key, str) or not target_key:
        return None

    normalized_source_keys: list[str] = []
    if isinstance(source_keys, list):
        normalized_source_keys = [str(x) for x in source_keys if isinstance(x, str) and x]
    elif isinstance(source_key, str) and source_key:
        normalized_source_keys = [source_key]
    elif isinstance(source_keys_env, list):
        for env_name in source_keys_env:
            key = _node_key_from_env_name(env_name if isinstance(env_name, str) else None)
            if key:
                normalized_source_keys.append(key)
    else:
        key = _node_key_from_env_name(source_key_env if isinstance(source_key_env, str) else None)
        if key:
            normalized_source_keys = [key]
    normalized_source_keys = [k for k in (_resolve_node_key(x) for x in normalized_source_keys) if k]
    if not normalized_source_keys:
        return None

    name = raw.get("name")
    if not isinstance(name, str) or not name:
        name = f"rule-{index}"

    paths = raw.get("presence_attribute_paths")
    if isinstance(paths, list):
        candidate_paths = [str(x) for x in paths if isinstance(x, str) and x]
        presence_paths_explicit = len(candidate_paths) > 0
    else:
        candidate_paths = list(DEFAULT_PRESENCE_PATHS)
        presence_paths_explicit = False

    luminance_paths = raw.get("luminance_attribute_paths")
    if isinstance(luminance_paths, list):
        candidate_luminance_paths = [str(x) for x in luminance_paths if isinstance(x, str) and x]
    else:
        candidate_luminance_paths = list(DEFAULT_LUMINANCE_PATHS)

    dark_when_lux_below = raw.get("dark_when_lux_below")
    dark_threshold = _as_float(dark_when_lux_below)
    require_luminance_for_on = bool(raw.get("require_luminance_for_on", False))
    luminance_mode = str(raw.get("luminance_mode", "matter_illuminance"))
    target_onoff_attribute_path = raw.get("target_onoff_attribute_path")
    if not isinstance(target_onoff_attribute_path, str):
        target_onoff_attribute_path = None
    on_active_windows = _parse_time_windows(raw.get("on_active_windows"))
    on_eligibility_mode = str(raw.get("on_eligibility_mode", "all")).lower()
    if on_eligibility_mode not in {"all", "any"}:
        on_eligibility_mode = "all"
    on_active_solar_window = _parse_solar_window(raw.get("on_active_solar_window"))
    manual_override_timeout_sec = _as_float(raw.get("manual_override_timeout_sec"))
    if manual_override_timeout_sec is None:
        manual_override_timeout_sec = _as_float(raw.get("manual_override_sec"))
    if manual_override_timeout_sec is None or manual_override_timeout_sec <= 0:
        manual_override_timeout_sec = DEFAULT_MANUAL_OVERRIDE_TIMEOUT_SEC

    return {
        "name": name,
        "source_keys": normalized_source_keys,
        "target_key": target_key,
        "target_endpoint": int(raw.get("target_endpoint", 1)),
        "cluster_id": int(raw.get("cluster_id", 6)),
        "on_command": str(raw.get("on_command", "On")),
        "off_command": str(raw.get("off_command", "Off")),
        "payload": raw.get("payload") if isinstance(raw.get("payload"), dict) else {},
        "presence_attribute_paths": candidate_paths,
        "presence_paths_explicit": presence_paths_explicit,
        "luminance_attribute_paths": candidate_luminance_paths,
        "dark_when_lux_below": dark_threshold,
        "require_luminance_for_on": require_luminance_for_on,
        "luminance_mode": luminance_mode,
        "target_onoff_attribute_path": target_onoff_attribute_path,
        "on_active_windows": on_active_windows,
        "on_eligibility_mode": on_eligibility_mode,
        "on_active_solar_window": on_active_solar_window,
        "manual_override_timeout_sec": manual_override_timeout_sec,
    }


async def _call(ws, message_id: str, command: str, args: dict | None = None) -> dict:
    payload = {"message_id": message_id, "command": command, "args": args or {}}
    await ws.send(json.dumps(payload))
    while True:
        message = json.loads(await ws.recv())
        if message.get("event"):
            continue
        if message.get("message_id") == message_id:
            return message


async def _device_command(
    ws,
    *,
    node_id: int,
    endpoint_id: int,
    cluster_id: int,
    command_name: str,
    payload: dict,
) -> None:
    response = await _call(
        ws,
        f"presence-cmd:{node_id}:{endpoint_id}:{cluster_id}:{command_name}",
        "device_command",
        {
            "node_id": node_id,
            "endpoint_id": endpoint_id,
            "cluster_id": cluster_id,
            "command_name": command_name,
            "payload": payload,
        },
    )
    if "error_code" in response:
        details = response.get("details") or "unknown error"
        raise RuntimeError(f"device_command {command_name} failed: {details}")


def _build_by_key(nodes: list[dict]) -> dict[str, dict]:
    by_key: dict[str, dict] = {}
    for node in nodes:
        node_id = node.get("node_id")
        if not isinstance(node_id, int):
            continue
        attrs = node.get("attributes") or {}
        key = _node_key(attrs)
        if key:
            by_key[key] = {
                "node_id": node_id,
                "attrs": attrs,
                "available": bool(node.get("available", False)),
            }
    return by_key


def _index_by_node_id(by_key: dict[str, dict]) -> dict[int, dict]:
    out: dict[int, dict] = {}
    for entry in by_key.values():
        node_id = entry.get("node_id")
        if isinstance(node_id, int):
            out[node_id] = entry
    return out


def _watched_node_ids(rules: list[dict], by_key: dict[str, dict]) -> set[int]:
    watched: set[int] = set()
    for rule in rules:
        for key in rule["source_keys"]:
            node = by_key.get(key)
            if node and isinstance(node.get("node_id"), int):
                watched.add(int(node["node_id"]))
        target = by_key.get(rule["target_key"])
        if target and isinstance(target.get("node_id"), int):
            watched.add(int(target["node_id"]))
    return watched


async def _read_snapshot(ws) -> dict[str, dict]:
    start = await _call(ws, "presence-start", "start_listening")
    if "error_code" in start:
        details = start.get("details") or "unknown error"
        raise RuntimeError(f"start_listening failed: {details}")
    nodes = start.get("result") or []
    return _build_by_key(nodes)


async def _evaluate_rules(
    ws,
    rules: list[dict],
    rule_state: dict[str, dict],
    by_key: dict[str, dict],
    trigger: str,
    event_data: dict | None = None,
) -> None:
    for rule in rules:
        state = rule_state.setdefault(
            rule["name"],
            {
                "last_presence": None,
                "last_on_eligible": None,
                "last_light_state": None,
                "manual_indicator_synced": False,
                "manual_indicator_enabled": None,
                "manual_override_value": None,
                "manual_override_expires_epoch": 0.0,
                "last_auto_command_epoch": 0.0,
                "last_presence_change_epoch": 0.0,
            },
        )
        sources = [by_key.get(key) for key in rule["source_keys"]]
        sources = [x for x in sources if x is not None]
        target = by_key.get(rule["target_key"])
        if not sources:
            print(
                f"presence rule {rule['name']}: source not found ({', '.join(rule['source_keys'])})",
                file=sys.stderr,
                flush=True,
            )
            continue
        if target is None:
            print(
                f"presence rule {rule['name']}: target not found ({rule['target_key']})",
                file=sys.stderr,
                flush=True,
            )
            continue
        if not target.get("available", False):
            continue

        now = asyncio.get_running_loop().time()

        previous_light_state = state.get("last_light_state")
        light_state = _target_light_onoff_from_attrs(
            target["attrs"],
            rule["target_onoff_attribute_path"],
        )
        state["last_light_state"] = light_state

        presence_values: list[bool] = []
        for source in sources:
            source_presence = _presence_from_attrs(
                source["attrs"],
                rule["presence_attribute_paths"],
                allow_any_fallback=not bool(rule.get("presence_paths_explicit")),
            )
            if source_presence is not None:
                presence_values.append(source_presence)
        if not presence_values:
            print(
                f"presence rule {rule['name']}: no occupancy attribute found on any source",
                file=sys.stderr,
                flush=True,
            )
            continue
        remote_present = any(presence_values)

        indicator_supported = _supports_manual_indicator(target["attrs"])
        override_value = state.get("manual_override_value")
        override_expires_epoch = state.get("manual_override_expires_epoch")
        override_active = (
            isinstance(override_value, bool)
            and isinstance(override_expires_epoch, (int, float))
            and now < float(override_expires_epoch)
        )

        if isinstance(override_value, bool) and not override_active:
            state["manual_override_value"] = None
            state["manual_override_expires_epoch"] = 0.0
            override_value = None
            override_expires_epoch = 0.0
            print(
                f"presence rule {rule['name']}: manual override expired; resuming presence",
                flush=True,
            )

        if indicator_supported:
            override_from_event = _manual_override_from_event(
                event_data,
                target_node_id=target["node_id"],
            )
            if override_from_event is not None:
                direction = "up" if override_from_event else "down"
                current_value = state.get("manual_override_value")
                current_expires_epoch = state.get("manual_override_expires_epoch")
                current_active = (
                    isinstance(current_value, bool)
                    and isinstance(current_expires_epoch, (int, float))
                    and now < float(current_expires_epoch)
                )
                if current_active and current_value == override_from_event:
                    state["manual_override_value"] = None
                    state["manual_override_expires_epoch"] = 0.0
                    print(
                        f"presence rule {rule['name']}: manual override cleared via {direction} press",
                        flush=True,
                    )
                else:
                    timeout_sec = float(rule["manual_override_timeout_sec"])
                    state["manual_override_value"] = override_from_event
                    state["manual_override_expires_epoch"] = now + timeout_sec
                    print(
                        f"presence rule {rule['name']}: manual override "
                        f"{'On' if override_from_event else 'Off'} for {int(timeout_sec / 60)}m "
                        f"via {direction} press",
                        flush=True,
                    )

        # Fallback path for cases where button node_event messages are missed:
        # infer manual intent from a direct target light-state change that did
        # not come from recent automation output.
        # Do not run this fallback during node_event handling, because an
        # explicit paddle event should always win (including clear-on-repeat).
        if (
            trigger != "node_event"
            and
            isinstance(previous_light_state, bool)
            and isinstance(light_state, bool)
            and previous_light_state != light_state
            and (now - float(state.get("last_auto_command_epoch") or 0.0)) > 10.0
        ):
            timeout_sec = float(rule["manual_override_timeout_sec"])
            state["manual_override_value"] = light_state
            state["manual_override_expires_epoch"] = now + timeout_sec
            print(
                f"presence rule {rule['name']}: manual override "
                f"{'On' if light_state else 'Off'} for {int(timeout_sec / 60)}m "
                f"via target state change",
                flush=True,
            )

        override_value = state.get("manual_override_value")
        override_expires_epoch = state.get("manual_override_expires_epoch")
        override_active = (
            isinstance(override_value, bool)
            and isinstance(override_expires_epoch, (int, float))
            and now < float(override_expires_epoch)
        )

        if indicator_supported:
            desired_indicator_enabled = bool(override_active)
            if state.get("manual_indicator_enabled") != desired_indicator_enabled:
                try:
                    await _set_manual_indicator(
                        ws,
                        node_id=target["node_id"],
                        enabled=desired_indicator_enabled,
                    )
                    state["manual_indicator_synced"] = True
                    state["manual_indicator_enabled"] = desired_indicator_enabled
                except Exception as err:
                    print(
                        f"presence rule {rule['name']}: failed to set manual indicator "
                        f"{'On' if desired_indicator_enabled else 'Off'}: {err}",
                        file=sys.stderr,
                        flush=True,
                    )
        else:
            state["manual_indicator_synced"] = True
            state["manual_indicator_enabled"] = False

        if override_active:
            present = bool(override_value)
            previous_presence = state.get("last_presence")
            presence_changed = (previous_presence is None) or (previous_presence != present)
            state["last_presence"] = present
            if presence_changed:
                state["last_presence_change_epoch"] = now
            state["last_on_eligible"] = present

            command_name = rule["on_command"] if present else rule["off_command"]
            desired_onoff = _command_desired_onoff(command_name)
            if desired_onoff is None:
                should_issue_manual = presence_changed
            elif light_state is None:
                should_issue_manual = presence_changed
            else:
                should_issue_manual = light_state != desired_onoff
            if not should_issue_manual:
                continue

            cmd_started = time.monotonic()
            await _device_command(
                ws,
                node_id=target["node_id"],
                endpoint_id=rule["target_endpoint"],
                cluster_id=rule["cluster_id"],
                command_name=command_name,
                payload=rule["payload"],
            )
            cmd_rtt_ms = (time.monotonic() - cmd_started) * 1000.0
            state["last_auto_command_epoch"] = now
            if desired_onoff is not None:
                _set_target_light_onoff_in_attrs(
                    target["attrs"],
                    rule["target_onoff_attribute_path"],
                    desired_onoff,
                )
                state["last_light_state"] = desired_onoff
            print(
                f"presence rule {rule['name']}: manual_override={present} -> {command_name} "
                f"target_node_id={target['node_id']} trigger={trigger} cmd_rtt_ms={cmd_rtt_ms:.0f}",
                flush=True,
            )
            continue

        present = remote_present
        previous_presence = state.get("last_presence")
        presence_changed = (previous_presence is None) or (previous_presence != present)
        state["last_presence"] = present
        if presence_changed:
            state["last_presence_change_epoch"] = now

        previous_on_eligible = state.get("last_on_eligible")
        skip_on_reasons: list[str] = []
        pass_conditions: list[str] = []
        fail_conditions: list[str] = []

        if present and rule["dark_when_lux_below"] is not None:
            lux = _luminance_lux_from_attrs(
                sources[0]["attrs"],
                rule["luminance_attribute_paths"],
                rule["luminance_mode"],
            )
            cond_ok = True
            cond_reason = "lux-ok"
            if lux is None:
                if rule["require_luminance_for_on"]:
                    cond_ok = False
                    cond_reason = "luminance unavailable"
                else:
                    cond_reason = "luminance unavailable (allowed)"
            elif lux >= rule["dark_when_lux_below"]:
                cond_ok = False
                cond_reason = (
                    f"bright (lux={lux:.2f} >= {rule['dark_when_lux_below']})"
                )
            else:
                cond_reason = f"dark (lux={lux:.2f} < {rule['dark_when_lux_below']})"

            if cond_ok:
                pass_conditions.append(cond_reason)
            else:
                fail_conditions.append(cond_reason)

        if present and rule["on_active_windows"]:
            if _is_now_in_any_window(rule["on_active_windows"]):
                pass_conditions.append("inside active window")
            else:
                fail_conditions.append("outside active window")

        if present and rule["on_active_solar_window"] is not None:
            solar_window = _resolve_solar_window(rule["on_active_solar_window"])
            if solar_window is None:
                fail_conditions.append("solar window unavailable (missing coords/timezone)")
            else:
                in_solar_window = is_now_in_solar_window(
                    latitude=solar_window["latitude"],
                    longitude=solar_window["longitude"],
                    timezone_name=solar_window["timezone"],
                    mode=solar_window["mode"],
                )
                if in_solar_window is None:
                    fail_conditions.append("solar window unavailable (polar/no event)")
                elif in_solar_window:
                    pass_conditions.append(f"inside solar window ({solar_window['mode']})")
                else:
                    fail_conditions.append(f"outside solar window ({solar_window['mode']})")

        if not present:
            on_eligible = False
        else:
            has_conditions = bool(pass_conditions or fail_conditions)
            if not has_conditions:
                on_eligible = True
            elif rule["on_eligibility_mode"] == "any":
                on_eligible = len(pass_conditions) > 0
            else:
                on_eligible = len(fail_conditions) == 0

        state["last_on_eligible"] = on_eligible

        should_issue_on = bool(on_eligible) and (
            presence_changed or (previous_on_eligible is not True)
        )
        should_issue_off = (not present) and presence_changed

        if present and (not on_eligible) and (
            presence_changed or (previous_on_eligible is not False)
        ):
            if fail_conditions:
                skip_on_reasons.extend(fail_conditions)
            reason_text = "; ".join(skip_on_reasons) if skip_on_reasons else "conditions not met"
            print(
                f"presence rule {rule['name']}: presence detected but {reason_text}; skipping On",
                flush=True,
            )
            continue

        if not should_issue_on and not should_issue_off:
            continue

        command_name = rule["on_command"] if should_issue_on else rule["off_command"]
        desired_onoff = _command_desired_onoff(command_name)
        if desired_onoff is not None and light_state is not None and light_state == desired_onoff:
            print(
                f"presence rule {rule['name']}: present={present} -> "
                f"skip {command_name} (target already {'On' if light_state else 'Off'}) "
                f"trigger={trigger}",
                flush=True,
            )
            continue

        cmd_started = time.monotonic()
        await _device_command(
            ws,
            node_id=target["node_id"],
            endpoint_id=rule["target_endpoint"],
            cluster_id=rule["cluster_id"],
            command_name=command_name,
            payload=rule["payload"],
        )
        cmd_rtt_ms = (time.monotonic() - cmd_started) * 1000.0
        state["last_auto_command_epoch"] = now
        if desired_onoff is not None:
            _set_target_light_onoff_in_attrs(
                target["attrs"],
                rule["target_onoff_attribute_path"],
                desired_onoff,
            )
            state["last_light_state"] = desired_onoff
        observe_to_cmd_ms = None
        if isinstance(state.get("last_presence_change_epoch"), (int, float)):
            observe_to_cmd_ms = max(0.0, (now - float(state["last_presence_change_epoch"])) * 1000.0)
        latency_text = (
            f"observe_to_cmd_ms={observe_to_cmd_ms:.0f} cmd_rtt_ms={cmd_rtt_ms:.0f}"
            if observe_to_cmd_ms is not None
            else f"cmd_rtt_ms={cmd_rtt_ms:.0f}"
        )
        print(
            f"presence rule {rule['name']}: present={present} -> "
            f"{command_name} target_node_id={target['node_id']} trigger={trigger} {latency_text}",
            flush=True,
        )


async def _run() -> int:
    ws_url = os.getenv("MATTER_WS_URL", WS_URL_DEFAULT)
    # Event-driven automation loop with a periodic re-evaluation tick for
    # time-window and override-expiry logic.
    poll_interval_sec = float(os.getenv("MATTER_PRESENCE_POLL_INTERVAL_SEC", "1.0"))
    raw_rules = os.getenv("MATTER_PRESENCE_RULES_JSON", "[]")

    try:
        parsed = json.loads(raw_rules)
    except Exception as err:
        print(f"Invalid MATTER_PRESENCE_RULES_JSON: {err}", file=sys.stderr)
        return 2
    if not isinstance(parsed, list):
        print("MATTER_PRESENCE_RULES_JSON must be a JSON list", file=sys.stderr)
        return 2

    rules = []
    for i, item in enumerate(parsed):
        rule = _normalize_rule(item, i)
        if rule is not None:
            rules.append(rule)
    if not rules:
        print("matter-presence-actions: no valid rules configured", file=sys.stderr)
        return 1

    print(
        f"matter-presence-actions: rules={len(rules)} event_driven=true tick={poll_interval_sec}s",
        flush=True,
    )
    rule_state: dict[str, dict] = {}

    while True:
        try:
            async with websockets.connect(ws_url) as ws:
                await ws.recv()  # server_info
                by_key = await _read_snapshot(ws)
                by_node_id = _index_by_node_id(by_key)
                await _evaluate_rules(ws, rules, rule_state, by_key, "startup")
                watched = _watched_node_ids(rules, by_key)

                tick = max(0.25, poll_interval_sec)
                while True:
                    try:
                        raw = await asyncio.wait_for(ws.recv(), timeout=tick)
                    except asyncio.TimeoutError:
                        # Keep rule timing logic active on a fast tick.
                        await _evaluate_rules(ws, rules, rule_state, by_key, "tick")
                        continue

                    msg = json.loads(raw)
                    event_name = msg.get("event")
                    if event_name == "attribute_updated":
                        data = msg.get("data")
                        if (
                            isinstance(data, list)
                            and len(data) >= 3
                            and isinstance(data[0], int)
                            and isinstance(data[1], str)
                        ):
                            node_id = data[0]
                            if node_id in watched:
                                    entry = by_node_id.get(node_id)
                                    if entry is not None:
                                        entry["attrs"][data[1]] = data[2]
                                    await _evaluate_rules(
                                        ws,
                                        rules,
                                        rule_state,
                                        by_key,
                                        "attribute_updated",
                                        event_data={
                                            "type": "attribute_updated",
                                            "node_id": node_id,
                                            "attribute_path": data[1],
                                            "value": data[2],
                                        },
                                    )
                        continue

                    if event_name != "node_event":
                        continue
                    data = msg.get("data") or {}
                    node_id = data.get("node_id")
                    if not isinstance(node_id, int) or node_id not in watched:
                        continue

                    # Do not call start_listening again on this websocket:
                    # matter-server allows it only once per client connection.
                    await _evaluate_rules(ws, rules, rule_state, by_key, "node_event", event_data=data)
        except websockets.exceptions.ConnectionClosed as err:
            # The matter server may close idle/rotating sockets; reconnect fast
            # to avoid missing brief occupancy changes.
            print(f"presence listener closed: {err}; reconnecting", file=sys.stderr, flush=True)
            await asyncio.sleep(0.2)
        except Exception as err:
            print(f"presence listener error: {err}", file=sys.stderr, flush=True)
            await asyncio.sleep(3)


async def main() -> int:
    return await _run()


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
