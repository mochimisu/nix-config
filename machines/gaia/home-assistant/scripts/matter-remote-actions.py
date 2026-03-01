#!/usr/bin/env python3
import asyncio
import base64
import json
import os
import sys
import time

import websockets

WS_URL_DEFAULT = "ws://127.0.0.1:5580/ws"
REMOTE_MAC = os.getenv("MATTER_REMOTE_MAC", "")
REMOTE_NODE_ID = int(os.getenv("MATTER_REMOTE_NODE_ID", "0"))
BLINDS_MAC = os.getenv("MATTER_BLINDS_MAC", "")
BLINDS_ENDPOINT = int(os.getenv("MATTER_BLINDS_ENDPOINT", "1"))
KEEPALIVE_NODE_IDS_ENV = os.getenv("MATTER_KEEPALIVE_NODE_IDS", "")
KEEPALIVE_INTERVAL_SEC = int(os.getenv("MATTER_KEEPALIVE_INTERVAL_SEC", "30"))
KEEPALIVE_LATENCY_FILE = os.getenv("MATTER_KEEPALIVE_LATENCY_FILE", "/run/matter-keepalive-latency.json")
SWITCH_CLUSTER_ID = 59
WINDOW_COVERING_CLUSTER_ID = 258
SWITCH_EVENT_MULTI_PRESS_COMPLETE = 6
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


def _parse_node_ids(raw: str) -> set[int]:
    node_ids: set[int] = set()
    for token in raw.split(","):
        value = token.strip()
        if not value:
            continue
        try:
            node_id = int(value)
        except ValueError:
            continue
        if node_id > 0:
            node_ids.add(node_id)
    return node_ids


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


async def _discover_keepalive_nodes(ws, seed_node_ids: set[int]) -> set[int]:
    keepalive_node_ids = set(seed_node_ids)
    start = await _call(ws, "keepalive:start", "start_listening")
    nodes = start.get("result") or []
    for node in nodes:
        node_id = node.get("node_id")
        if not isinstance(node_id, int) or node_id <= 0:
            continue
        attrs = node.get("attributes") or {}
        if _is_thread_candidate(attrs):
            keepalive_node_ids.add(node_id)
    return keepalive_node_ids


def _write_keepalive_metrics(metrics: dict[str, dict]) -> None:
    parent = os.path.dirname(KEEPALIVE_LATENCY_FILE) or "."
    os.makedirs(parent, exist_ok=True)
    tmp = f"{KEEPALIVE_LATENCY_FILE}.tmp"
    payload = {
        "updated_at_epoch": time.time(),
        "nodes": metrics,
    }
    with open(tmp, "w", encoding="utf-8") as handle:
        json.dump(payload, handle, separators=(",", ":"), sort_keys=True)
    os.replace(tmp, KEEPALIVE_LATENCY_FILE)


def _load_keepalive_metrics() -> dict[str, dict]:
    try:
        with open(KEEPALIVE_LATENCY_FILE, "r", encoding="utf-8") as handle:
            data = json.load(handle)
    except Exception:
        return {}
    if not isinstance(data, dict):
        return {}
    nodes = data.get("nodes")
    return nodes if isinstance(nodes, dict) else {}


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
    message_id = f"cmd:{node_id}:{endpoint_id}:{cluster_id}:{command_name}"
    response = await _call(
        ws,
        message_id,
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


async def _keepalive_once(ws_url: str, seed_node_ids: set[int]) -> None:
    async with websockets.connect(ws_url) as ws:
        await ws.recv()  # server info frame
        keepalive_node_ids = await _discover_keepalive_nodes(ws, seed_node_ids)
        previous_metrics = _load_keepalive_metrics()
        metrics: dict[str, dict] = {}
        for node_id in sorted(keepalive_node_ids):
            node_key = str(node_id)
            previous_entry = previous_metrics.get(node_key)
            previous_last_ack = None
            if isinstance(previous_entry, dict):
                previous_last_ack = previous_entry.get("last_ack_epoch")
            started = time.monotonic()
            response = await _call(
                ws,
                f"keepalive:{node_id}",
                "read_attribute",
                {
                    "node_id": node_id,
                    "attribute_path": "0/40/5",  # BasicInformation.NodeLabel
                },
            )
            latency_ms = (time.monotonic() - started) * 1000.0
            if "error_code" in response:
                details = response.get("details") or "unknown error"
                entry = {
                    "ok": False,
                    "latency_ms": latency_ms,
                    "error": details,
                }
                if isinstance(previous_last_ack, (int, float)):
                    entry["last_ack_epoch"] = float(previous_last_ack)
                metrics[node_key] = entry
                print(
                    f"keepalive node_id={node_id} failed: {details}",
                    file=sys.stderr,
                    flush=True,
                )
            else:
                metrics[node_key] = {
                    "ok": True,
                    "latency_ms": latency_ms,
                    "last_ack_epoch": time.time(),
                }
        _write_keepalive_metrics(metrics)


async def _keepalive_loop(ws_url: str, node_ids: set[int], interval_sec: int) -> None:
    if interval_sec <= 0:
        return

    while True:
        try:
            await _keepalive_once(ws_url, node_ids)
        except Exception as err:
            print(f"keepalive loop error: {err}", file=sys.stderr, flush=True)
        await asyncio.sleep(interval_sec)


async def _run() -> int:
    ws_url = os.getenv("MATTER_WS_URL", WS_URL_DEFAULT)
    keepalive_node_ids = _parse_node_ids(KEEPALIVE_NODE_IDS_ENV)

    async with websockets.connect(ws_url) as ws:
        await ws.recv()  # server info frame

        start = await _call(ws, "start", "start_listening")
        if "error_code" in start:
            details = start.get("details") or "unknown error"
            print(f"start_listening failed: {details}", file=sys.stderr)
            return 1

        nodes = start.get("result") or []
        remote_node_id = REMOTE_NODE_ID if REMOTE_NODE_ID > 0 else None
        blinds_node_id = None

        for node in nodes:
            node_id = node.get("node_id")
            attrs = node.get("attributes") or {}
            mac = _mac_from_attrs(attrs)
            if REMOTE_MAC and mac and mac.lower() == REMOTE_MAC.lower():
                remote_node_id = node_id
            if BLINDS_MAC and mac and mac.lower() == BLINDS_MAC.lower():
                blinds_node_id = node_id

        if remote_node_id is None:
            print("remote node not found; set MATTER_REMOTE_NODE_ID or MATTER_REMOTE_MAC", file=sys.stderr)
            return 1
        if blinds_node_id is None:
            print(f"blinds node not found by mac {BLINDS_MAC}", file=sys.stderr)
            return 1

        keepalive_node_ids.add(remote_node_id)

        print(
            "listening for remote node_id="
            f"{remote_node_id}, controlling blinds node_id={blinds_node_id}, "
            f"keepalive_seed_nodes={sorted(keepalive_node_ids)} "
            f"(plus dynamic thread devices) interval={KEEPALIVE_INTERVAL_SEC}s",
            flush=True,
        )

        keepalive_task = asyncio.create_task(
            _keepalive_loop(ws_url, keepalive_node_ids, KEEPALIVE_INTERVAL_SEC)
        )

        current_direction = "idle"  # one of: idle, up, down

        try:
            while True:
                message = json.loads(await ws.recv())
                if message.get("event") != "node_event":
                    continue

                data = message.get("data") or {}
                if data.get("node_id") != remote_node_id:
                    continue

                endpoint_id = data.get("endpoint_id")
                cluster_id = data.get("cluster_id")
                event_id = data.get("event_id")

                if cluster_id != SWITCH_CLUSTER_ID or event_id != SWITCH_EVENT_MULTI_PRESS_COMPLETE:
                    continue

                press_count = (data.get("data") or {}).get("totalNumberOfPressesCounted")
                if press_count != 1:
                    continue

                desired_direction = None
                if endpoint_id == 1:
                    desired_direction = "up"
                elif endpoint_id == 2:
                    desired_direction = "down"

                if desired_direction is None:
                    continue

                try:
                    if current_direction == desired_direction:
                        await _device_command(
                            ws,
                            node_id=blinds_node_id,
                            endpoint_id=BLINDS_ENDPOINT,
                            cluster_id=WINDOW_COVERING_CLUSTER_ID,
                            command_name="StopMotion",
                            payload={},
                        )
                        current_direction = "idle"
                        print(f"remote button {endpoint_id}: stop blinds", flush=True)
                    else:
                        command_name = "UpOrOpen" if desired_direction == "up" else "DownOrClose"
                        mode = "reverse" if current_direction in ("up", "down") else "start"
                        await _device_command(
                            ws,
                            node_id=blinds_node_id,
                            endpoint_id=BLINDS_ENDPOINT,
                            cluster_id=WINDOW_COVERING_CLUSTER_ID,
                            command_name=command_name,
                            payload={},
                        )
                        current_direction = desired_direction
                        print(f"remote button {endpoint_id}: {mode} {desired_direction}", flush=True)
                except Exception as err:
                    print(f"command failed: {err}", file=sys.stderr, flush=True)
        finally:
            keepalive_task.cancel()
            with contextlib.suppress(asyncio.CancelledError):
                await keepalive_task


async def main() -> int:
    while True:
        try:
            return await _run()
        except Exception as err:
            print(f"listener error: {err}", file=sys.stderr, flush=True)
            await asyncio.sleep(3)


if __name__ == "__main__":
    import contextlib

    raise SystemExit(asyncio.run(main()))
