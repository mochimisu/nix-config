#!/usr/bin/env python3
import asyncio
import base64
import json
import os
import sys
import time
from dataclasses import dataclass

import websockets

WS_URL_DEFAULT = "ws://127.0.0.1:5580/ws"
REMOTE_NODE_ID = int(os.getenv("MATTER_REMOTE_NODE_ID", "0"))
BLINDS_ENDPOINT = int(os.getenv("MATTER_BLINDS_ENDPOINT", "1"))
SWITCH_CLUSTER_ID = 59
WINDOW_COVERING_CLUSTER_ID = 258
SWITCH_EVENT_INITIAL_PRESS = 1
SWITCH_EVENT_MULTI_PRESS_COMPLETE = 6
ACTION_DEDUPE_WINDOW_SEC = float(os.getenv("MATTER_REMOTE_ACTION_DEDUPE_WINDOW_SEC", "0.8"))


@dataclass
class Binding:
    name: str
    remote_mac: str
    blinds_mac: str
    remote_node_id: int | None = None
    blinds_node_id: int | None = None
    current_direction: str = "idle"


def _env(value: str) -> str:
    return os.getenv(value, "").strip()


def _binding_specs() -> list[Binding]:
    # Keep compatibility with existing MATTER_REMOTE_MAC / MATTER_BLINDS_MAC.
    office_remote_mac = _env("MATTER_OFFICE_REMOTE_MAC") or _env("MATTER_REMOTE_MAC")
    office_blinds_mac = _env("MATTER_OFFICE_BLINDS_MAC") or _env("MATTER_BLINDS_MAC")
    nursery_remote_mac = _env("MATTER_NURSERY_REMOTE_MAC")
    nursery_blinds_mac = _env("MATTER_NURSERY_BLINDS_MAC")

    bindings: list[Binding] = []
    if office_remote_mac and office_blinds_mac:
        bindings.append(
            Binding(
                name="Office",
                remote_mac=office_remote_mac,
                blinds_mac=office_blinds_mac,
            )
        )
    if nursery_remote_mac and nursery_blinds_mac:
        bindings.append(
            Binding(
                name="Nursery",
                remote_mac=nursery_remote_mac,
                blinds_mac=nursery_blinds_mac,
            )
        )
    return bindings


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


async def _run() -> int:
    ws_url = os.getenv("MATTER_WS_URL", WS_URL_DEFAULT)
    bindings = _binding_specs()

    if not bindings:
        print(
            "no bindings configured; set MATTER_REMOTE_MAC/MATTER_BLINDS_MAC "
            "and/or MATTER_NURSERY_REMOTE_MAC/MATTER_NURSERY_BLINDS_MAC",
            file=sys.stderr,
        )
        return 1

    async with websockets.connect(ws_url) as ws:
        await ws.recv()  # server info frame

        start = await _call(ws, "start", "start_listening")
        if "error_code" in start:
            details = start.get("details") or "unknown error"
            print(f"start_listening failed: {details}", file=sys.stderr)
            return 1

        nodes = start.get("result") or []

        for node in nodes:
            node_id = node.get("node_id")
            if not isinstance(node_id, int) or node_id <= 0:
                continue
            attrs = node.get("attributes") or {}
            mac = _mac_from_attrs(attrs)
            if not mac:
                continue
            mac_lower = mac.lower()
            for binding in bindings:
                if mac_lower == binding.remote_mac.lower():
                    binding.remote_node_id = node_id
                if mac_lower == binding.blinds_mac.lower():
                    binding.blinds_node_id = node_id

        if REMOTE_NODE_ID > 0 and bindings:
            bindings[0].remote_node_id = REMOTE_NODE_ID

        missing = [
            binding
            for binding in bindings
            if binding.remote_node_id is None or binding.blinds_node_id is None
        ]
        if missing:
            for binding in missing:
                if binding.remote_node_id is None:
                    print(
                        f"{binding.name}: remote node not found by mac {binding.remote_mac}",
                        file=sys.stderr,
                    )
                if binding.blinds_node_id is None:
                    print(
                        f"{binding.name}: blinds node not found by mac {binding.blinds_mac}",
                        file=sys.stderr,
                    )
            return 1

        binding_summary = ", ".join(
            f"{binding.name}: remote={binding.remote_node_id} blinds={binding.blinds_node_id}"
            for binding in bindings
        )
        print(
            "listening for bindings: "
            f"{binding_summary}, trigger=initial_press fallback=multi_press_complete",
            flush=True,
        )

        binding_by_remote_node_id = {binding.remote_node_id: binding for binding in bindings}
        last_action_ts: dict[tuple[int, int], float] = {}

        while True:
            message = json.loads(await ws.recv())
            if message.get("event") != "node_event":
                continue

            data = message.get("data") or {}
            binding = binding_by_remote_node_id.get(data.get("node_id"))
            if binding is None:
                continue

            endpoint_id = data.get("endpoint_id")
            cluster_id = data.get("cluster_id")
            event_id = data.get("event_id")

            if cluster_id != SWITCH_CLUSTER_ID:
                continue

            if event_id == SWITCH_EVENT_INITIAL_PRESS:
                pass
            elif event_id == SWITCH_EVENT_MULTI_PRESS_COMPLETE:
                press_count = (data.get("data") or {}).get("totalNumberOfPressesCounted")
                if press_count != 1:
                    continue
            else:
                continue

            desired_direction = None
            if endpoint_id == 1:
                desired_direction = "up"
            elif endpoint_id == 2:
                desired_direction = "down"

            if desired_direction is None:
                continue

            action_key = (binding.remote_node_id, endpoint_id)
            now = time.monotonic()
            previous = last_action_ts.get(action_key)
            if previous is not None and (now - previous) < ACTION_DEDUPE_WINDOW_SEC:
                continue
            last_action_ts[action_key] = now

            try:
                if binding.current_direction == desired_direction:
                    await _device_command(
                        ws,
                        node_id=binding.blinds_node_id,
                        endpoint_id=BLINDS_ENDPOINT,
                        cluster_id=WINDOW_COVERING_CLUSTER_ID,
                        command_name="StopMotion",
                        payload={},
                    )
                    binding.current_direction = "idle"
                    print(
                        f"{binding.name} remote button {endpoint_id} event={event_id}: stop blinds",
                        flush=True,
                    )
                else:
                    command_name = "UpOrOpen" if desired_direction == "up" else "DownOrClose"
                    mode = "reverse" if binding.current_direction in ("up", "down") else "start"
                    await _device_command(
                        ws,
                        node_id=binding.blinds_node_id,
                        endpoint_id=BLINDS_ENDPOINT,
                        cluster_id=WINDOW_COVERING_CLUSTER_ID,
                        command_name=command_name,
                        payload={},
                    )
                    binding.current_direction = desired_direction
                    print(
                        f"{binding.name} remote button {endpoint_id} event={event_id}: {mode} {desired_direction}",
                        flush=True,
                    )
            except Exception as err:
                print(f"command failed: {err}", file=sys.stderr, flush=True)


async def main() -> int:
    while True:
        try:
            return await _run()
        except Exception as err:
            print(f"listener error: {err}", file=sys.stderr, flush=True)
            await asyncio.sleep(3)


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
