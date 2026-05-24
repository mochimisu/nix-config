{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.gaia.homeAssistant.matterjs;
  otbrSystemdDeps = [
    "otbr-ensure-dataset.service"
  ];

  matterjsDataDir = "/earth/home-assistant/matterjs-server";
  matterjsOtaDir = "${matterjsDataDir}/ota-provider";
  pythonEnv = pkgs.python3.withPackages (ps: [
    ps.websockets
  ]);

  setThreadDatasetScript = pkgs.writeText "matterjs-set-thread-dataset.py" ''
    import asyncio
    import json
    import os
    import sys
    import websockets


    async def call(ws, message_id, command, args=None):
        await ws.send(json.dumps({
            "message_id": message_id,
            "command": command,
            "args": args or {},
        }))
        while True:
            raw = await ws.recv()
            message = json.loads(raw)
            if message.get("event"):
                continue
            if message.get("message_id") == message_id:
                return message


    async def read_server_info(url):
        async with websockets.connect(url, max_size=None) as ws:
            return json.loads(await ws.recv())


    async def main():
        url = os.environ["MATTERJS_THREAD_DATASET_WS_URL"]
        dataset = os.environ.get("MATTER_THREAD_DATASET_HEX", "").strip()
        if not dataset:
            print("matterjs-set-thread-dataset: MATTER_THREAD_DATASET_HEX is empty", file=sys.stderr)
            return 2

        async with websockets.connect(url, max_size=None) as ws:
            await ws.recv()
            response = await call(
                ws,
                "set-thread-dataset",
                "set_thread_dataset",
                {"dataset": dataset},
            )
            if "error_code" in response:
                details = response.get("details") or "unknown error"
                print(f"matterjs-set-thread-dataset: failed: {details}", file=sys.stderr)
                return 1

        server_info = await read_server_info(url)
        if not server_info.get("thread_credentials_set"):
            print("matterjs-set-thread-dataset: command completed but thread_credentials_set is still false", file=sys.stderr)
            return 1

        print("matterjs-set-thread-dataset: thread_credentials_set=true")
        return 0


    if __name__ == "__main__":
        raise SystemExit(asyncio.run(main()))
  '';

  setThreadDataset = pkgs.writeShellApplication {
    name = "matterjs-set-thread-dataset";
    runtimeInputs = [
      pythonEnv
    ];
    text = ''
      set -euo pipefail
      export MATTERJS_THREAD_DATASET_WS_URL="''${1:-ws://127.0.0.1:${toString cfg.port}/ws}"
      exec ${pythonEnv}/bin/python3 ${setThreadDatasetScript}
    '';
  };
in {
  options.gaia.homeAssistant.matterjs = {
    imageTag = lib.mkOption {
      type = lib.types.str;
      default = "0.6.8";
      description = "matter-js/matterjs-server image tag to use for Gaia's primary Matter backend.";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 5580;
      description = "WebSocket/dashboard port for Gaia's primary Matter backend.";
    };
  };

  config = lib.mkMerge [
    {
      environment.systemPackages = [
        setThreadDataset
      ];

      systemd.tmpfiles.rules = [
        "d ${matterjsDataDir} 0755 root root - -"
        "d ${matterjsOtaDir} 0755 root root - -"
      ];
    }

    {
      systemd.services.matterjs-set-thread-dataset = {
        description = "Seed Thread credentials into Matter.js";
        wantedBy = [
          "podman-matter-server.service"
        ];
        after =
          [
            "podman-matter-server.service"
            "network-online.target"
          ]
          ++ otbrSystemdDeps;
        wants =
          [
            "network-online.target"
          ]
          ++ otbrSystemdDeps;
        serviceConfig = {
          Type = "oneshot";
          EnvironmentFile = config.sops.secrets."matter-env".path;
          ExecStartPre = "${pkgs.bash}/bin/bash -c 'for i in {1..60}; do (echo > /dev/tcp/127.0.0.1/${toString cfg.port}) >/dev/null 2>&1 && exit 0; sleep 1; done; echo matterjs ws not ready >&2; exit 1'";
          ExecStart = "${setThreadDataset}/bin/matterjs-set-thread-dataset";
        };
      };
    }
  ];
}
