{config, pkgs, lib, matterNodeLabels ? {}, ...}: let
  # Prefer setting the Matter device's own NodeLabel (0/40/5) so names survive
  # HA state wipes and re-pairing. Entity_id-based HA customizations are fragile.

  # Disambiguation strategy for multiple devices:
  # - Prefer BasicInfo UniqueID (0/40/18) when present: `unique_id:<value>`
  # - Else SerialNumber (0/40/15): `serial:<value>`
  # - Else MAC from GeneralDiagnostics NetworkInterfaces (0/51/0 field 4): `mac:<aa:bb:cc:dd:ee:ff>`
  #
  # Source of truth is in pairings.nix via _module.args.matterNodeLabels.
  # You can discover candidate keys with `matter-node-labels --list`.

  matterNodeLabelsJson = builtins.toJSON matterNodeLabels;
  matterServerUnit = "podman-matter-server.service";
  matterWsPort = "5580";
  matterWsUrl = "ws://127.0.0.1:${matterWsPort}/ws";

  pythonEnv = pkgs.python3.withPackages (ps: [
    ps.websockets
  ]);

  matterLabeler = pkgs.writeText "matter-node-labels.py" ''
    import argparse
    import asyncio
    import base64
    import json
    import os
    import sys

    import websockets

    WS_URL_DEFAULT = "ws://127.0.0.1:5580/ws"

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

    def _b64_to_bytes(s: str) -> bytes | None:
        # Matter server returns some values base64-encoded.
        try:
            return base64.b64decode(s + "===")
        except Exception:
            return None

    def _mac_from_node(attrs: dict) -> str | None:
        # GeneralDiagnostics.NetworkInterfaces (0/51/0) contains a list of structs.
        # Field "4" is the hardware address (base64-encoded bytes) when present.
        for entry in (attrs.get("0/51/0") or []):
            hw = entry.get("4")
            if isinstance(hw, str) and hw:
                b = _b64_to_bytes(hw)
                if b and len(b) >= 6:
                    return ":".join(f"{x:02x}" for x in b[:6])
        return None

    def _node_key(attrs: dict) -> str | None:
        uid = attrs.get("0/40/18")
        if isinstance(uid, str) and uid:
            return f"unique_id:{uid}"
        serial = attrs.get("0/40/15")
        if isinstance(serial, str) and serial:
            return f"serial:{serial}"
        mac = _mac_from_node(attrs)
        if mac:
            return f"mac:{mac}"
        return None

    async def _call(ws, message_id: str, command: str, args: dict | None = None) -> dict:
        payload = {"message_id": message_id, "command": command, "args": args or {}}
        await ws.send(json.dumps(payload))
        while True:
            raw = await ws.recv()
            msg = json.loads(raw)
            if msg.get("message_id") == message_id:
                return msg

    async def main() -> int:
        ap = argparse.ArgumentParser()
        ap.add_argument("--ws-url", default=os.getenv("MATTER_WS_URL", WS_URL_DEFAULT))
        ap.add_argument("--labels-json", default=os.getenv("MATTER_NODE_LABELS_JSON", "{}"))
        ap.add_argument("--list", action="store_true", help="List discovered nodes and computed stable keys.")
        args = ap.parse_args()

        try:
            labels = json.loads(args.labels_json)
        except Exception as e:
            print(f"Invalid MATTER_NODE_LABELS_JSON: {e}", file=sys.stderr)
            return 2
        labels = _expand_labels(labels if isinstance(labels, dict) else {})

        async with websockets.connect(args.ws_url, max_size=None) as ws:
            # Server sends a server_info object immediately after connect.
            await ws.recv()

            nodes_resp = await _call(ws, "1", "start_listening")
            nodes = nodes_resp.get("result") or []

            if args.list:
                for n in nodes:
                    attrs = n.get("attributes") or {}
                    vendor = attrs.get("0/40/1")
                    product = attrs.get("0/40/3")
                    node_label = attrs.get("0/40/5") or ""
                    key = _node_key(attrs)
                    print(
                        f"node_id={n.get('node_id')} key={key!r} vendor={vendor!r} product={product!r} label={node_label!r}"
                    )
                return 0

            # Apply desired labels.
            changed = 0
            missing = []
            for n in nodes:
                node_id = n.get("node_id")
                attrs = n.get("attributes") or {}
                key = _node_key(attrs)
                if not key:
                    continue
                desired = labels.get(key)
                if not desired:
                    continue
                current = attrs.get("0/40/5") or ""
                if current == desired:
                    continue

                resp = await _call(
                    ws,
                    f"write:{node_id}",
                    "write_attribute",
                    {"node_id": node_id, "attribute_path": "0/40/5", "value": desired},
                )
                # Expect a list of status entries; Status==0 indicates success.
                result = resp.get("result")
                ok = False
                if isinstance(result, list) and result:
                    ok = (result[0].get("Status") == 0)
                if ok:
                    print(f"set node_id={node_id} ({key}) label={desired!r}")
                    changed += 1
                else:
                    print(f"failed node_id={node_id} ({key}) resp={resp}", file=sys.stderr)

            # Optional: warn about label keys that weren't found this run.
            keys_seen = {_node_key((n.get('attributes') or {})) for n in nodes}
            for k in labels.keys():
                if k not in keys_seen:
                    missing.append(k)
            for k in missing:
                print(f"warn: desired label key not found this run: {k}", file=sys.stderr)

            if changed:
                return 0
            return 0

    if __name__ == "__main__":
        raise SystemExit(asyncio.run(main()))
  '';

  matterHaNamer = pkgs.writeText "matter-ha-namer.py" ''
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
  '';

  matterHaCleanup = pkgs.writeText "matter-ha-matter-cleanup.py" ''
    import argparse
    import asyncio
    import base64
    import json
    import os
    import re
    import sys

    import websockets

    MATTER_WS_URL_DEFAULT = "ws://127.0.0.1:5580/ws"
    HA_WS_URL_DEFAULT = "ws://127.0.0.1:8123/api/websocket"
    MATTER_NODE_RE = re.compile(r"-([0-9A-Fa-f]{16})-MatterNodeDevice")
    NUMBERED_NAME_RE = re.compile(r"^(?P<base>.+) \([0-9]+\)$")
    ROLE_SUFFIX_RE = re.compile(r" \((Load Control|RGB Indicator)\)$")
    DEAD_STATES = {"unavailable", "unknown"}

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
            msg = json.loads(await ws.recv())
            if msg.get("message_id") == message_id:
                return msg

    async def _ha_call(ws, req_id: int, msg_type: str, **kwargs) -> dict:
        payload = {"id": req_id, "type": msg_type, **kwargs}
        await ws.send(json.dumps(payload))
        while True:
            msg = json.loads(await ws.recv())
            if msg.get("id") == req_id:
                return msg

    def _matter_identifier_values(device: dict) -> list[str]:
        out = []
        for item in device.get("identifiers") or []:
            if isinstance(item, (list, tuple)) and len(item) >= 2 and item[0] == "matter":
                out.append(str(item[1]))
        return out

    def _device_node_ids(device: dict) -> set[int]:
        out = set()
        for value in _matter_identifier_values(device):
            for match in MATTER_NODE_RE.finditer(value):
                out.add(int(match.group(1), 16))
        return out

    def _has_matter_identity(device: dict) -> bool:
        return bool(_matter_identifier_values(device))

    def _device_matches_node(device: dict, node: dict) -> bool:
        node_id = node.get("node_id")
        attrs = node.get("attributes") or {}
        if isinstance(node_id, int) and node_id in _device_node_ids(device):
            return True

        identifiers = _matter_identifier_values(device)
        serial = attrs.get("0/40/15")
        if isinstance(serial, str) and serial and f"serial_{serial}" in identifiers:
            return True

        mac = _mac_from_node(attrs)
        if mac:
            for conn in device.get("connections") or []:
                if isinstance(conn, (list, tuple)) and len(conn) >= 2:
                    if str(conn[0]).lower() == "mac" and str(conn[1]).lower() == mac.lower():
                        return True
        return False

    def _state_map(states: list[dict]) -> dict[str, dict]:
        return {
            str(state.get("entity_id")): state
            for state in states
            if state.get("entity_id")
        }

    def _state_value(states: dict[str, dict], entity_id: str) -> str:
        state = states.get(entity_id) or {}
        return str(state.get("state", "unknown"))

    def _entity_domain(entity_id: str) -> str:
        return entity_id.split(".", 1)[0] if "." in entity_id else ""

    def _entity_name(entity: dict, states: dict[str, dict]) -> str:
        entity_id = entity.get("entity_id") or ""
        state = states.get(entity_id) or {}
        attrs = state.get("attributes") or {}
        for value in (
            attrs.get("friendly_name"),
            entity.get("name"),
            entity.get("original_name"),
        ):
            if isinstance(value, str) and value:
                return value
        return entity_id

    def _device_class(entity: dict, states: dict[str, dict]) -> str:
        entity_id = entity.get("entity_id") or ""
        state = states.get(entity_id) or {}
        attrs = state.get("attributes") or {}
        value = attrs.get("device_class") or entity.get("device_class") or ""
        return str(value)

    def _unit(entity: dict, states: dict[str, dict]) -> str:
        entity_id = entity.get("entity_id") or ""
        state = states.get(entity_id) or {}
        attrs = state.get("attributes") or {}
        value = attrs.get("unit_of_measurement") or ""
        return str(value)

    def _same_measurement(a: dict, b: dict, states: dict[str, dict]) -> bool:
        a_class = _device_class(a, states)
        b_class = _device_class(b, states)
        if a_class and b_class and a_class != b_class:
            return False
        a_unit = _unit(a, states)
        b_unit = _unit(b, states)
        if a_unit and b_unit and a_unit != b_unit:
            return False
        return True

    def _duplicate_entity_reason(candidate: dict, live_entities: list[dict], states: dict[str, dict]) -> str | None:
        entity_id = candidate.get("entity_id") or ""
        if not entity_id or _state_value(states, entity_id) not in DEAD_STATES:
            return None

        domain = _entity_domain(entity_id)
        name = _entity_name(candidate, states)
        numbered = NUMBERED_NAME_RE.match(name)
        base_name = numbered.group("base") if numbered else None

        for live in live_entities:
            live_id = live.get("entity_id") or ""
            if not live_id or live_id == entity_id:
                continue
            if _entity_domain(live_id) != domain:
                continue
            if _state_value(states, live_id) in DEAD_STATES:
                continue
            if not _same_measurement(candidate, live, states):
                continue

            live_name = _entity_name(live, states)
            if live_name == name:
                return "same-name live Matter entity exists"

            if base_name:
                live_base = ROLE_SUFFIX_RE.sub("", live_name)
                if live_base == base_name:
                    return "numbered stale Matter entity has live role entity"

        return None

    def _entity_debug_line(entity: dict, states: dict[str, dict]) -> str:
        entity_id = entity.get("entity_id") or ""
        state = states.get(entity_id) or {}
        attrs = state.get("attributes") or {}
        fields = {
            "entity_id": entity_id,
            "state": _state_value(states, entity_id),
            "name": _entity_name(entity, states),
            "original_name": entity.get("original_name") or "",
            "unique_id": entity.get("unique_id") or "",
            "disabled_by": entity.get("disabled_by") or "",
            "hidden_by": entity.get("hidden_by") or "",
            "domain": _entity_domain(entity_id),
            "device_class": _device_class(entity, states),
            "unit": _unit(entity, states),
            "friendly_name": attrs.get("friendly_name") or "",
        }
        return " ".join(f"{key}={json.dumps(value, sort_keys=True)}" for key, value in fields.items())

    def _stale_reason(device: dict, entities: list[dict], states: dict[str, dict], nodes: list[dict]) -> str | None:
        if not _has_matter_identity(device):
            return None

        explicit_node_ids = _device_node_ids(device)
        live_node_ids = {node.get("node_id") for node in nodes if isinstance(node.get("node_id"), int)}
        if explicit_node_ids and explicit_node_ids.isdisjoint(live_node_ids):
            return "matter node id is not commissioned"

        if any(_device_matches_node(device, node) for node in nodes):
            return None

        # For serial-only or MAC-only HA Matter devices, require that HA has no
        # currently usable entities before treating the unmatched device as stale.
        if not entities:
            return "matter identity has no matching commissioned node and no entities"

        entity_states = [_state_value(states, entity.get("entity_id", "")) for entity in entities]
        if all(state in DEAD_STATES for state in entity_states):
            return "matter identity has no matching commissioned node and all entities are unavailable"
        return None

    async def main() -> int:
        ap = argparse.ArgumentParser()
        ap.add_argument("--matter-ws-url", default=os.getenv("MATTER_WS_URL", MATTER_WS_URL_DEFAULT))
        ap.add_argument("--ha-ws-url", default=os.getenv("HA_WS_URL", HA_WS_URL_DEFAULT))
        ap.add_argument("--ha-token", default=os.getenv("MATTER_HA_TOKEN", ""))
        ap.add_argument("--dry-run", action="store_true")
        ap.add_argument("--inspect", default="", help="Print Matter HA registry devices/entities whose names contain this text.")
        args = ap.parse_args()

        if not args.ha_token:
            print("matter-ha-matter-cleanup: MATTER_HA_TOKEN not set; skipping")
            return 0

        async with websockets.connect(args.matter_ws_url, max_size=None) as matter_ws:
            await matter_ws.recv()
            nodes_resp = await _matter_call(matter_ws, "cleanup-list-nodes", "start_listening")
            if "error_code" in nodes_resp:
                print(f"matter start_listening failed: {nodes_resp}", file=sys.stderr)
                return 2
            nodes = nodes_resp.get("result") or []

        async with websockets.connect(args.ha_ws_url, max_size=None) as ha_ws:
            first = json.loads(await ha_ws.recv())
            if first.get("type") != "auth_required":
                print(f"unexpected HA websocket greeting: {first}", file=sys.stderr)
                return 2
            await ha_ws.send(json.dumps({"type": "auth", "access_token": args.ha_token}))
            auth = json.loads(await ha_ws.recv())
            if auth.get("type") != "auth_ok":
                print("HA auth failed", file=sys.stderr)
                return 2

            devices_resp = await _ha_call(ha_ws, 1, "config/device_registry/list")
            entities_resp = await _ha_call(ha_ws, 2, "config/entity_registry/list")
            states_resp = await _ha_call(ha_ws, 3, "get_states")
            if not devices_resp.get("success") or not entities_resp.get("success") or not states_resp.get("success"):
                print("failed to read HA registries/states", file=sys.stderr)
                return 2

            devices = devices_resp.get("result") or []
            entities = entities_resp.get("result") or []
            states = _state_map(states_resp.get("result") or [])

            entities_by_device: dict[str, list[dict]] = {}
            for entity in entities:
                device_id = entity.get("device_id")
                if isinstance(device_id, str) and device_id:
                    entities_by_device.setdefault(device_id, []).append(entity)

            if args.inspect:
                needle = args.inspect.lower()
                for device in devices:
                    if not _has_matter_identity(device):
                        continue
                    device_entities = entities_by_device.get(device.get("id"), [])
                    names = [
                        str(device.get("name_by_user") or ""),
                        str(device.get("name") or ""),
                        str(device.get("original_name") or ""),
                    ] + [_entity_name(entity, states) for entity in device_entities]
                    if not any(needle in name.lower() for name in names):
                        continue
                    print(
                        "inspect device="
                        f"{device.get('id')} name={json.dumps(device.get('name_by_user') or device.get('name') or "")} "
                        f"original_name={json.dumps(device.get('original_name') or "")} "
                        f"identifiers={json.dumps(_matter_identifier_values(device), sort_keys=True)}"
                    )
                    for entity in sorted(device_entities, key=lambda item: item.get("entity_id") or ""):
                        print(f"  inspect entity {_entity_debug_line(entity, states)}")
                return 0

            stale = []
            for device in devices:
                reason = _stale_reason(device, entities_by_device.get(device.get("id"), []), states, nodes)
                if reason:
                    stale.append((device, reason))

            if not stale:
                print("matter-ha-matter-cleanup: no stale Matter HA devices found")

            removed_entities = 0
            removed_devices = 0
            req_id = 100
            for device, reason in stale:
                device_id = device.get("id")
                name = device.get("name_by_user") or device.get("name") or device_id
                device_entities = entities_by_device.get(device_id, [])
                print(f"{'would remove' if args.dry_run else 'remove'} device={device_id} name={name!r}: {reason}")

                for entity in device_entities:
                    entity_id = entity.get("entity_id")
                    if not entity_id:
                        continue
                    print(f"  {'would remove' if args.dry_run else 'remove'} entity={entity_id}")
                    if args.dry_run:
                        removed_entities += 1
                        continue
                    req_id += 1
                    resp = await _ha_call(ha_ws, req_id, "config/entity_registry/remove", entity_id=entity_id)
                    if resp.get("success"):
                        removed_entities += 1
                    else:
                        print(f"  failed entity={entity_id}: {resp.get('error')}", file=sys.stderr)

                if args.dry_run:
                    removed_devices += 1
                    continue
                req_id += 1
                resp = await _ha_call(ha_ws, req_id, "config/device_registry/remove", device_id=device_id)
                if resp.get("success"):
                    removed_devices += 1
                else:
                    print(f"  failed device={device_id}: {resp.get('error')}", file=sys.stderr)

            live_entities = [
                entity
                for entity in entities
                if _state_value(states, entity.get("entity_id", "")) not in DEAD_STATES
            ]
            stale_device_ids = {device.get("id") for device, _ in stale}
            matter_device_ids = {
                device.get("id")
                for device in devices
                if _has_matter_identity(device) and device.get("id") not in stale_device_ids
            }

            duplicate_entities = []
            for entity in entities:
                device_id = entity.get("device_id")
                if device_id not in matter_device_ids:
                    continue
                reason = _duplicate_entity_reason(entity, live_entities, states)
                if reason:
                    duplicate_entities.append((entity, reason))

            for entity, reason in duplicate_entities:
                entity_id = entity.get("entity_id")
                if not entity_id:
                    continue
                print(f"{'would remove' if args.dry_run else 'remove'} duplicate entity={entity_id}: {reason}")
                if args.dry_run:
                    removed_entities += 1
                    continue
                req_id += 1
                resp = await _ha_call(ha_ws, req_id, "config/entity_registry/remove", entity_id=entity_id)
                if resp.get("success"):
                    removed_entities += 1
                else:
                    print(f"failed duplicate entity={entity_id}: {resp.get('error')}", file=sys.stderr)

            if not stale and not duplicate_entities:
                print("matter-ha-matter-cleanup: no stale Matter HA devices or duplicate entities found")

            print(f"matter-ha-matter-cleanup: devices={removed_devices} entities={removed_entities} dry_run={args.dry_run}")
        return 0

    if __name__ == "__main__":
        raise SystemExit(asyncio.run(main()))
  '';

  matterNodeLabelsTool = pkgs.writeShellApplication {
    name = "matter-node-labels";
    runtimeInputs = [ pythonEnv ];
    text = ''
      export MATTER_NODE_LABELS_JSON='${matterNodeLabelsJson}'
      exec ${pythonEnv}/bin/python3 ${matterLabeler} "$@"
    '';
  };

  matterHaNamerTool = pkgs.writeShellApplication {
    name = "matter-ha-namer";
    runtimeInputs = [ pythonEnv ];
    text = ''
      export MATTER_NODE_LABELS_JSON='${matterNodeLabelsJson}'
      exec ${pythonEnv}/bin/python3 ${matterHaNamer} "$@"
    '';
  };

  matterHaCleanupTool = pkgs.writeShellApplication {
    name = "matter-ha-matter-cleanup";
    runtimeInputs = [ pythonEnv ];
    text = ''
      exec ${pythonEnv}/bin/python3 ${matterHaCleanup} "$@"
    '';
  };
in {
  environment.systemPackages = [
    matterNodeLabelsTool
    matterHaNamerTool
    matterHaCleanupTool
  ];

  systemd.services.matter-apply-node-labels = {
    description = "Apply Matter NodeLabel overrides (Nix-defined)";
    after = [
      matterServerUnit
      "network-online.target"
    ];
    wants = [
      matterServerUnit
      "network-online.target"
    ];
    serviceConfig = {
      Type = "oneshot";
      EnvironmentFile = config.sops.secrets."matter-env".path;
      Environment = [
        "MATTER_WS_URL=${matterWsUrl}"
      ];
      ExecStartPre = "${pkgs.bash}/bin/bash -c 'for i in {1..60}; do (echo > /dev/tcp/127.0.0.1/${matterWsPort}) >/dev/null 2>&1 && exit 0; sleep 1; done; echo matter-server ws not ready >&2; exit 1'";
      ExecStart = "${matterNodeLabelsTool}/bin/matter-node-labels";
    };
  };

  # Devices may come online after boot; retry periodically.
  systemd.timers.matter-apply-node-labels = {
    wantedBy = [
      "timers.target"
    ];
    timerConfig = {
      OnBootSec = "2min";
      OnUnitInactiveSec = "1h";
      Unit = "matter-apply-node-labels.service";
    };
  };

  systemd.services.matter-apply-ha-names = {
    description = "Apply Home Assistant device names from Matter labels";
    after = [
      "home-assistant.service"
      matterServerUnit
      "network-online.target"
    ];
    wants = [
      "home-assistant.service"
      matterServerUnit
      "network-online.target"
    ];
    serviceConfig = {
      Type = "oneshot";
      EnvironmentFile = config.sops.secrets."matter-env".path;
      Environment = [
        "MATTER_WS_URL=${matterWsUrl}"
      ];
      ExecStartPre = "${pkgs.bash}/bin/bash -c 'for i in {1..60}; do (echo > /dev/tcp/127.0.0.1/8123) >/dev/null 2>&1 && (echo > /dev/tcp/127.0.0.1/${matterWsPort}) >/dev/null 2>&1 && exit 0; sleep 1; done; echo HA or matter ws not ready >&2; exit 1'";
      ExecStart = "${matterHaNamerTool}/bin/matter-ha-namer";
    };
  };

  systemd.timers.matter-apply-ha-names = {
    wantedBy = [
      "timers.target"
    ];
    timerConfig = {
      OnBootSec = "4min";
      OnUnitInactiveSec = "1h";
      Unit = "matter-apply-ha-names.service";
    };
  };

  systemd.services.matter-ha-matter-cleanup = {
    description = "Remove stale Home Assistant Matter devices";
    after = [
      "home-assistant.service"
      matterServerUnit
      "network-online.target"
    ];
    wants = [
      "home-assistant.service"
      matterServerUnit
      "network-online.target"
    ];
    serviceConfig = {
      Type = "oneshot";
      EnvironmentFile = config.sops.secrets."matter-env".path;
      Environment = [
        "MATTER_WS_URL=${matterWsUrl}"
      ];
      ExecStartPre = "${pkgs.bash}/bin/bash -c 'for i in {1..60}; do (echo > /dev/tcp/127.0.0.1/8123) >/dev/null 2>&1 && (echo > /dev/tcp/127.0.0.1/${matterWsPort}) >/dev/null 2>&1 && exit 0; sleep 1; done; echo HA or matter ws not ready >&2; exit 1'";
      ExecStart = "${matterHaCleanupTool}/bin/matter-ha-matter-cleanup";
    };
  };
}
