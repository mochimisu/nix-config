#!/usr/bin/env python3
import argparse
import asyncio
import base64
import json
import os
import shutil
import sys
from datetime import datetime

import websockets

WS_URL_DEFAULT = "ws://127.0.0.1:5580/ws"

GREEN = "\033[32m"
RED = "\033[31m"
RESET = "\033[0m"


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


def _clear() -> None:
    print("\033[2J\033[H", end="")


def _fmt_state(available: bool, color: bool) -> str:
    text = "CONNECTED" if available else "DISCONNECTED"
    if not color:
        return text
    return f"{GREEN}{text}{RESET}" if available else f"{RED}{text}{RESET}"


async def _poll(ws_url: str) -> list[dict]:
    async with websockets.connect(ws_url) as ws:
        await ws.recv()  # server_info
        start = await _call(ws, "start", "start_listening")
        if "error_code" in start:
            details = start.get("details") or "unknown error"
            raise RuntimeError(f"start_listening failed: {details}")
        return start.get("result") or []


def _print_table(nodes: list[dict], color: bool, ws_url: str, interval: float) -> None:
    width = shutil.get_terminal_size((120, 40)).columns
    now = datetime.now().isoformat(timespec="seconds")
    _clear()
    print(f"Matter device connectivity  ({now})")
    print(f"WS: {ws_url}")
    print(f"Polling every {interval:.1f}s. Press Ctrl+C to stop.")
    print("-" * min(width, 140))
    print(f"{'Node':<6}  {'State':<12}  {'Label':<24}  {'MAC':<17}  Device")
    print(f"{'----':<6}  {'-----':<12}  {'-----':<24}  {'---':<17}  ------")

    for node in sorted(nodes, key=lambda n: n.get("node_id", 0)):
        node_id = node.get("node_id")
        available = bool(node.get("available"))
        attrs = node.get("attributes") or {}
        label = attrs.get("0/40/5") or "(no label)"
        vendor = attrs.get("0/40/1") or ""
        product = attrs.get("0/40/3") or ""
        mac = _mac_from_attrs(attrs) or ""
        state = _fmt_state(available, color)
        device = f"{vendor} {product}".strip()
        print(f"{str(node_id):<6}  {state:<12}  {label[:24]:<24}  {mac:<17}  {device}")


async def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--ws-url", default=os.getenv("MATTER_WS_URL", WS_URL_DEFAULT))
    parser.add_argument("--interval", type=float, default=2.0)
    parser.add_argument("--no-color", action="store_true")
    args = parser.parse_args()

    use_color = (not args.no_color) and sys.stdout.isatty()

    while True:
        try:
            nodes = await _poll(args.ws_url)
            _print_table(nodes, use_color, args.ws_url, args.interval)
        except Exception as err:
            _clear()
            print(f"Matter watch error: {err}", file=sys.stderr)

        await asyncio.sleep(args.interval)


if __name__ == "__main__":
    try:
        raise SystemExit(asyncio.run(main()))
    except KeyboardInterrupt:
        print("\nstopped")
        raise SystemExit(0)
