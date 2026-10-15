import argparse
import asyncio
import base64
import json
import os
import sys

import websockets

MATTER_WS_URL_DEFAULT = "ws://127.0.0.1:5580/ws"
HA_WS_URL_DEFAULT = "ws://127.0.0.1:8123/api/websocket"

def _b64_to_bytes(s: str) -> bytes | None:
    try:
        return base64.b64decode(s + "===")
    except Exception:
        return None

def _mac_from_node(attrs: dict) -> str | None:
    for entry in (attrs.get("0/51/0") or []):
        hw = entry.get("4")
        if isinstance(hw, str) and hw:
            b = _b64_to_bytes(hw)
            if b and len(b) >= 6:
                return ":".join(f"{x:02x}" for x in b[:6])
    return None

async def _matter_call(ws, message_id: str, command: str, args: dict | None = None) -> dict:
    payload = {"message_id": message_id, "command": command, "args": args or {}}
    await ws.send(json.dumps(payload))
    while True:
        raw = await ws.recv()
        msg = json.loads(raw)
        if msg.get("message_id") == message_id:
            return msg

async def _ha_call(ws, req_id: int, msg_type: str, **kwargs) -> dict:
    payload = {"id": req_id, "type": msg_type, **kwargs}
    await ws.send(json.dumps(payload))
    while True:
        raw = await ws.recv()
        msg = json.loads(raw)
        if msg.get("id") == req_id:
            return msg

def _desired_label_for_node(attrs: dict, labels: dict) -> tuple[str | None, str | None]:
    unique_id = attrs.get("0/40/18")
    serial = attrs.get("0/40/15")
    mac = _mac_from_node(attrs)
    candidates = []
    if isinstance(unique_id, str) and unique_id:
        candidates.append(f"unique_id:{unique_id}")
    if isinstance(serial, str) and serial:
        candidates.append(f"serial:{serial}")
    if mac:
        candidates.append(f"mac:{mac}")
    for key in candidates:
        label = labels.get(key)
        if isinstance(label, str) and label:
            return key, label
    return None, None

def _expand_labels(raw: dict) -> dict:
    out = {}
    for key, label in raw.items():
        if not isinstance(key, str) or not isinstance(label, str) or not label:
            continue
        if key.startswith("unique_id_env:"):
            env_name = key.split(":", 1)[1].strip()
            if not env_name:
                continue
            unique_id = (os.getenv(env_name, "") or "").strip()
            if not unique_id:
                continue
            out[f"unique_id:{unique_id}"] = label
            continue
        if key.startswith("serial_env:"):
            env_name = key.split(":", 1)[1].strip()
            if not env_name:
                continue
            serial = (os.getenv(env_name, "") or "").strip()
            if not serial:
                continue
            out[f"serial:{serial}"] = label
            continue
        if key.startswith("mac_env:"):
            env_name = key.split(":", 1)[1].strip()
            if not env_name:
                continue
            mac = (os.getenv(env_name, "") or "").strip().lower()
            if not mac:
                continue
            out[f"mac:{mac}"] = label
            continue
        out[key] = label
    return out

def _device_matches_node(device: dict, node_id: int, attrs: dict) -> bool:
    node_hex = f"{node_id:016X}"
    identifiers = device.get("identifiers") or []
    matter_ident_values = []
    for item in identifiers:
        if isinstance(item, (list, tuple)) and len(item) >= 2 and item[0] == "matter":
            matter_ident_values.append(str(item[1]))

    if any(f"-{node_hex}-MatterNodeDevice" in val for val in matter_ident_values):
        return True

    serial = attrs.get("0/40/15")
    if isinstance(serial, str) and serial and any(val == f"serial_{serial}" for val in matter_ident_values):
        return True

    mac = _mac_from_node(attrs)
    if mac:
        for conn in (device.get("connections") or []):
            if isinstance(conn, (list, tuple)) and len(conn) >= 2:
                if str(conn[0]).lower() == "mac" and str(conn[1]).lower() == mac.lower():
                    return True
    return False

async def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--matter-ws-url", default=os.getenv("MATTER_WS_URL", MATTER_WS_URL_DEFAULT))
    ap.add_argument("--ha-ws-url", default=os.getenv("HA_WS_URL", HA_WS_URL_DEFAULT))
    ap.add_argument("--labels-json", default=os.getenv("MATTER_NODE_LABELS_JSON", "{}"))
    ap.add_argument("--ha-token", default=os.getenv("MATTER_HA_TOKEN", ""))
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    if not args.ha_token:
        print("matter-ha-namer: MATTER_HA_TOKEN not set; skipping")
        return 0

    try:
        labels = json.loads(args.labels_json)
    except Exception as err:
        print(f"Invalid MATTER_NODE_LABELS_JSON: {err}", file=sys.stderr)
        return 2
    labels = _expand_labels(labels if isinstance(labels, dict) else {})

    async with websockets.connect(args.matter_ws_url, max_size=None) as matter_ws:
        await matter_ws.recv()  # server_info
        nodes_resp = await _matter_call(matter_ws, "ha-name-nodes", "start_listening")
        nodes = nodes_resp.get("result") or []

    desired_nodes = []
    for node in nodes:
        node_id = node.get("node_id")
        if not isinstance(node_id, int):
            continue
        attrs = node.get("attributes") or {}
        key, desired = _desired_label_for_node(attrs, labels)
        if not desired:
            continue
        desired_nodes.append({
            "node_id": node_id,
            "attrs": attrs,
            "match_key": key,
            "desired_name": desired,
        })

    if not desired_nodes:
        print("matter-ha-namer: no matching labeled Matter nodes found")
        return 0

    async with websockets.connect(args.ha_ws_url, max_size=None) as ha_ws:
        first = json.loads(await ha_ws.recv())
        if first.get("type") != "auth_required":
            print(f"matter-ha-namer: unexpected HA websocket greeting: {first}", file=sys.stderr)
            return 2
        await ha_ws.send(json.dumps({"type": "auth", "access_token": args.ha_token}))
        auth = json.loads(await ha_ws.recv())
        if auth.get("type") != "auth_ok":
            print("matter-ha-namer: HA auth failed", file=sys.stderr)
            return 2

        devices_resp = await _ha_call(ha_ws, 1, "config/device_registry/list")
        if not devices_resp.get("success"):
            print(f"matter-ha-namer: failed to list HA devices: {devices_resp}", file=sys.stderr)
            return 2
        devices = devices_resp.get("result") or []

        changed = 0
        for node in desired_nodes:
            node_id = node["node_id"]
            attrs = node["attrs"]
            desired_name = node["desired_name"]
            match_key = node["match_key"]

            matched = [d for d in devices if _device_matches_node(d, node_id, attrs)]
            if not matched:
                print(f"warn: no HA device found for node_id={node_id} ({match_key})", file=sys.stderr)
                continue

            device = matched[0]
            current_name = device.get("name_by_user") or ""
            if current_name == desired_name:
                continue

            if args.dry_run:
                print(f"would set ha device_id={device.get('id')} node_id={node_id} name={desired_name!r}")
                changed += 1
                continue

            update_resp = await _ha_call(
                ha_ws,
                1000 + node_id,
                "config/device_registry/update",
                device_id=device.get("id"),
                name_by_user=desired_name,
            )
            if update_resp.get("success"):
                print(f"set ha device_id={device.get('id')} node_id={node_id} name={desired_name!r}")
                changed += 1
            else:
                print(
                    f"failed to set ha name for node_id={node_id}: {update_resp.get('error')}",
                    file=sys.stderr,
                )

        print(f"matter-ha-namer: updated={changed}")
    return 0

if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
