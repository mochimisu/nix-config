#!/usr/bin/env python3
import asyncio
import base64
import json
import os
import sys
import time

import websockets

WS_URL_DEFAULT = "ws://127.0.0.1:5580/ws"
KEEPALIVE_INTERVAL_SEC = int(os.getenv("MATTER_KEEPALIVE_INTERVAL_SEC", "30"))
KEEPALIVE_LATENCY_FILE = os.getenv("MATTER_KEEPALIVE_LATENCY_FILE", "/run/matter-keepalive-latency.json")
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


async def _discover_keepalive_nodes(ws) -> list[tuple[int, dict]]:
    start = await _call(ws, "keepalive:start", "start_listening")
    if "error_code" in start:
        details = start.get("details") or "unknown error"
        raise RuntimeError(f"start_listening failed: {details}")

    found: list[tuple[int, dict]] = []
    for node in start.get("result") or []:
        node_id = node.get("node_id")
        attrs = node.get("attributes") or {}
        if not isinstance(node_id, int) or node_id <= 0:
            continue
        if _is_thread_candidate(attrs):
            found.append((node_id, attrs))
    return found


async def _keepalive_once(ws_url: str) -> None:
    async with websockets.connect(ws_url) as ws:
        await ws.recv()
        nodes = await _discover_keepalive_nodes(ws)
        previous_metrics = _load_keepalive_metrics()
        metrics: dict[str, dict] = {}

        for node_id, _attrs in sorted(nodes, key=lambda item: item[0]):
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
                    "attribute_path": "0/40/5",
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
                print(f"keepalive node_id={node_id} failed: {details}", file=sys.stderr, flush=True)
            else:
                metrics[node_key] = {
                    "ok": True,
                    "latency_ms": latency_ms,
                    "last_ack_epoch": time.time(),
                }

        _write_keepalive_metrics(metrics)


async def _run() -> int:
    ws_url = os.getenv("MATTER_WS_URL", WS_URL_DEFAULT)
    if KEEPALIVE_INTERVAL_SEC <= 0:
        return 0

    while True:
        try:
            await _keepalive_once(ws_url)
        except Exception as err:
            print(f"keepalive loop error: {err}", file=sys.stderr, flush=True)
        await asyncio.sleep(KEEPALIVE_INTERVAL_SEC)


if __name__ == "__main__":
    raise SystemExit(asyncio.run(_run()))
