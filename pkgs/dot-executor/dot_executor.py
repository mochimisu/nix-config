#!/usr/bin/env python3
"""Fail-closed supervisor for an already-enrolled Codex executor.

This program does NOT enroll a computer or authorize a dot. It uses the native
Codex CLI and its existing private login, never extracts or prints credentials.
"""
from __future__ import annotations

import argparse
import fcntl
import json
import os
from pathlib import Path
import re
import selectors
import signal
import socket
import stat
import subprocess
import sys
import tempfile
import time

REGISTRY = "https://codex-cloud-environments.chatgpt.com/api"
CODEX = Path("@codex@")
STATE = Path.home() / ".local/share/dot-executor"
SCHEMA = 1


class SetupError(Exception):
    pass


def private_path(path: Path, directory: bool = False) -> None:
    try:
        st = path.lstat()
    except FileNotFoundError:
        raise SetupError(f"Missing {path.name}") from None
    expected = stat.S_ISDIR if directory else stat.S_ISREG
    if not expected(st.st_mode) or st.st_uid != os.getuid():
        raise SetupError(f"{path.name} must be owned by this user and not a symlink")
    wanted = 0o700 if directory else 0o600
    if stat.S_IMODE(st.st_mode) != wanted:
        raise SetupError(f"{path.name} must have mode {wanted:o}; no permissions were changed")


def load_enrollment(state: Path = STATE, hostname: str | None = None, declared: dict | None = None) -> dict:
    path = state / "enrollment.json"
    if not path.exists():
        if declared is None:
            raise SetupError("Enrollment is pending: restore the existing computer identity or use the reviewed declarative configuration")
        value = declared
    else:
        private_path(path)
        if path.stat().st_size > 32768:
            raise SetupError("Enrollment file is too large")
        try:
            value = json.loads(path.read_text())
        except (ValueError, UnicodeError):
            raise SetupError("Enrollment file is not valid JSON") from None
    keys = {"schema_version", "environment_id", "registry_url", "issued_for_host", "enrollment_source"}
    if not isinstance(value, dict) or set(value) != keys or value["schema_version"] != SCHEMA:
        raise SetupError("Enrollment file has an unsupported schema")
    if not isinstance(value["environment_id"], str) or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]{0,255}", value["environment_id"]):
        raise SetupError("A server-issued environment ID is required; placeholders are not valid")
    if value["environment_id"] in (value["issued_for_host"], f"{value['issued_for_host']}-executor", "REPLACE_ME", "pending"):
        raise SetupError("A display name or installation ID is not an environment ID")
    if value["registry_url"] != REGISTRY:
        raise SetupError("Registry does not match the reviewed production registry")
    if value["issued_for_host"] != (hostname or socket.gethostname()):
        raise SetupError("Enrollment belongs to a different computer")
    if not isinstance(value["enrollment_source"], str) or not value["enrollment_source"].strip():
        raise SetupError("Record how the authorized enrollment was obtained")
    if declared is not None:
        for key in ("environment_id", "registry_url", "issued_for_host"):
            if value[key] != declared[key]:
                raise SetupError("Private enrollment and declarative identity differ; stopped without changing either")
    return value


def child_environment(state: Path = STATE) -> dict:
    env = dict(os.environ)
    # Keep normal network/proxy settings. Do not borrow another login or pretend
    # to be the desktop app. The CLI owns credential use and refresh.
    for key in tuple(env):
        if key.startswith("CODEX_") or key in {"OPENAI_API_KEY", "OPENAI_ACCESS_TOKEN", "RUST_LOG", "DISPLAY", "WAYLAND_DISPLAY", "XAUTHORITY"}:
            env.pop(key)
    env.update(CODEX_HOME=str(state), RUST_LOG="codex_exec_server::remote=info", LOG_FORMAT="json")
    return env


def preflight(state: Path = STATE, codex: Path = CODEX, declared: dict | None = None) -> dict:
    private_path(state, directory=True)
    private_path(state / "auth.json")
    if not codex.is_file() or not os.access(codex, os.X_OK):
        raise SetupError("Installed Codex executable is unavailable")
    enrollment = load_enrollment(state, declared=declared)
    try:
        login = subprocess.run([str(codex), "login", "status"], env=child_environment(state),
                               capture_output=True, text=True, timeout=15)
    except (OSError, subprocess.TimeoutExpired):
        raise SetupError("Could not check the existing Codex login") from None
    # Never relay raw authentication output or initiate a login automatically.
    if login.returncode != 0 or "Logged in using ChatGPT" not in login.stdout + login.stderr:
        raise SetupError("A valid ChatGPT login is required in the existing dedicated Codex home")
    return enrollment


def command(enrollment: dict, codex: Path = CODEX) -> list[str]:
    return [str(codex), "-c", 'forced_login_method="chatgpt"', "exec-server",
            "--concurrent-requests", "32", "--remote", REGISTRY,
            "--environment-id", enrollment["environment_id"], "--exit-on-stdin-close"]


def classify_log(line: str) -> str | None:
    # Inspect only transport diagnostics, never forward their raw contents.
    # Native tracing can emit ANSI styling even with piped output. Normalize it
    # before matching fields so readiness and HTTP denials remain observable.
    line = re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", line)
    try:
        record = json.loads(line)
    except (ValueError, TypeError):
        record = None
    if isinstance(record, dict):
        for fields in (record, record.get("fields")):
            if not isinstance(fields, dict):
                continue
            for key in ("status", "status_code", "http_status", "http_status_code"):
                if fields.get(key) in (401, 403, "401", "403"):
                    return "access_denied"
    if re.search(r"\b(?:unauthorized|forbidden|cloudflare)\b", line, re.I) or re.search(r"\b(?:HTTP(?:/\S+)?|status)[ :=]+(?:401|403)\b", line, re.I):
        return "access_denied"
    if "rendezvous_connection" in line and re.search(r'noise_outcome["\s:=]+ok\b', line):
        return "transport_ready"
    return None


def write_status(state: Path, phase: str, **extra) -> None:
    record = {"schema_version": SCHEMA, "phase": phase, "updated_at_unix": int(time.time()),
              "dot_access": "not_verified", **extra}
    fd, name = tempfile.mkstemp(prefix=".runtime-status-", dir=state)
    try:
        with os.fdopen(fd, "w") as file:
            json.dump(record, file, indent=2)
            file.write("\n")
        os.replace(name, state / "runtime-status.json")
    finally:
        if os.path.exists(name):
            os.unlink(name)


def stop_child(child: subprocess.Popen) -> None:
    if child.stdin:
        child.stdin.close()
    if child.poll() is None:
        child.terminate()
    try:
        child.wait(timeout=10)
    except subprocess.TimeoutExpired:
        child.kill()
        child.wait(timeout=5)
    if child.stderr:
        child.stderr.close()
    if child.stdout:
        child.stdout.close()


def supervise(state: Path = STATE, codex: Path = CODEX, startup_timeout: float | None = None, declared: dict | None = None) -> int:
    enrollment = preflight(state, codex, declared)
    fd = os.open(state / "supervisor.lock", os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, "w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise SetupError("Another headless supervisor is already running") from None
        stopping = False

        def stop(_signum, _frame):
            nonlocal stopping
            stopping = True

        previous = {s: signal.signal(s, stop) for s in (signal.SIGTERM, signal.SIGINT)}
        child = None
        phase = "running_unverified"
        result = 1
        try:
            child = subprocess.Popen(command(enrollment, codex), cwd=Path.home(),
                                     env=child_environment(state), stdin=subprocess.PIPE,
                                     stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            write_status(state, phase, pid=child.pid)
            print("Native executor started without a display; connection and dot access require external verification.", flush=True)
            sel = selectors.DefaultSelector()
            sel.register(child.stderr, selectors.EVENT_READ)
            sel.register(child.stdout, selectors.EVENT_READ)
            started, buffers = time.monotonic(), {}
            while not stopping:
                if startup_timeout is not None and phase == "running_unverified" and time.monotonic() - started > startup_timeout:
                    phase = "readiness_timeout"
                    break
                for key, _ in sel.select(0.25):
                    data = os.read(key.fileobj.fileno(), 8192)
                    if not data:
                        tail = buffers.pop(key.fd, b"")
                        if classify_log(tail.decode("utf-8", errors="replace")) == "access_denied":
                            phase, stopping = "access_denied", True
                        sel.unregister(key.fileobj)
                        continue
                    buffered = (buffers.get(key.fd, b"") + data)[-65536:]
                    while b"\n" in buffered:
                        line, buffered = buffered.split(b"\n", 1)
                        event = classify_log(line.decode("utf-8", errors="replace"))
                        if event == "access_denied":
                            phase = event
                            stopping = True
                            break
                        if event == "transport_ready" and phase == "running_unverified":
                            phase = event
                            write_status(state, phase, pid=child.pid)
                            print("Native executor reported transport readiness; dot access still requires verification.", flush=True)
                    buffers[key.fd] = buffered
                if child.poll() is not None and not sel.get_map():
                    break
            if phase == "access_denied":
                print("Access denied. Stopped without retrying or changing transport identity.", flush=True)
                result = 77
            elif stopping:
                phase, result = "stopped", 0
            elif phase == "readiness_timeout":
                print("Readiness was not confirmed within the startup timeout; stopped without retrying.", flush=True)
                result = 75
            else:
                phase, result = "exited", child.returncode or 0
            sel.close()
        finally:
            if child is not None:
                stop_child(child)
            write_status(state, phase, exit_code=result)
            for sig, handler in previous.items():
                signal.signal(sig, handler)
        return result


def inspect_status(state: Path = STATE, declared: dict | None = None) -> dict:
    result = {"computer": socket.gethostname(), "enrollment": "pending", "dot_access": "not_verified"}
    try:
        private_path(state, True)
        private_path(state / "auth.json")
        result["credential_file"] = "present_with_expected_permissions"
        load_enrollment(state, declared=declared)
        result["enrollment"] = "local_configuration_present_not_server_verified"
    except SetupError as exc:
        result["blocker"] = str(exc)
    path = state / "runtime-status.json"
    if path.exists():
        private_path(path)
        value = json.loads(path.read_text())
        # State may be stale after power loss. Never equate it with live connectivity.
        result["last_run"] = {k: value[k] for k in ("phase", "updated_at_unix", "exit_code") if k in value}
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["status", "check", "dry-run", "run"])
    parser.add_argument("--environment-id", help="Existing server-issued computer ID; never registers a new computer")
    parser.add_argument("--host", help="Host authorized for the declared environment ID")
    args = parser.parse_args()
    if bool(args.environment_id) != bool(args.host):
        parser.error("--environment-id and --host must be supplied together")
    declared = None
    if args.environment_id:
        declared = {"schema_version": SCHEMA, "environment_id": args.environment_id,
                    "registry_url": REGISTRY, "issued_for_host": args.host,
                    "enrollment_source": "Host-specific declarative configuration for the existing granted identity"}
    try:
        if args.action == "status":
            print(json.dumps(inspect_status(declared=declared), indent=2))
        elif args.action == "check":
            preflight(declared=declared)
            print("Local prerequisites passed. Server enrollment and dot access are not verified by this check.")
        elif args.action == "dry-run":
            print(json.dumps(command(load_enrollment(declared=declared)), indent=2))
        else:
            return supervise(declared=declared)
        return 0
    except (SetupError, OSError, ValueError) as exc:
        print(f"Not started: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
