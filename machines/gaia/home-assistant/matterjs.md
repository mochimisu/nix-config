# Gaia Matter.js Runbook

Gaia runs `matterjs-server` as the primary Matter backend. The normal service name is `podman-matter-server.service`, and Home Assistant connects to `ws://127.0.0.1:5580/ws`.

## Current Shape

- Primary controller: `ghcr.io/matter-js/matterjs-server:stable`.
- WebSocket/dashboard: `ws://127.0.0.1:5580/ws` and `http://127.0.0.1:5580/`.
- Matter.js storage: `/earth/home-assistant/matterjs-server`.
- Custom OTA drop directory: `/earth/home-assistant/matterjs-server/ota-provider`.
- PAA root certificate directory: `/earth/home-assistant/matter-server/paa-root-certs`.
- Thread dataset source: `MATTER_THREAD_DATASET_HEX` from `machines/gaia/secrets/matter-env.env` via sops.

## Startup Order

Matter.js depends on the ZBT-2 Thread border router being ready. The normal Matter server unit is ordered after:

- `podman-otbr.service`
- `otbr-ensure-dataset.service`
- `otbr-prefer-zbt2-router.service`

If Thread devices look unavailable while Wi-Fi Matter devices work, restart in this order:

```sh
sudo systemctl stop home-assistant.service matter-keepalive.service podman-matter-server.service
sudo systemctl restart podman-otbr.service
sudo systemctl start otbr-ensure-dataset.service otbr-prefer-zbt2-router.service
sudo podman exec otbr ot-ctl state
sudo systemctl start podman-matter-server.service matterjs-set-thread-dataset.service
sleep 90
matter-health
timeout 15 matter-watch
sudo systemctl start home-assistant.service matter-keepalive.service
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
