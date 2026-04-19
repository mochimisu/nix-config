#!/usr/bin/env python3
import asyncio
import base64
import json
import os
import sys
import time

import websockets

WS_URL_DEFAULT = "ws://127.0.0.1:5580/ws"
KEEPALIVE_INTERVAL_SEC = int(os.getenv("MATTER_KEEPALIVE_INTERVAL_SEC", "30"))
KEEPALIVE_LATENCY_FILE = os.getenv("MATTER_KEEPALIVE_LATENCY_FILE", "/run/matter-keepalive-latency.json")
KEEPALIVE_SLOW_LATENCY_MS = float(os.getenv("MATTER_KEEPALIVE_SLOW_LATENCY_MS", "1500"))
KEEPALIVE_FAILURE_PENALTY = int(os.getenv("MATTER_KEEPALIVE_FAILURE_PENALTY", "2"))
KEEPALIVE_SLOW_PENALTY = int(os.getenv("MATTER_KEEPALIVE_SLOW_PENALTY", "1"))
KEEPALIVE_SUCCESS_DECAY = int(os.getenv("MATTER_KEEPALIVE_SUCCESS_DECAY", "1"))
KEEPALIVE_DEGRADED_SCORE = int(os.getenv("MATTER_KEEPALIVE_DEGRADED_SCORE", "4"))
KEEPALIVE_PERSISTENT_SCORE = int(os.getenv("MATTER_KEEPALIVE_PERSISTENT_SCORE", "6"))
KEEPALIVE_DEGRADED_FAILURES = int(os.getenv("MATTER_KEEPALIVE_DEGRADED_FAILURES", "2"))
KEEPALIVE_PERSISTENT_FAILURES = int(os.getenv("MATTER_KEEPALIVE_PERSISTENT_FAILURES", "3"))
KEEPALIVE_DEGRADED_SLOW_STREAK = int(os.getenv("MATTER_KEEPALIVE_DEGRADED_SLOW_STREAK", "3"))
KEEPALIVE_STALE_WARN_SEC = float(
    os.getenv("MATTER_KEEPALIVE_STALE_WARN_SEC", str(max(120, KEEPALIVE_INTERVAL_SEC * 4)))
)
KEEPALIVE_STALE_CRIT_SEC = float(
    os.getenv("MATTER_KEEPALIVE_STALE_CRIT_SEC", str(max(300, KEEPALIVE_INTERVAL_SEC * 10)))
)
THREAD_VENDOR_KEYWORDS = (
    "inovelli",
    "meross",
    "ikea of sweden",
    "smartwings",
    "aqara",
    "nanoleaf",
)


def _b64_to_bytes(value: str) -> bytes | None:
    try:
        return base64.b64decode(value + "===")
    except Exception:
        return None


def _is_thread_candidate(attrs: dict) -> bool:
    vendor = str(attrs.get("0/40/1") or "").strip().lower()
    product = str(attrs.get("0/40/3") or "").strip().lower()
    if any(keyword in vendor for keyword in THREAD_VENDOR_KEYWORDS):
        return True
    for path in attrs.keys():
        if isinstance(path, str) and (path.startswith("0/53/") or path.startswith("0/54/")):
            return True
    if "button" in product or "remote" in product:
        return True
    return False


def _write_keepalive_metrics(metrics: dict[str, dict]) -> None:
    parent = os.path.dirname(KEEPALIVE_LATENCY_FILE) or "."
    os.makedirs(parent, exist_ok=True)
    tmp = f"{KEEPALIVE_LATENCY_FILE}.tmp"
    payload = {
        "updated_at_epoch": time.time(),
        "nodes": metrics,
    }
    with open(tmp, "w", encoding="utf-8") as handle:
        json.dump(payload, handle, separators=(",", ":"), sort_keys=True)
    os.replace(tmp, KEEPALIVE_LATENCY_FILE)


def _load_keepalive_metrics() -> dict[str, dict]:
    try:
        with open(KEEPALIVE_LATENCY_FILE, "r", encoding="utf-8") as handle:
            data = json.load(handle)
    except Exception:
        return {}
    if not isinstance(data, dict):
        return {}
    nodes = data.get("nodes")
    return nodes if isinstance(nodes, dict) else {}


def _entry_number(entry: dict, key: str, default: float = 0.0) -> float:
    value = entry.get(key)
    if isinstance(value, (int, float)):
        return float(value)
    return default


def _node_label(attrs: dict) -> str:
    label = attrs.get("0/40/5")
    if isinstance(label, str) and label.strip():
        return label.strip()
    return "(unlabeled)"


def _health_state(entry: dict, now_epoch: float) -> tuple[str, str]:
    score = int(_entry_number(entry, "degraded_score", 0))
    consecutive_failures = int(_entry_number(entry, "consecutive_failures", 0))
    consecutive_slow = int(_entry_number(entry, "consecutive_slow", 0))
    last_ack_epoch = entry.get("last_ack_epoch")
    ack_age_sec = None
    if isinstance(last_ack_epoch, (int, float)):
        ack_age_sec = max(0.0, now_epoch - float(last_ack_epoch))

    if consecutive_failures >= KEEPALIVE_PERSISTENT_FAILURES:
        return "persistent", f"{consecutive_failures} failed reads"
    if ack_age_sec is not None and ack_age_sec >= KEEPALIVE_STALE_CRIT_SEC:
        return "persistent", f"stale ack {int(round(ack_age_sec))}s"
    if score >= KEEPALIVE_PERSISTENT_SCORE:
        return "persistent", f"score {score}"

    if consecutive_failures >= KEEPALIVE_DEGRADED_FAILURES:
        return "degraded", f"{consecutive_failures} failed reads"
    if ack_age_sec is not None and ack_age_sec >= KEEPALIVE_STALE_WARN_SEC:
        return "degraded", f"stale ack {int(round(ack_age_sec))}s"
    if consecutive_slow >= KEEPALIVE_DEGRADED_SLOW_STREAK:
        return "degraded", f"{consecutive_slow} slow reads"
    if score >= KEEPALIVE_DEGRADED_SCORE:
        return "degraded", f"score {score}"

    return "healthy", ""


async def _call(ws, message_id: str, command: str, args: dict | None = None) -> dict:
    payload = {"message_id": message_id, "command": command, "args": args or {}}
    await ws.send(json.dumps(payload))
    while True:
        message = json.loads(await ws.recv())
        if message.get("event"):
            continue
        if message.get("message_id") == message_id:
            return message


async def _discover_keepalive_nodes(ws) -> list[tuple[int, dict]]:
    start = await _call(ws, "keepalive:start", "start_listening")
    if "error_code" in start:
        details = start.get("details") or "unknown error"
        raise RuntimeError(f"start_listening failed: {details}")

    found: list[tuple[int, dict]] = []
    for node in start.get("result") or []:
        node_id = node.get("node_id")
        attrs = node.get("attributes") or {}
        if not isinstance(node_id, int) or node_id <= 0:
            continue
        if _is_thread_candidate(attrs):
            found.append((node_id, attrs))
    return found


async def _keepalive_once(ws_url: str) -> None:
    async with websockets.connect(ws_url, max_size=None) as ws:
        await ws.recv()
        nodes = await _discover_keepalive_nodes(ws)
        previous_metrics = _load_keepalive_metrics()
        metrics: dict[str, dict] = {}
        now_epoch = time.time()

        for node_id, attrs in sorted(nodes, key=lambda item: item[0]):
            node_key = str(node_id)
            previous_entry = previous_metrics.get(node_key)
            if not isinstance(previous_entry, dict):
                previous_entry = {}

            previous_last_ack = previous_entry.get("last_ack_epoch")
            previous_score = int(_entry_number(previous_entry, "degraded_score", 0))
            previous_failures = int(_entry_number(previous_entry, "consecutive_failures", 0))
            previous_slow = int(_entry_number(previous_entry, "consecutive_slow", 0))

            started = time.monotonic()
            response = await _call(
                ws,
                f"keepalive:{node_id}",
                "read_attribute",
                {
                    "node_id": node_id,
                    "attribute_path": "0/40/5",
                },
            )
            latency_ms = (time.monotonic() - started) * 1000.0
            entry = {
                "label": _node_label(attrs),
                "vendor": str(attrs.get("0/40/1") or ""),
                "product": str(attrs.get("0/40/3") or ""),
                "last_seen_epoch": now_epoch,
                "latency_ms": latency_ms,
            }
            if "error_code" in response:
                details = response.get("details") or "unknown error"
                entry["ok"] = False
                entry["error"] = details
                entry["consecutive_failures"] = previous_failures + 1
                entry["consecutive_slow"] = 0
                entry["degraded_score"] = previous_score + KEEPALIVE_FAILURE_PENALTY
                if isinstance(previous_last_ack, (int, float)):
                    entry["last_ack_epoch"] = float(previous_last_ack)
                metrics[node_key] = entry
                print(f"keepalive node_id={node_id} failed: {details}", file=sys.stderr, flush=True)
            else:
                slow = latency_ms >= KEEPALIVE_SLOW_LATENCY_MS
                entry["ok"] = True
                entry["last_ack_epoch"] = now_epoch
                entry["consecutive_failures"] = 0
                entry["consecutive_slow"] = (previous_slow + 1) if slow else 0
                if slow:
                    entry["degraded_score"] = previous_score + KEEPALIVE_SLOW_PENALTY
                else:
                    entry["degraded_score"] = max(0, previous_score - KEEPALIVE_SUCCESS_DECAY)
                metrics[node_key] = entry

            state, reason = _health_state(entry, now_epoch)
            previous_state = str(previous_entry.get("health_state") or "healthy")
            entry["health_state"] = state
            if reason:
                entry["health_reason"] = reason
            else:
                entry.pop("health_reason", None)

            previous_since = previous_entry.get("degraded_since_epoch")
            if state == "healthy":
                entry.pop("degraded_since_epoch", None)
            elif isinstance(previous_since, (int, float)) and previous_state in {"degraded", "persistent"}:
                entry["degraded_since_epoch"] = float(previous_since)
            else:
                entry["degraded_since_epoch"] = now_epoch

            previous_reason = str(previous_entry.get("health_reason") or "")
            if state != previous_state:
                suffix = f" ({reason})" if reason else ""
                print(
                    f"keepalive node_id={node_id} label={entry['label']!r} state {previous_state} -> {state}{suffix}",
                    file=sys.stderr,
                    flush=True,
                )
            elif state != "healthy" and reason and reason != previous_reason:
                print(
                    f"keepalive node_id={node_id} label={entry['label']!r} state {state}: {reason}",
                    file=sys.stderr,
                    flush=True,
                )

        _write_keepalive_metrics(metrics)


async def _run() -> int:
    ws_url = os.getenv("MATTER_WS_URL", WS_URL_DEFAULT)
    if KEEPALIVE_INTERVAL_SEC <= 0:
        return 0

    while True:
        try:
            await _keepalive_once(ws_url)
        except Exception as err:
            print(f"keepalive loop error: {err}", file=sys.stderr, flush=True)
        await asyncio.sleep(KEEPALIVE_INTERVAL_SEC)


if __name__ == "__main__":
    raise SystemExit(asyncio.run(_run()))
