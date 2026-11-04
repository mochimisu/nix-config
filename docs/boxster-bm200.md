# Boxster ANCEL BM200 via ESPHome

Gaia installs Rafciq/BM6 1.0.3 from commit
`53437905346a0da5f2a6aa62bed3402a0b40bb43` using `overlays/ha-bm6.nix`.
The source hash is `sha256-sqxkv2mUQEVOHq4KAVMlKJV3msQZT7WWRIF1LjbbyZs=`.
Gaia's existing Home Assistant container preStart copies this fixed component from
the Nix store on every start. No HACS-managed mutable installation is used.

The upstream manifest omitted the imported Crypto dependency. The package adds
`pycryptodome==3.23.0` to the manifest for the upstream HA container to resolve.
The other imports are HA-provided Bluetooth libraries and standard HA dependencies.

## Telemetry and local patch

Review found exactly one active monitor command: encrypted `d15507` realtime
request to FFF3, with notifications on FFF4. No battery-type, threshold, pairing,
clock, or firmware-setting command is sent. HA battery estimation options only
change calculations in HA. Prefer the device-reported algorithm and zero offsets
until battery chemistry/calibration has been confirmed.

`ha-bm6-telemetry.patch` subscribes before requesting data, bounds the response
wait to 10 seconds, returns on first successful scanner, and tries the next
scanner after failure. This avoids missed immediate replies, indefinitely occupied
proxy slots, and duplicate requests through every scanner. It also fixes exception
annotation. Offline tests cover immediate response ordering and the single
telemetry request, timeout/disconnect, and failed-scanner fallback:

```
python3 tests/test-bm6-telemetry.py /nix/store/<built-bm6>/custom_components/bm6/bm6_connect.py
```

## Setup and verification

Activate the built Gaia generation through the normal NixOS switch workflow.
This restarts Home Assistant to install/load the component; do not reboot Gaia.
Use the existing authenticated HA UI to add Battery Monitor BM6 for only the
verified Boxster monitor. Keep its unique address in HA's persistent config entry,
not this repository. Config entries live under the persistent `/earth/home-assistant`
volume and survive container restarts and Nix rebuilds.

2026-10-31: ESP32-D0WD-V3 / 4 MB runs ESPHome 2026.9.1, encrypted API and
active Bluetooth proxy, paired to Gaia and assigned Garage. Fresh FFF0 advertising
matched the user-supplied serial at -79 dBm. Wi-Fi previously measured -45 dBm.
The first generation was activated via nix-rs and the matching HA entry created.
Live polling through the Boxster proxy returned a `d15507ff` acknowledgement with
zero padding, which upstream incorrectly treated as a zero-voltage measurement.
The follow-up patch ignores that acknowledgement and waits for the measurement;
its four regression tests and complete Gaia build passed. The follow-up generation was activated on 2026-10-31 at 15:30 PDT.
Live telemetry is now verified: 12.80 V, 24 C, 100 percent device-reported charge
at 15:34:55 PDT via Boxster BLE Proxy; fresh unrelated advertisements continued
arriving through the proxy at the same time. Second automatic poll at 15:35:59 PDT returned 12.80 V, 25 C and 100 percent.
Both reads succeeded in 4-6 seconds via the garage proxy. The proxy released its
connection (0/3 occupied between polls), with advertisements 3-19 seconds old.
Temporary debug logging was disabled after verification.
After activation verify fresh voltage/temperature, the scanner sensor identifying
Boxster BLE Proxy, repeated updates, and continued HA advertisement forwarding.

ESPHome Wi-Fi/API/OTA secrets are private on Blackmoon outside Git. The temporary
USB ACL vanished on unplug; no permanent serial permission was added. No HA token
was created. The phone app should remain disconnected during gateway polling.

## Setup bug and retained configuration

Upstream 1.0.3 skips battery metadata for the device-reported algorithm but still
requires it at initialization. Workaround used in HA: select SoC/SoD, save its
12 V / AGM defaults, then select device-reported mode again, preserving metadata,
and reload the entry. The retained final algorithm is `by_device`, interval 60 s,
zero voltage/temperature offsets, Celsius. The default metadata is not a verified
claim of battery chemistry and is not written to the monitor. No token was created.

Only the monitor's minimal realtime request was sent during verification. Debug
logging confirmed the garage proxy was the sole scanner used; logging was then
disabled. Zero readings from the unfiltered acknowledgement are invalid telemetry.

The final active generation is
`/nix/store/1nn0c91ark5xibr2nkgfwlggkwby8h7i-nixos-system-gaia-26.11.20261027.31ecbac`.
The upstream human-readable battery state entity currently shows Unknown despite
valid voltage, temperature and reported percentage; do not use it for alerts yet.
The monitor's reported percentage is not an independent battery health assessment.

## Presentation follow-up — October 31

Voltage display precision was set to two decimal places using HA's persistent
entity setting, verified as 12.80 V. Measurements and entity IDs are unchanged;
this setting survives ordinary HA/container restarts and Nix rebuilds.

The Unknown state was traced to an upstream type mismatch: the parser returns
integer 0/1/2 while Battery's lookup uses Enum keys. `ha-bm6-state.patch` normalizes
the integer through the upstream enum before lookup, preserving the existing
0=Ok, 1=LowVoltage, 2=Charging meanings and Unknown for unrecognized values.
Two real-frame mapping tests (all three known statuses and unknown cases) and
all four telemetry regression tests passed against the built package.

The state correction is staged in both Nix checkouts and its package is copied
to Gaia, but is NOT active yet. Include it in the next coordinated Gaia rebuild;
no standalone Nix activation was performed to avoid overlap with UPS work.
