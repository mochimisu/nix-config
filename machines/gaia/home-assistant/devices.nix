{config, pkgs, matterNodeLabels ? {}, ...}: let
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

        async with websockets.connect(args.ws_url) as ws:
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

        async with websockets.connect(args.matter_ws_url) as matter_ws:
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

        async with websockets.connect(args.ha_ws_url) as ha_ws:
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
in {
  environment.systemPackages = [
    matterNodeLabelsTool
    matterHaNamerTool
  ];

  systemd.services.matter-apply-node-labels = {
    description = "Apply Matter NodeLabel overrides (Nix-defined)";
    after = [
      "podman-matter-server.service"
      "network-online.target"
    ];
    wants = [
      "podman-matter-server.service"
      "network-online.target"
    ];
    serviceConfig = {
      Type = "oneshot";
      EnvironmentFile = config.sops.secrets."matter-env".path;
      ExecStartPre = "${pkgs.bash}/bin/bash -c 'for i in {1..60}; do (echo > /dev/tcp/127.0.0.1/5580) >/dev/null 2>&1 && exit 0; sleep 1; done; echo matter-server ws not ready >&2; exit 1'";
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
      "podman-matter-server.service"
      "network-online.target"
    ];
    wants = [
      "home-assistant.service"
      "podman-matter-server.service"
      "network-online.target"
    ];
    serviceConfig = {
      Type = "oneshot";
      EnvironmentFile = config.sops.secrets."matter-env".path;
      ExecStartPre = "${pkgs.bash}/bin/bash -c 'for i in {1..60}; do (echo > /dev/tcp/127.0.0.1/8123) >/dev/null 2>&1 && (echo > /dev/tcp/127.0.0.1/5580) >/dev/null 2>&1 && exit 0; sleep 1; done; echo HA or matter ws not ready >&2; exit 1'";
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
}
