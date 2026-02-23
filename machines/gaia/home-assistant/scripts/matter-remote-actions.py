#!/usr/bin/env python3
import asyncio
import base64
import json
import os
import sys

import websockets

WS_URL_DEFAULT = "ws://127.0.0.1:5580/ws"
REMOTE_MAC = os.getenv("MATTER_REMOTE_MAC", "")
REMOTE_NODE_ID = int(os.getenv("MATTER_REMOTE_NODE_ID", "0"))
BLINDS_MAC = os.getenv("MATTER_BLINDS_MAC", "")
BLINDS_ENDPOINT = int(os.getenv("MATTER_BLINDS_ENDPOINT", "1"))
KEEPALIVE_NODE_IDS_ENV = os.getenv("MATTER_KEEPALIVE_NODE_IDS", "")
KEEPALIVE_INTERVAL_SEC = int(os.getenv("MATTER_KEEPALIVE_INTERVAL_SEC", "30"))
SWITCH_CLUSTER_ID = 59
WINDOW_COVERING_CLUSTER_ID = 258
SWITCH_EVENT_MULTI_PRESS_COMPLETE = 6


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


async def _keepalive_once(ws_url: str, node_ids: set[int]) -> None:
    if not node_ids:
        return

    async with websockets.connect(ws_url) as ws:
        await ws.recv()  # server info frame
        for node_id in sorted(node_ids):
            response = await _call(
                ws,
                f"keepalive:{node_id}",
                "read_attribute",
                {
                    "node_id": node_id,
                    "attribute_path": "0/40/5",  # BasicInformation.NodeLabel
                },
            )
            if "error_code" in response:
                details = response.get("details") or "unknown error"
                print(
                    f"keepalive node_id={node_id} failed: {details}",
                    file=sys.stderr,
                    flush=True,
                )


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
            f"keepalive_nodes={sorted(keepalive_node_ids)} interval={KEEPALIVE_INTERVAL_SEC}s",
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
