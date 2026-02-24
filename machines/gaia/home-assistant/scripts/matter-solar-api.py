#!/usr/bin/env python3
import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from zoneinfo import ZoneInfo
import datetime

from solar_window import facade_sun_position, solar_events_for_day, sun_position


def _env_float(name: str, default: float | None = None) -> float | None:
    value = os.getenv(name, "")
    if not value:
        return default
    try:
        return float(value)
    except Exception:
        return default


def _build_payload() -> dict:
    latitude = _env_float("MATTER_SITE_LATITUDE")
    longitude = _env_float("MATTER_SITE_LONGITUDE")
    timezone_name = os.getenv("MATTER_SITE_TIMEZONE") or os.getenv("TZ") or "America/Los_Angeles"
    facade_azimuth = _env_float("MATTER_FACADE_AZIMUTH_DEG", 189.0)

    now_local = datetime.datetime.now(ZoneInfo(timezone_name))
    payload = {
        "timestamp_local": now_local.isoformat(timespec="seconds"),
        "timestamp_utc": now_local.astimezone(datetime.timezone.utc).isoformat(timespec="seconds"),
        "timezone": timezone_name,
        "latitude": latitude,
        "longitude": longitude,
        "facade_azimuth_deg": facade_azimuth,
    }

    if latitude is None or longitude is None:
        payload["error"] = "missing MATTER_SITE_LATITUDE/LONGITUDE"
        return payload

    sunrise, sunset = solar_events_for_day(
        now_local.date(),
        latitude=latitude,
        longitude=longitude,
        timezone_name=timezone_name,
    )
    sun = sun_position(
        latitude=latitude,
        longitude=longitude,
        timezone_name=timezone_name,
        now=now_local,
    )
    facade = facade_sun_position(
        sun_azimuth_deg=sun["azimuth_deg"],
        sun_elevation_deg=sun["elevation_deg"],
        facade_azimuth_deg=facade_azimuth,
    )
    is_night = not bool(sun["is_daylight"])

    payload["solar"] = {
        "sunrise_local": sunrise.isoformat(timespec="seconds") if sunrise else None,
        "sunset_local": sunset.isoformat(timespec="seconds") if sunset else None,
        "day_night": "night" if is_night else "day",
        "sun": sun,
        "facade": facade,
    }
    return payload


class Handler(BaseHTTPRequestHandler):
    def _write_json(self, code: int, body: dict) -> None:
        raw = json.dumps(body, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def do_GET(self) -> None:
        if self.path not in ("/solar", "/healthz", "/"):
            self._write_json(404, {"error": "not_found"})
            return
        if self.path == "/healthz":
            self._write_json(200, {"ok": True})
            return
        self._write_json(200, _build_payload())

    def log_message(self, fmt: str, *args) -> None:
        # Quiet by default; systemd journal still tracks service lifecycle.
        return


def main() -> int:
    bind = os.getenv("MATTER_SOLAR_API_BIND", "127.0.0.1")
    port = int(os.getenv("MATTER_SOLAR_API_PORT", "8056"))
    server = ThreadingHTTPServer((bind, port), Handler)
    server.serve_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
