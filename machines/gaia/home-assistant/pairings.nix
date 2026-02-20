{pkgs, ...}: let
  # Declarative desired pairings. Keep setup codes in /etc/secret/matter-reconcile.env
  # using the environment variable named in `code_env`.
  matterDesiredPairings = [
    {
      name = "Office Blinds";
      code_env = "MATTER_CODE_OFFICE_BLINDS";
      network_only = false;
      match = {
        mac = "88:13:bf:aa:50:df";
      };
    }

    {
      name = "Office Blinds Remote";
      code_env = "MATTER_CODE_OFFICE_BLINDS_REMOTE";
      network_only = false;
      match = {
        mac = "52:d8:7d:13:af:d2";
      };
    }

    # Example:
    # {
    #   name = "Nursery Sensor";
    #   code_env = "MATTER_CODE_NURSERY_SENSOR";
    #   network_only = false;
    #   match = {
    #     unique_id = "0123456789ABCDEF";
    #   };
    # }
  ];
  matterDesiredPairingsJson = builtins.toJSON matterDesiredPairings;

  pythonEnv = pkgs.python3.withPackages (ps: [
    ps.websockets
  ]);

  matterReconcile = pkgs.writeText "matter-reconcile.py" ''
    import argparse
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


    def _node_identity(attrs: dict) -> dict:
      return {
        "unique_id": attrs.get("0/40/18") or None,
        "serial": attrs.get("0/40/15") or None,
        "mac": _mac_from_attrs(attrs),
        "label": attrs.get("0/40/5") or None,
      }


    def _matches(node: dict, desired: dict) -> bool:
      attrs = node.get("attributes") or {}
      identity = _node_identity(attrs)
      desired_name = desired.get("name")
      desired_match = desired.get("match") or {}

      if desired_name and identity.get("label") == desired_name:
        return True

      for key in ("unique_id", "serial", "mac"):
        want = desired_match.get(key)
        have = identity.get(key)
        if isinstance(want, str) and want:
          if key == "mac":
            if (have or "").lower() == want.lower():
              return True
          elif have == want:
            return True
      return False


    async def _call(ws, message_id: str, command: str, args: dict | None = None) -> dict:
      payload = {"message_id": message_id, "command": command, "args": args or {}}
      await ws.send(json.dumps(payload))

      while True:
        raw = await ws.recv()
        message = json.loads(raw)
        if message.get("event"):
          continue
        if message.get("message_id") == message_id:
          return message


    async def _set_thread_dataset(ws, dataset_hex: str) -> None:
      response = await _call(
        ws,
        "set-thread-dataset",
        "set_thread_dataset",
        {"dataset": dataset_hex},
      )
      if "error_code" in response:
        details = response.get("details") or "unknown error"
        raise RuntimeError(f"set_thread_dataset failed: {details}")


    async def _read_nodes(ws) -> list[dict]:
      response = await _call(ws, "start-listening", "start_listening")
      if "error_code" in response:
        details = response.get("details") or "unknown error"
        raise RuntimeError(f"start_listening failed: {details}")
      return response.get("result") or []


    async def _write_node_label(ws, node_id: int, label: str) -> None:
      response = await _call(
        ws,
        f"label:{node_id}",
        "write_attribute",
        {"node_id": node_id, "attribute_path": "0/40/5", "value": label},
      )
      if "error_code" in response:
        details = response.get("details") or "unknown error"
        raise RuntimeError(f"write_attribute failed: {details}")

      result = response.get("result")
      if not isinstance(result, list) or not result or result[0].get("Status") != 0:
        raise RuntimeError(f"write_attribute returned non-success status: {response}")


    async def _commission(ws, desired: dict) -> tuple[bool, str]:
      name = desired.get("name") or "<unnamed>"
      code_env = desired.get("code_env") or ""
      code = os.getenv(code_env, "") if code_env else ""
      if not code:
        return False, f"skip {name}: missing setup code in {code_env or 'UNSET_CODE_ENV'}"

      args = {
        "code": code,
        "network_only": bool(desired.get("network_only", False)),
      }
      response = await _call(ws, f"commission:{name}", "commission_with_code", args)
      if "error_code" in response:
        details = response.get("details") or "unknown error"
        return False, f"failed {name}: {details}"

      result = response.get("result") or {}
      node_id = result.get("node_id")
      if isinstance(node_id, int) and name:
        try:
          await _write_node_label(ws, node_id, name)
        except Exception as err:
          return False, f"commissioned {name} (node_id={node_id}) but failed to set label: {err}"

      return True, f"commissioned {name} (node_id={node_id})"


    async def main() -> int:
      parser = argparse.ArgumentParser()
      parser.add_argument("--ws-url", default=os.getenv("MATTER_WS_URL", WS_URL_DEFAULT))
      parser.add_argument(
        "--desired-json",
        default=os.getenv("MATTER_DESIRED_PAIRINGS_JSON", "[]"),
      )
      parser.add_argument("--dry-run", action="store_true")
      args = parser.parse_args()

      try:
        desired = json.loads(args.desired_json)
      except Exception as err:
        print(f"Invalid MATTER_DESIRED_PAIRINGS_JSON: {err}", file=sys.stderr)
        return 2

      if not isinstance(desired, list):
        print("MATTER_DESIRED_PAIRINGS_JSON must be a JSON list", file=sys.stderr)
        return 2

      async with websockets.connect(args.ws_url) as ws:
        await ws.recv()  # server_info

        dataset = os.getenv("MATTER_THREAD_DATASET_HEX", "").strip()
        if dataset:
          try:
            await _set_thread_dataset(ws, dataset)
            print("set Thread dataset in Matter server")
          except Exception as err:
            print(f"warn: unable to set Thread dataset: {err}", file=sys.stderr)

        nodes = await _read_nodes(ws)

        to_commission: list[dict] = []
        for item in desired:
          if not isinstance(item, dict):
            continue
          if any(_matches(node, item) for node in nodes):
            name = item.get("name") or "<unnamed>"
            print(f"ok {name}: already commissioned")
            continue
          to_commission.append(item)

        if not to_commission:
          print("nothing to do")
          return 0

        if args.dry_run:
          for item in to_commission:
            print(f"would commission {item.get('name') or '<unnamed>'}")
          return 0

        failures = 0
        for item in to_commission:
          success, message = await _commission(ws, item)
          print(message)
          if not success:
            failures += 1

        return 1 if failures else 0


    if __name__ == "__main__":
      raise SystemExit(asyncio.run(main()))
  '';

  matterReconcileTool = pkgs.writeShellApplication {
    name = "matter-reconcile";
    runtimeInputs = [pythonEnv];
    text = ''
      export MATTER_DESIRED_PAIRINGS_JSON='${matterDesiredPairingsJson}'
      exec ${pythonEnv}/bin/python3 ${matterReconcile} "$@"
    '';
  };
in {
  environment.systemPackages = [
    matterReconcileTool
  ];

  system.activationScripts.matterReconcileEnv = ''
    ENV_FILE=/etc/secret/matter-reconcile.env
    if [ ! -f "$ENV_FILE" ]; then
      ${pkgs.coreutils}/bin/install -d -m 0750 /etc/secret
      ${pkgs.coreutils}/bin/install -m 0600 /dev/null "$ENV_FILE"
      ${pkgs.coreutils}/bin/cat > "$ENV_FILE" <<'EOT'
# Matter reconcile secrets/config.
# One variable per desired pairing `code_env` key.
# Example:
# MATTER_CODE_NURSERY_SENSOR=MT:Y.ABCD1234...
# Optional: set to seed Thread commissioning credentials.
# MATTER_THREAD_DATASET_HEX=0e080000000000010000000300001235060004001fffe00208...
EOT
    fi
  '';

  systemd.services.matter-reconcile = {
    description = "Reconcile declarative Matter pairings";
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
      SuccessExitStatus = [ 1 ];
      EnvironmentFile = "-/etc/secret/matter-reconcile.env";
      ExecStartPre = "${pkgs.bash}/bin/bash -c 'for i in {1..60}; do (echo > /dev/tcp/127.0.0.1/5580) >/dev/null 2>&1 && exit 0; sleep 1; done; echo matter-server ws not ready >&2; exit 1'";
      ExecStart = "${matterReconcileTool}/bin/matter-reconcile";
    };
  };

  systemd.timers.matter-reconcile = {
    wantedBy = [
      "timers.target"
    ];
    timerConfig = {
      OnBootSec = "3min";
      OnUnitInactiveSec = "30min";
      Unit = "matter-reconcile.service";
    };
  };
}
