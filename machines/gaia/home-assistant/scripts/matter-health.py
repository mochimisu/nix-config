#!/usr/bin/env python3
import asyncio
import base64
import json
import os
import sys

import websockets

WS_URL_DEFAULT = "ws://127.0.0.1:5580/ws"


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


async def _call(ws, message_id: str, command: str, args: dict | None = None) -> dict:
    payload = {"message_id": message_id, "command": command, "args": args or {}}
    await ws.send(json.dumps(payload))
    while True:
        message = json.loads(await ws.recv())
        if message.get("event"):
            continue
        if message.get("message_id") == message_id:
            return message


async def _run() -> int:
    ws_url = os.getenv("MATTER_WS_URL", WS_URL_DEFAULT)

    async with websockets.connect(ws_url) as ws:
        await ws.recv()  # server_info

        start = await _call(ws, "start", "start_listening")
        if "error_code" in start:
            details = start.get("details") or "unknown error"
            print(f"start_listening failed: {details}", file=sys.stderr)
            return 1

        nodes = start.get("result") or []
        print("node_id\tavailable\tlabel\tmac\tvendor\tproduct")

        for node in sorted(nodes, key=lambda n: n.get("node_id", 0)):
            node_id = node.get("node_id")
            available = bool(node.get("available"))
            attrs = node.get("attributes") or {}
            label = (attrs.get("0/40/5") or "").replace("\t", " ")
            vendor = (attrs.get("0/40/1") or "").replace("\t", " ")
            product = (attrs.get("0/40/3") or "").replace("\t", " ")
            mac = _mac_from_attrs(attrs) or ""
            print(f"{node_id}\t{available}\t{label}\t{mac}\t{vendor}\t{product}")

    return 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(_run()))
