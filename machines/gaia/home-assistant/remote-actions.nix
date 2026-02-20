{pkgs, ...}: let
  # Office bindings (Matter-over-Thread, handled directly through matter.js server API).
  remoteMac = "52:d8:7d:13:af:d2";
  remoteNodeId = 19;
  blindsMac = "88:13:bf:aa:50:df";
  blindsEndpoint = 1;
  pythonEnv = pkgs.python3.withPackages (ps: [
    ps.websockets
  ]);

  matterRemoteActions = pkgs.writeText "matter-remote-actions.py" ''
    import asyncio
    import base64
    import json
    import os
    import sys

    import websockets

    WS_URL_DEFAULT = "ws://127.0.0.1:5580/ws"
    REMOTE_MAC = "${remoteMac}"
    REMOTE_NODE_ID = ${toString remoteNodeId}
    BLINDS_MAC = "${blindsMac}"
    BLINDS_ENDPOINT = ${toString blindsEndpoint}
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

        async with websockets.connect(ws_url) as ws:
            # server info frame
            await ws.recv()

            start = await _call(ws, "start", "start_listening")
            if "error_code" in start:
                details = start.get("details") or "unknown error"
                print(f"start_listening failed: {details}", file=sys.stderr)
                return 1

            nodes = start.get("result") or []
            # Use configured node id as a fallback for remotes that don't expose MAC details.
            remote_node_id = REMOTE_NODE_ID
            blinds_node_id = None

            for node in nodes:
                node_id = node.get("node_id")
                attrs = node.get("attributes") or {}
                mac = _mac_from_attrs(attrs)
                if mac and mac.lower() == REMOTE_MAC.lower():
                    remote_node_id = node_id
                if mac and mac.lower() == BLINDS_MAC.lower():
                    blinds_node_id = node_id
            if blinds_node_id is None:
                print(f"blinds node not found by mac {BLINDS_MAC}", file=sys.stderr)
                return 1

            print(
                f"listening for remote node_id={remote_node_id}, controlling blinds node_id={blinds_node_id}",
                flush=True,
            )

            current_direction = "idle"  # one of: idle, up, down

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
                        print(
                            f"remote button {endpoint_id}: {mode} {desired_direction}",
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
  '';

  matterEvents = pkgs.writeText "matter-events.py" ''
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
          meta_label = meta.get("label", "")
          meta_mac = meta.get("mac", "")
          print(
            f"streaming node_event for node_id={target_node_id} label={meta_label} mac={meta_mac}",
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
          meta_label = meta.get("label", "")
          meta_mac = meta.get("mac", "")
          print(
            f"{ts} node={node_id} label={meta_label} mac={meta_mac} "
            f"ep={endpoint_id} cluster={cluster_id} event={event_id} event_no={event_number} payload={payload}",
            flush=True,
          )


    if __name__ == "__main__":
      raise SystemExit(asyncio.run(_run()))
  '';

  matterHealth = pkgs.writeText "matter-health.py" ''
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
  '';

  matterRemoteActionsTool = pkgs.writeShellApplication {
    name = "matter-remote-actions";
    runtimeInputs = [pythonEnv];
    text = ''
      exec ${pythonEnv}/bin/python3 ${matterRemoteActions} "$@"
    '';
  };

  matterEventsTool = pkgs.writeShellApplication {
    name = "matter-events";
    runtimeInputs = [pythonEnv];
    text = ''
      exec ${pythonEnv}/bin/python3 ${matterEvents} "$@"
    '';
  };

  matterHealthTool = pkgs.writeShellApplication {
    name = "matter-health";
    runtimeInputs = [pythonEnv];
    text = ''
      exec ${pythonEnv}/bin/python3 ${matterHealth} "$@"
    '';
  };
in {
  environment.systemPackages = [
    matterRemoteActionsTool
    matterEventsTool
    matterHealthTool
  ];

  systemd.services.matter-remote-actions = {
    description = "Matter.js remote actions for office blinds";
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
      Type = "simple";
      Restart = "always";
      RestartSec = "5s";
      ExecStartPre = "${pkgs.bash}/bin/bash -c 'for i in {1..60}; do (echo > /dev/tcp/127.0.0.1/5580) >/dev/null 2>&1 && exit 0; sleep 1; done; echo matter-server ws not ready >&2; exit 1'";
      ExecStart = "${matterRemoteActionsTool}/bin/matter-remote-actions";
    };
  };
}
