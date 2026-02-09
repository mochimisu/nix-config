{pkgs, ...}: let
  # Prefer setting the Matter device's own NodeLabel (0/40/5) so names survive
  # HA state wipes and re-pairing. Entity_id-based HA customizations are fragile.

  # Disambiguation strategy for multiple devices:
  # - Prefer BasicInfo UniqueID (0/40/18) when present: `unique_id:<value>`
  # - Else SerialNumber (0/40/15): `serial:<value>`
  # - Else MAC from GeneralDiagnostics NetworkInterfaces (0/51/0 field 4): `mac:<aa:bb:cc:dd:ee:ff>`
  #
  # You can discover keys with `matter-node-labels --list`.
  matterNodeLabels = {
    # SmartWings Window Covering (node_id may change; MAC is stable)
    "mac:88:13:bf:aa:50:df" = "Office Blinds";
    "mac:88:13:bf:aa:51:77" = "Nursery Blinds";

    # LED strip (shows up in HA as "ILMS"; Matter vendor/product: Nanoleaf NL72K3)
    "unique_id:1DC692B6244A7FDD" = "MBR Bed Light";
  };

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

  matterNodeLabelsTool = pkgs.writeShellApplication {
    name = "matter-node-labels";
    runtimeInputs = [ pythonEnv ];
    text = ''
      export MATTER_NODE_LABELS_JSON='${matterNodeLabelsJson}'
      exec ${pythonEnv}/bin/python3 ${matterLabeler} "$@"
    '';
  };
in {
  environment.systemPackages = [
    matterNodeLabelsTool
  ];

  systemd.services.matter-apply-node-labels = {
    description = "Apply Matter NodeLabel overrides (Nix-defined)";
    wantedBy = [
      "multi-user.target"
    ];
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
}
