#!/usr/bin/env python3
import argparse
import asyncio
import base64
import json
import os
import sys
from datetime import datetime

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
    parser = argparse.ArgumentParser()
    parser.add_argument("--ws-url", default=os.getenv("MATTER_WS_URL", WS_URL_DEFAULT))
    parser.add_argument("--remote-mac")
    parser.add_argument("--node-id", type=int)
    parser.add_argument("--all", action="store_true", help="Do not filter to one remote.")
    parser.add_argument("--raw", action="store_true", help="Print raw JSON events.")
    args = parser.parse_args()

    if not args.all and args.node_id is None and args.remote_mac is None:
        args.all = True

    async with websockets.connect(args.ws_url) as ws:
        await ws.recv()  # server_info

        start = await _call(ws, "start", "start_listening")
        if "error_code" in start:
            details = start.get("details") or "unknown error"
            print(f"start_listening failed: {details}", file=sys.stderr)
            return 1

        nodes = start.get("result") or []
        node_by_id = {}
        target_node_id = args.node_id

        for node in nodes:
            node_id = node.get("node_id")
            attrs = node.get("attributes") or {}
            label = attrs.get("0/40/5") or ""
            product = attrs.get("0/40/3") or ""
            mac = _mac_from_attrs(attrs) or ""
            node_by_id[node_id] = {
                "label": label,
                "product": product,
                "mac": mac,
            }
            if target_node_id is None and not args.all and args.remote_mac and mac.lower() == args.remote_mac.lower():
                target_node_id = node_id

        if not args.all and target_node_id is None:
            print("target remote not found (use --all, --node-id, or --remote-mac)", file=sys.stderr)
            return 1

        if args.all:
            print("streaming all node_event messages", flush=True)
        else:
            meta = node_by_id.get(target_node_id, {})
            print(
                f"streaming node_event for node_id={target_node_id} label={meta.get('label', '')} mac={meta.get('mac', '')}",
                flush=True,
            )

        while True:
            message = json.loads(await ws.recv())
            if message.get("event") != "node_event":
                continue

            data = message.get("data") or {}
            node_id = data.get("node_id")
            if not args.all and node_id != target_node_id:
                continue

            if args.raw:
                print(json.dumps(message, sort_keys=True), flush=True)
                continue

            ts = datetime.now().isoformat(timespec="seconds")
            endpoint_id = data.get("endpoint_id")
            cluster_id = data.get("cluster_id")
            event_id = data.get("event_id")
            event_number = data.get("event_number")
            payload = data.get("data")
            meta = node_by_id.get(node_id, {})
            print(
                f"{ts} node={node_id} label={meta.get('label', '')} mac={meta.get('mac', '')} "
                f"ep={endpoint_id} cluster={cluster_id} event={event_id} event_no={event_number} payload={payload}",
                flush=True,
            )


if __name__ == "__main__":
    raise SystemExit(asyncio.run(_run()))
