# Gaia Matter.js Runbook

Gaia runs `matterjs-server` as the primary Matter backend. The normal service name is `podman-matter-server.service`, and Home Assistant connects to `ws://127.0.0.1:5580/ws`.

## Current Shape

- Primary controller: `ghcr.io/matter-js/matterjs-server:latest`.
- WebSocket/dashboard: local `ws://127.0.0.1:5580/ws` and `http://127.0.0.1:5580/`; LAN dashboard access is available at `http://gaia:5580/`.
- Matter.js storage: `/earth/home-assistant/matterjs-server`.
- Custom OTA drop directory: `/earth/home-assistant/matterjs-server/ota-provider`.
- PAA root certificate directory: `/earth/home-assistant/matter-server/paa-root-certs`.
- Thread dataset source: `MATTER_THREAD_DATASET_HEX` from `machines/gaia/secrets/matter-env.env` via sops.
- Thread border router: Gaia's local ZBT-2 OTBR is enabled and stores OTBR state in `/earth/home-assistant/otbr`.
- Keepalive: the manual `matter-keepalive` tool remains installed, but the background service is disabled while matter-layer handles targeted stale probes after 2 minutes without source updates for available devices and 5 minutes for unavailable devices.

## Startup Order

Matter.js depends on the ZBT-2 Thread border router being ready. The Matter server unit is ordered after:

- `podman-otbr.service`
- `otbr-ensure-dataset.service`
- `otbr-prefer-zbt2-router.service`

If Thread devices look unavailable while Wi-Fi Matter devices work, restart in this order:

```sh
sudo systemctl stop home-assistant.service podman-matter-server.service
sudo systemctl restart podman-otbr.service
sudo systemctl start otbr-ensure-dataset.service otbr-prefer-zbt2-router.service
sudo podman exec otbr ot-ctl state
sudo systemctl start podman-matter-server.service matterjs-set-thread-dataset.service
sleep 90
matter-health
timeout 15 matter-watch
sudo systemctl start home-assistant.service
```

`ot-ctl state` should be `router` or `leader`, not `child`.

## Validation

```sh
matter-health
timeout 15 matter-watch
matter-events --all
```

Pass criteria:

- Matter.js server info reports `thread_credentials_set=true`.
- Thread and Wi-Fi Matter nodes both respond to live reads.
- Presence sensors and remotes emit events through the default `5580` URL.
- Home Assistant's Matter integration is configured for `ws://127.0.0.1:5580/ws`.

## BILRESA Event Latency

If a BILRESA remote answers `ping_node` or Identify but button events arrive minutes late, treat that as Matter.js subscription/session delivery first. A known failure shape is a Switch-cluster event burst only when Matter.js replaces a timed-out subscription. Validate the running server with:

```sh
matter-health | head
```

or a direct `server_info` websocket call; it should not report the old floating `stable` image's `matter-server/0.6.4` build. After deploying a fresh `latest` image, restart `podman-matter-server.service`, run `matterjs-set-thread-dataset.service`, restart `matter-layer.service`, then watch `journalctl -u podman-matter-server.service` for `Replacing subscription to @1:2ec` and delayed `node_id: 748` Switch events.
