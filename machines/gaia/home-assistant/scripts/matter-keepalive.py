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
KEEPALIVE_READ_TIMEOUT_SEC = float(os.getenv("MATTER_KEEPALIVE_READ_TIMEOUT_SEC", "8"))
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
KEEPALIVE_NODE_BACKOFF_BASE_SEC = float(os.getenv("MATTER_KEEPALIVE_NODE_BACKOFF_BASE_SEC", "60"))
KEEPALIVE_NODE_BACKOFF_MAX_SEC = float(os.getenv("MATTER_KEEPALIVE_NODE_BACKOFF_MAX_SEC", "900"))
KEEPALIVE_MAX_ATTRIBUTES_PER_PASS = max(1, int(os.getenv("MATTER_KEEPALIVE_MAX_ATTRIBUTES_PER_PASS", "1")))
KEEPALIVE_SKIP_SLEEPY = os.getenv("MATTER_KEEPALIVE_SKIP_SLEEPY", "1").lower() not in {"0", "false", "no"}
KEEPALIVE_FORCE_NODE_IDS = {
    int(value)
    for value in os.getenv("MATTER_KEEPALIVE_FORCE_NODE_IDS", "").replace(",", " ").split()
    if value.isdigit()
}
KEEPALIVE_FORCE_LABELS = {
    value.strip().lower()
    for value in os.getenv("MATTER_KEEPALIVE_FORCE_LABELS", "").split(",")
    if value.strip()
}
KEEPALIVE_FORCE_PRODUCT_KEYWORDS = {
    value.strip().lower()
    for value in os.getenv("MATTER_KEEPALIVE_FORCE_PRODUCT_KEYWORDS", "").split(",")
    if value.strip()
}
KEEPALIVE_ATTRIBUTE_PATHS = [
    value.strip()
    for value in os.getenv("MATTER_KEEPALIVE_ATTRIBUTE_PATHS", "0/40/5").split(",")
    if value.strip()
]
KEEPALIVE_FORCE_ATTRIBUTE_PATHS = [
    value.strip()
    for value in os.getenv(
        "MATTER_KEEPALIVE_FORCE_ATTRIBUTE_PATHS",
        "1/1030/0,0/40/5",
    ).split(",")
    if value.strip()
]
THREAD_VENDOR_KEYWORDS = (
    "inovelli",
    "meross",
    "ikea of sweden",
    "smartwings",
    "aqara",
    "nanoleaf",
)
SLEEPY_PRODUCT_KEYWORDS = (
    "button",
    "door/window",
    "presence",
    "remote",
)


def _b64_to_bytes(value: str) -> bytes | None:
    try:
        return base64.b64decode(value + "===")
    except Exception:
        return None


def _is_forced_keepalive_node(node_id: int, attrs: dict) -> bool:
    if node_id in KEEPALIVE_FORCE_NODE_IDS:
        return True
    label = _node_label(attrs).strip().lower()
    if label and label in KEEPALIVE_FORCE_LABELS:
        return True
    product = str(attrs.get("0/40/3") or "").strip().lower()
    return bool(product and any(keyword in product for keyword in KEEPALIVE_FORCE_PRODUCT_KEYWORDS))


def _is_thread_candidate(node_id: int, attrs: dict) -> bool:
    vendor = str(attrs.get("0/40/1") or "").strip().lower()
    product = str(attrs.get("0/40/3") or "").strip().lower()
    if _is_forced_keepalive_node(node_id, attrs):
        return True
    if KEEPALIVE_SKIP_SLEEPY and any(keyword in product for keyword in SLEEPY_PRODUCT_KEYWORDS):
        return False
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


def _keepalive_attribute_paths(node_id: int, attrs: dict) -> list[str]:
    paths = (
        KEEPALIVE_FORCE_ATTRIBUTE_PATHS
        if _is_forced_keepalive_node(node_id, attrs)
        else KEEPALIVE_ATTRIBUTE_PATHS
    )
    # Prefer paths that the cached interview says exist, but leave BasicInformation
    # as a fallback because older interviews can miss dynamic cluster attributes.
    present = [path for path in paths if path in attrs or path == "0/40/5"]
    return present or ["0/40/5"]


def _rotate_attribute_paths(paths: list[str], previous_entry: dict) -> tuple[list[str], int]:
    if not paths:
        return ["0/40/5"], 0
    previous_index = int(_entry_number(previous_entry, "next_attribute_index", 0))
    start = previous_index % len(paths)
    rotated = paths[start:] + paths[:start]
    selected = rotated[:KEEPALIVE_MAX_ATTRIBUTES_PER_PASS]
    next_index = (start + len(selected)) % len(paths)
    return selected, next_index


def _failure_backoff_sec(consecutive_failures: int) -> float:
    if consecutive_failures <= 0:
        return 0.0
    backoff = KEEPALIVE_NODE_BACKOFF_BASE_SEC * (2 ** max(0, consecutive_failures - 1))
    return min(KEEPALIVE_NODE_BACKOFF_MAX_SEC, backoff)


async def _read_keepalive_attribute(ws, node_id: int, attribute_path: str) -> dict:
    return await asyncio.wait_for(
        _call(
            ws,
            f"keepalive:{node_id}:{attribute_path}",
            "read_attribute",
            {
                "node_id": node_id,
                "attribute_path": attribute_path,
            },
        ),
        timeout=KEEPALIVE_READ_TIMEOUT_SEC,
    )


async def _discover_keepalive_nodes(ws) -> list[tuple[int, dict, bool]]:
    start = await _call(ws, "keepalive:start", "start_listening")
    if "error_code" in start:
        details = start.get("details") or "unknown error"
        raise RuntimeError(f"start_listening failed: {details}")

    found: list[tuple[int, dict, bool]] = []
    for node in start.get("result") or []:
        node_id = node.get("node_id")
        attrs = node.get("attributes") or {}
        available = bool(node.get("available", False))
        if not isinstance(node_id, int) or node_id <= 0:
            continue
        if _is_thread_candidate(node_id, attrs):
            found.append((node_id, attrs, available))
    return found


async def _keepalive_once(ws_url: str) -> None:
    async with websockets.connect(ws_url, max_size=None) as ws:
        await ws.recv()
        nodes = await _discover_keepalive_nodes(ws)
        previous_metrics = _load_keepalive_metrics()
        metrics: dict[str, dict] = {}
        now_epoch = time.time()

        for node_id, attrs, available in sorted(nodes, key=lambda item: item[0]):
            node_key = str(node_id)
            previous_entry = previous_metrics.get(node_key)
            if not isinstance(previous_entry, dict):
                previous_entry = {}

            previous_last_ack = previous_entry.get("last_ack_epoch")
            previous_score = int(_entry_number(previous_entry, "degraded_score", 0))
            previous_failures = int(_entry_number(previous_entry, "consecutive_failures", 0))
            previous_slow = int(_entry_number(previous_entry, "consecutive_slow", 0))
            previous_next_probe = previous_entry.get("next_probe_epoch")

            entry = {
                "label": _node_label(attrs),
                "vendor": str(attrs.get("0/40/1") or ""),
                "product": str(attrs.get("0/40/3") or ""),
                "last_seen_epoch": now_epoch,
                "reported_available": available,
            }
            all_attribute_paths = _keepalive_attribute_paths(node_id, attrs)
            attribute_paths, next_attribute_index = _rotate_attribute_paths(all_attribute_paths, previous_entry)
            entry["attribute_paths"] = attribute_paths
            entry["candidate_attribute_paths"] = all_attribute_paths
            entry["next_attribute_index"] = next_attribute_index

            if isinstance(previous_last_ack, (int, float)):
                entry["last_ack_epoch"] = float(previous_last_ack)

            if isinstance(previous_next_probe, (int, float)) and now_epoch < float(previous_next_probe):
                entry["ok"] = bool(previous_entry.get("ok", False))
                entry["skipped"] = True
                entry["skip_reason"] = f"backoff until {int(round(float(previous_next_probe) - now_epoch))}s"
                entry["consecutive_failures"] = previous_failures
                entry["consecutive_slow"] = previous_slow
                entry["degraded_score"] = previous_score
                entry["next_probe_epoch"] = float(previous_next_probe)
                state, reason = _health_state(entry, now_epoch)
                entry["health_state"] = state
                if reason:
                    entry["health_reason"] = reason
                metrics[node_key] = entry
                continue

            started = time.monotonic()
            responses = []
            for attribute_path in attribute_paths:
                try:
                    response = await _read_keepalive_attribute(ws, node_id, attribute_path)
                except TimeoutError:
                    response = {
                        "error_code": "timeout",
                        "details": f"{attribute_path} read timed out after {KEEPALIVE_READ_TIMEOUT_SEC:g}s",
                    }
                responses.append(response)
            response = next((item for item in responses if "error_code" not in item), responses[-1])
            latency_ms = (time.monotonic() - started) * 1000.0
            entry["latency_ms"] = latency_ms
            if "error_code" in response:
                details = response.get("details") or "unknown error"
                consecutive_failures = previous_failures + 1
                entry["ok"] = False
                entry["error"] = details
                entry["consecutive_failures"] = consecutive_failures
                entry["consecutive_slow"] = 0
                entry["degraded_score"] = previous_score + KEEPALIVE_FAILURE_PENALTY
                entry["next_probe_epoch"] = now_epoch + _failure_backoff_sec(consecutive_failures)
                metrics[node_key] = entry
                print(f"keepalive node_id={node_id} failed: {details}", file=sys.stderr, flush=True)
            else:
                slow = latency_ms >= KEEPALIVE_SLOW_LATENCY_MS
                entry["ok"] = True
                entry["last_ack_epoch"] = now_epoch
                entry["consecutive_failures"] = 0
                entry["consecutive_slow"] = (previous_slow + 1) if slow else 0
                entry.pop("next_probe_epoch", None)
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
