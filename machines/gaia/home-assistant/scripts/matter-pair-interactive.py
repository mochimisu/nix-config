import argparse
import asyncio
import base64
import json
import os
import re
import subprocess
import sys

import websockets

WS_URL_DEFAULT = "ws://127.0.0.1:5580/ws"


def load_dotenv(path: str) -> dict[str, str]:
    values: dict[str, str] = {}
    if not path:
        return values
    try:
        with open(path, "r", encoding="utf-8") as handle:
            for raw_line in handle:
                line = raw_line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                key, value = line.split("=", 1)
                key = key.strip()
                value = value.strip()
                if not key:
                    continue
                if len(value) >= 2 and value[0] == value[-1] and value[0] in ("'", '"'):
                    value = value[1:-1]
                values[key] = value
    except FileNotFoundError:
        print(f"warn: env file not found: {path}", file=sys.stderr)
    except PermissionError:
        print(
            f"warn: cannot read env file {path}; run with sudo or pass --env-file",
            file=sys.stderr,
        )
    return values


def merged_env(path: str | None) -> dict[str, str]:
    env = dict(os.environ)
    if path:
        for key, value in load_dotenv(path).items():
            env.setdefault(key, value)
    return env


def resolved_code(pairing: dict, env: dict[str, str]) -> tuple[str, str]:
    code_env = pairing.get("code_env") or ""
    code = env.get(code_env, "").strip() if code_env else ""
    if not code:
        return code_env, ""
    if code.upper() in {"TODO", "TBD", "UNKNOWN"}:
        return code_env, ""
    return code_env, code


def b64_to_bytes(value: str) -> bytes | None:
    try:
        return base64.b64decode(value + "===")
    except Exception:
        return None


def mac_from_attrs(attrs: dict) -> str | None:
    for entry in (attrs.get("0/51/0") or []):
        hw = entry.get("4")
        if isinstance(hw, str) and hw:
            decoded = b64_to_bytes(hw)
            if decoded and len(decoded) >= 6:
                return ":".join(f"{byte:02x}" for byte in decoded[:6])
    return None


def node_identity(attrs: dict) -> dict[str, str | None]:
    return {
        "unique_id": attrs.get("0/40/18") or None,
        "serial": attrs.get("0/40/15") or None,
        "mac": mac_from_attrs(attrs),
        "label": attrs.get("0/40/5") or None,
    }


def resolve_match(match: dict, env: dict[str, str]) -> dict[str, str]:
    resolved: dict[str, str] = {}
    for field in ("unique_id", "serial", "mac"):
        direct = match.get(field)
        if isinstance(direct, str) and direct:
            resolved[field] = direct
        env_name = match.get(f"{field}_env")
        if isinstance(env_name, str) and env_name:
            env_value = env.get(env_name, "").strip()
            if env_value:
                resolved[field] = env_value.lower() if field == "mac" else env_value
    return resolved


def match_key(pairing: dict, env: dict[str, str]) -> str:
    match = resolve_match(pairing.get("match") or {}, env)
    for field in ("unique_id", "serial", "mac"):
        value = match.get(field)
        if value:
            return f"{field}:{value}"
    return "-"


def pairing_matches_node(node: dict, pairing: dict, env: dict[str, str]) -> bool:
    attrs = node.get("attributes") or {}
    identity = node_identity(attrs)
    desired_name = pairing.get("name")
    desired_match = resolve_match(pairing.get("match") or {}, env)

    if desired_name and identity.get("label") == desired_name:
        return True

    for field in ("unique_id", "serial", "mac"):
        want = desired_match.get(field)
        have = identity.get(field)
        if not want or not have:
            continue
        if field == "mac":
            if have.lower() == want.lower():
                return True
        elif have == want:
            return True
    return False


def matching_nodes(nodes: list[dict], pairing: dict, env: dict[str, str]) -> list[dict]:
    return [node for node in nodes if pairing_matches_node(node, pairing, env)]


async def call(ws, message_id: str, command: str, args: dict | None = None) -> dict:
    payload = {"message_id": message_id, "command": command, "args": args or {}}
    await ws.send(json.dumps(payload))

    while True:
        raw = await ws.recv()
        message = json.loads(raw)
        if message.get("event"):
            continue
        if message.get("message_id") == message_id:
            return message


async def set_thread_dataset(ws, dataset_hex: str) -> None:
    response = await call(
        ws,
        "set-thread-dataset",
        "set_thread_dataset",
        {"dataset": dataset_hex},
    )
    if "error_code" in response:
        details = response.get("details") or "unknown error"
        raise RuntimeError(f"set_thread_dataset failed: {details}")


async def read_nodes(ws) -> list[dict]:
    response = await call(ws, "start-listening", "start_listening")
    if "error_code" in response:
        details = response.get("details") or "unknown error"
        raise RuntimeError(f"start_listening failed: {details}")
    return response.get("result") or []


async def write_node_label(ws, node_id: int, label: str) -> None:
    response = await call(
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


async def remove_node(ws, node_id: int) -> None:
    response = await call(
        ws,
        f"remove:{node_id}",
        "remove_node",
        {"node_id": node_id},
    )
    if "error_code" in response:
        details = response.get("details") or "unknown error"
        raise RuntimeError(f"remove_node failed for node_id={node_id}: {details}")


def status_for_pairing(pairing: dict, nodes: list[dict], env: dict[str, str]) -> str:
    _, code = resolved_code(pairing, env)
    if matching_nodes(nodes, pairing, env):
        return "paired"
    if not code:
        return "missing-code"
    return "unpaired"


def summarize(pairings: list[dict], nodes: list[dict], env: dict[str, str]) -> list[dict]:
    rows = []
    for pairing in pairings:
        rows.append(
            {
                "name": pairing.get("name") or "<unnamed>",
                "status": status_for_pairing(pairing, nodes, env),
                "key": match_key(pairing, env),
                "code_env": pairing.get("code_env") or "",
                "pairing": pairing,
            }
        )
    return rows


def print_rows(rows: list[dict]) -> None:
    print("")
    print("Matter pairings:")
    for idx, row in enumerate(rows, start=1):
        print(f"{idx:2d}. [{row['status']:<12}] {row['name']} ({row['key']})")
    print("")


def candidate_node_id_from_response(response: dict) -> int | None:
    result = response.get("result")
    if isinstance(result, dict):
        node_id = result.get("node_id")
        if isinstance(node_id, int):
            return node_id

    details = str(response.get("details") or "")
    match = re.search(r"\bnode\s+(\d+)\b", details, re.IGNORECASE)
    if match:
        try:
            return int(match.group(1))
        except ValueError:
            return None
    return None


def format_commission_failure(name: str, response: dict, pairing: dict) -> str:
    details = str(response.get("details") or "").strip()
    error_code = response.get("error_code")
    node_id = candidate_node_id_from_response(response)
    code_env = pairing.get("code_env") or "UNSET_CODE_ENV"
    network_only = bool(pairing.get("network_only", False))

    parts = [f"failed {name}"]
    if details:
        parts.append(details)
    if error_code is not None:
        parts.append(f"error_code={error_code}")
    if node_id is not None:
        parts.append(f"candidate_node_id={node_id}")
    parts.append(f"code_env={code_env}")
    parts.append(f"network_only={network_only}")

    generic_details = {
        "",
        "unknown error",
        "Commission with code failed.",
        f"Commission with code failed for node {node_id}." if node_id is not None else "",
    }
    if details in generic_details:
        parts.append(
            "likely_causes=device not in pairing mode, stale/wrong setup code, "
            "already commissioned device without an open commissioning window, or controller BLE reachability"
        )

    raw = json.dumps(response, sort_keys=True)
    parts.append(f"raw={raw}")
    return ": ".join(parts[:2]) + ("; " + "; ".join(parts[2:]) if len(parts) > 2 else "")


def recent_commission_logs(node_id: int | None) -> list[str]:
    if node_id is None:
        return []
    try:
        proc = subprocess.run(
            [
                "journalctl",
                "-u",
                "podman-matter-server.service",
                "-n",
                "80",
                "--no-pager",
                "--output=cat",
            ],
            check=False,
            capture_output=True,
            text=True,
        )
    except Exception:
        return []
    if proc.returncode != 0:
        return []

    needle = f"node {node_id}"
    needle_alt = f"Node ID {node_id}"
    lines: list[str] = []
    for raw_line in proc.stdout.splitlines():
        line = raw_line.strip()
        if not line:
            continue
        if needle in line or needle_alt in line:
            lines.append(line)
    return lines[-6:]


async def commission_pairing(ws, pairing: dict, env: dict[str, str]) -> tuple[bool, str]:
    name = pairing.get("name") or "<unnamed>"
    code_env, code = resolved_code(pairing, env)
    if not code:
        return False, f"skip {name}: missing setup code in {code_env or 'UNSET_CODE_ENV'}"

    response = await call(
        ws,
        f"commission:{name}",
        "commission_with_code",
        {
            "code": code,
            "network_only": bool(pairing.get("network_only", False)),
        },
    )
    if "error_code" in response:
        node_id = candidate_node_id_from_response(response)
        message = format_commission_failure(name, response, pairing)
        log_lines = recent_commission_logs(node_id)
        if log_lines:
            message = f"{message}; journal={json.dumps(log_lines)}"
        return False, message

    result = response.get("result") or {}
    node_id = result.get("node_id")
    if isinstance(node_id, int) and name:
        try:
            await write_node_label(ws, node_id, name)
        except Exception as err:
            return False, f"commissioned {name} (node_id={node_id}) but failed to set label: {err}"
    return True, f"commissioned {name} (node_id={node_id})"


def parse_selection(raw: str, count: int) -> list[int]:
    picked: list[int] = []
    for token in raw.split(","):
        token = token.strip()
        if not token:
            continue
        if "-" in token:
            start_text, end_text = token.split("-", 1)
            start = int(start_text)
            end = int(end_text)
            if start > end:
                start, end = end, start
            for idx in range(start, end + 1):
                if 1 <= idx <= count and idx not in picked:
                    picked.append(idx)
            continue
        idx = int(token)
        if 1 <= idx <= count and idx not in picked:
            picked.append(idx)
    return picked


def pick_rows(rows: list[dict], args: argparse.Namespace) -> list[dict]:
    allowed_statuses = {"unpaired", "paired"} if args.force else {"unpaired"}
    eligible = [row for row in rows if row["status"] in allowed_statuses]
    if args.all:
        return eligible
    if args.select:
        try:
            picked = parse_selection(args.select, len(rows))
        except ValueError:
            print(f"invalid --select value: {args.select}", file=sys.stderr)
            return []
        return [rows[idx - 1] for idx in picked if rows[idx - 1]["status"] in allowed_statuses]
    if args.name:
        wanted = {name.strip() for name in args.name if name.strip()}
        return [row for row in eligible if row["name"] in wanted]
    if not sys.stdin.isatty():
        return []

    while True:
        print_rows(rows)
        print("Select unpaired entries by number, range, or comma list.")
        print("Use 'a' for all unpaired, 'r' to refresh, or 'q' to quit.")
        raw = input("> ").strip().lower()
        if raw in {"q", "quit", "exit"}:
            return []
        if raw in {"a", "all"}:
            return eligible
        if raw in {"r", "refresh"}:
            return None
        try:
            picked = parse_selection(raw, len(rows))
        except ValueError:
            print("invalid selection")
            continue
        selected = [rows[idx - 1] for idx in picked if rows[idx - 1]["status"] in allowed_statuses]
        if selected:
            return selected
        print("no eligible entries selected")


async def interactive_loop(ws, pairings: list[dict], env: dict[str, str], args: argparse.Namespace) -> int:
    while True:
        nodes = await read_nodes(ws)
        rows = summarize(pairings, nodes, env)

        if args.list:
            print_rows(rows)
            return 0

        selected = pick_rows(rows, args)
        if selected is None:
            continue
        if not selected:
            print("nothing selected")
            return 0

        if not args.yes:
            print("")
            print("About to commission:")
            for row in selected:
                print(f"- {row['name']}")
            confirm = input("Proceed? [y/N] ").strip().lower()
            if confirm not in {"y", "yes"}:
                print("aborted")
                return 0

        failures = 0
        for row in selected:
            if args.force:
                stale_nodes = matching_nodes(nodes, row["pairing"], env)
                for stale in stale_nodes:
                    stale_node_id = stale.get("node_id")
                    if not isinstance(stale_node_id, int):
                        continue
                    try:
                        await remove_node(ws, stale_node_id)
                        print(f"removed stale node_id={stale_node_id} for {row['name']}")
                    except Exception as err:
                        print(f"failed removing stale node_id={stale_node_id} for {row['name']}: {err}")
                        failures += 1
                nodes = await read_nodes(ws)
            ok, message = await commission_pairing(ws, row["pairing"], env)
            print(message)
            if not ok:
                failures += 1

        return 1 if failures else 0


async def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--ws-url", default=os.getenv("MATTER_WS_URL", WS_URL_DEFAULT))
    parser.add_argument("--env-file", default=os.getenv("MATTER_ENV_FILE", ""))
    parser.add_argument(
        "--desired-json",
        default=os.getenv("MATTER_DESIRED_PAIRINGS_JSON", "[]"),
    )
    parser.add_argument("--list", action="store_true", help="List pairings and exit.")
    parser.add_argument("--all", action="store_true", help="Commission all unpaired entries.")
    parser.add_argument("--yes", action="store_true", help="Skip confirmation prompt.")
    parser.add_argument(
        "--force",
        action="store_true",
        help="Remove matching stale paired node(s) first, then commission again.",
    )
    parser.add_argument(
        "--select",
        help="Commission unpaired entries by displayed list number, range, or comma list.",
    )
    parser.add_argument(
        "--name",
        action="append",
        default=[],
        help="Commission a specific pairing by exact name. Repeatable.",
    )
    args = parser.parse_args()

    try:
        pairings = json.loads(args.desired_json)
    except Exception as err:
        print(f"Invalid MATTER_DESIRED_PAIRINGS_JSON: {err}", file=sys.stderr)
        return 2

    if not isinstance(pairings, list):
        print("MATTER_DESIRED_PAIRINGS_JSON must be a JSON list", file=sys.stderr)
        return 2

    env = merged_env(args.env_file)

    async with websockets.connect(args.ws_url) as ws:
        await ws.recv()

        dataset = env.get("MATTER_THREAD_DATASET_HEX", "").strip()
        if dataset:
            try:
                await set_thread_dataset(ws, dataset)
            except Exception as err:
                print(f"warn: unable to set Thread dataset: {err}", file=sys.stderr)

        return await interactive_loop(ws, pairings, env, args)


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
