import contextlib
import io
import json
import os
from pathlib import Path
import signal
import socket
import stat
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import dot_executor as g


class ExecutorTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.state = self.root / "state"
        self.state.mkdir(mode=0o700)
        self.auth = self.state / "auth.json"
        self.auth.write_text('{"test_only":true}')
        self.auth.chmod(0o600)
        self.enrollment = {"schema_version": 1, "environment_id": "env-server-issued-fixture",
                           "registry_url": g.REGISTRY, "issued_for_host": socket.gethostname(),
                           "enrollment_source": "Offline test fixture, never use remotely"}

    def save(self, value=None):
        path = self.state / "enrollment.json"
        path.write_text(json.dumps(self.enrollment if value is None else value))
        path.chmod(0o600)
        return path

    def fake_codex(self, body):
        path = self.root / "fake_codex"
        path.write_text(f"#!{sys.executable}\nimport sys,time,signal\n"
                        "if sys.argv[1:3] == ['login', 'status']:\n"
                        " print('Logged in using ChatGPT'); sys.exit(0)\n" + body)
        path.chmod(0o700)
        return path

    def test_pending_enrollment(self):
        with self.assertRaisesRegex(g.SetupError, "Enrollment is pending"):
            g.load_enrollment(self.state)

    def test_pending_never_invokes_cli(self):
        with patch.object(g.subprocess, "run") as run:
            with self.assertRaises(g.SetupError):
                g.preflight(self.state, Path(sys.executable))
        run.assert_not_called()

    def test_enrollment_valid(self):
        self.save()
        self.assertEqual(g.load_enrollment(self.state), self.enrollment)

    def test_host_mismatch(self):
        self.save()
        with self.assertRaisesRegex(g.SetupError, "different computer"):
            g.load_enrollment(self.state, hostname="other-host")

    def test_registry_restricted(self):
        for url in ["http://localhost", "https://example.com", g.REGISTRY + "/", "https://user:secret@codex-cloud-environments.chatgpt.com/api"]:
            with self.subTest(url=url):
                self.save({**self.enrollment, "registry_url": url})
                with self.assertRaisesRegex(g.SetupError, "Registry"):
                    g.load_enrollment(self.state)

    def test_invalid_ids(self):
        for value in [None, socket.gethostname(), socket.gethostname() + "-executor", "../other", "env?token=x", "a\n--help", "x" * 257]:
            with self.subTest(value=value):
                self.save({**self.enrollment, "environment_id": value})
                with self.assertRaises(g.SetupError):
                    g.load_enrollment(self.state)

    def test_independent_host_identities(self):
        for host in ("gaia", "comet", "cove"):
            with self.subTest(host=host):
                record = {**self.enrollment, "issued_for_host": host,
                          "environment_id": f"env-issued-{host}-fixture"}
                self.save(record)
                self.assertEqual(g.load_enrollment(self.state, hostname=host, declared=record), record)
                with self.assertRaisesRegex(g.SetupError, "different computer"):
                    g.load_enrollment(self.state, hostname="another-host", declared=record)
                for placeholder in (host, host + "-executor"):
                    self.save({**record, "environment_id": placeholder})
                    with self.assertRaisesRegex(g.SetupError, "display name"):
                        g.load_enrollment(self.state, hostname=host)

    def test_unknown_fields_rejected(self):
        self.save({**self.enrollment, "access_token": "secret-test"})
        with self.assertRaisesRegex(g.SetupError, "schema"):
            g.load_enrollment(self.state)

    def test_world_readable_rejected_without_fixing(self):
        path = self.save()
        path.chmod(0o644)
        with self.assertRaisesRegex(g.SetupError, "mode 600"):
            g.load_enrollment(self.state)
        self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o644)

    def test_symlink_rejected(self):
        path = self.save()
        target = self.root / "saved"
        path.rename(target)
        path.symlink_to(target)
        with self.assertRaises(g.SetupError):
            g.load_enrollment(self.state)

    def test_auth_not_read_by_status(self):
        self.auth.write_text("not JSON and never a token to parse")
        status = g.inspect_status(self.state)
        self.assertEqual(status["credential_file"], "present_with_expected_permissions")
        self.assertNotIn("never a token", json.dumps(status))

    def test_child_env_has_no_borrowed_auth_or_desktop_identity(self):
        with patch.dict(os.environ, {"CODEX_ACCESS_TOKEN": "secret", "CODEX_INTERNAL_ORIGINATOR_OVERRIDE": "desktop",
                                    "OPENAI_API_KEY": "secret", "HTTPS_PROXY": "https://normal.proxy"}):
            env = g.child_environment(self.state)
        self.assertNotIn("CODEX_ACCESS_TOKEN", env)
        self.assertNotIn("OPENAI_API_KEY", env)
        self.assertNotIn("CODEX_INTERNAL_ORIGINATOR_OVERRIDE", env)
        self.assertNotIn("CODEX_EXEC_SERVER_EXIT_ON_STDIN_CLOSE", env)
        self.assertEqual(env["CODEX_HOME"], str(self.state))
        self.assertEqual(env["HTTPS_PROXY"], "https://normal.proxy")

    def test_command_has_no_network_or_sandbox_bypass(self):
        cmd = g.command(self.enrollment)
        self.assertIn("--exit-on-stdin-close", cmd)
        self.assertNotIn("--listen", cmd)
        self.assertNotIn("--dangerously-bypass-approvals-and-sandbox", cmd)
        self.assertNotIn("--use-agent-identity-auth", cmd)
        self.assertIn(self.enrollment["environment_id"], cmd)

    def test_classifies_structured_readiness(self):
        for line in ['noise_event="rendezvous_connection" noise_outcome="ok"',
                     '{"fields":{"noise_event":"rendezvous_connection","noise_outcome":"ok"}}']:
            self.assertEqual(g.classify_log(line), "transport_ready")
        self.assertIsNone(g.classify_log('noise_event="registration" noise_outcome="ok"'))

    def test_denial_detection(self):
        for line in ["HTTP 403", "HTTP/1.1 401", "status:403", "Forbidden", "Cloudflare error code: 1010"]:
            self.assertEqual(g.classify_log(line), "access_denied")
        self.assertIsNone(g.classify_log("processed 403 requests"))

    def test_colored_native_transport_diagnostics(self):
        line = ('Noise executor connected to rendezvous '
                '\x1b[3mnoise_event\x1b[0m\x1b[2m=\x1b[0m"rendezvous_connection" '
                '\x1b[3mnoise_outcome\x1b[0m\x1b[2m=\x1b[0m"ok"')
        self.assertEqual(g.classify_log(line), "transport_ready")
        self.assertEqual(g.classify_log('HTTP \x1b[31m403\x1b[0m'), "access_denied")

    def test_status_permissions_and_no_connectivity_claim(self):
        g.write_status(self.state, "transport_ready", pid=123)
        path = self.state / "runtime-status.json"
        self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o600)
        value = g.inspect_status(self.state)
        self.assertEqual(value["dot_access"], "not_verified")
        self.assertNotIn("pid", value["last_run"])

    def test_access_denial_stops_without_retry_or_raw_log(self):
        self.save()
        cli = self.fake_codex("print('HTTP 403 secret-test-token',file=sys.stderr,flush=True)\ntime.sleep(20)\n")
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            result = g.supervise(self.state, cli, startup_timeout=2)
        self.assertEqual(result, 77)
        self.assertNotIn("secret-test-token", output.getvalue())
        self.assertNotIn("secret-test-token", (self.state / "runtime-status.json").read_text())
        self.assertEqual(json.loads((self.state / "runtime-status.json").read_text())["phase"], "access_denied")

    def test_fast_denial_without_newline(self):
        self.save()
        cli = self.fake_codex("sys.stderr.write('HTTP 403 secret'); sys.stderr.flush(); sys.exit(1)\n")
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(g.supervise(self.state, cli, startup_timeout=2), 77)

    def test_startup_timeout(self):
        self.save()
        cli = self.fake_codex("time.sleep(20)\n")
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(g.supervise(self.state, cli, startup_timeout=0.05), 75)

    def test_ready_then_child_exit(self):
        self.save()
        cli = self.fake_codex("print('noise_event=\\\"rendezvous_connection\\\" noise_outcome=\\\"ok\\\"', file=sys.stderr, flush=True)\ntime.sleep(.05)\n")
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            self.assertEqual(g.supervise(self.state, cli, startup_timeout=2), 0)
        self.assertIn("reported transport readiness", output.getvalue())
        self.assertEqual(json.loads((self.state / "runtime-status.json").read_text())["dot_access"], "not_verified")

    def test_existing_lock_blocks_second_process(self):
        self.save()
        cli = self.fake_codex("raise AssertionError('must not start')\n")
        with open(self.state / "supervisor.lock", "w") as lock:
            g.fcntl.flock(lock, g.fcntl.LOCK_EX | g.fcntl.LOCK_NB)
            with self.assertRaisesRegex(g.SetupError, "already running"):
                g.supervise(self.state, cli)

    def test_json_readiness_on_stdout(self):
        self.save()
        cli = self.fake_codex("print('{\"fields\":{\"noise_event\":\"rendezvous_connection\",\"noise_outcome\":\"ok\"}}',flush=True)\ntime.sleep(.05)\n")
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            self.assertEqual(g.supervise(self.state, cli, startup_timeout=2), 0)
        self.assertIn("reported transport readiness", output.getvalue())

    def test_supervisor_never_reads_auth_contents(self):
        self.save()
        cli = self.fake_codex("time.sleep(.05)\n")
        original = Path.read_text
        def guarded(path, *args, **kwargs):
            if path == self.auth:
                raise AssertionError("Supervisor must leave authentication to native Codex")
            return original(path, *args, **kwargs)
        with patch.object(Path, "read_text", guarded), contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(g.supervise(self.state, cli), 0)

    def test_default_does_not_claim_readiness_from_process_liveness(self):
        import inspect
        self.assertIsNone(inspect.signature(g.supervise).parameters["startup_timeout"].default)
        self.save()
        cli = self.fake_codex("time.sleep(.05)\n")
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            self.assertEqual(g.supervise(self.state, cli), 0)
        self.assertNotIn("reported transport readiness", output.getvalue())

    def test_headless_environment_does_not_inherit_display(self):
        with patch.dict(os.environ, {"DISPLAY": ":73", "WAYLAND_DISPLAY": "wayland-0", "XAUTHORITY": "/tmp/test"}):
            env = g.child_environment(self.state)
        for key in ("DISPLAY", "WAYLAND_DISPLAY", "XAUTHORITY"):
            self.assertNotIn(key, env)

    def test_declared_identity_works_without_recreating_private_state(self):
        self.assertEqual(g.load_enrollment(self.state, declared=self.enrollment), self.enrollment)
        self.assertFalse((self.state / "enrollment.json").exists())

    def test_declared_identity_must_match_existing_private_identity(self):
        self.save()
        for key, value in [("environment_id", "different-issued-id"), ("issued_for_host", "other-host"),
                           ("registry_url", "https://example.invalid")]:
            with self.subTest(key=key), self.assertRaisesRegex(g.SetupError, "identity differ"):
                g.load_enrollment(self.state, declared={**self.enrollment, key: value})
        self.assertEqual(json.loads((self.state / "enrollment.json").read_text()), self.enrollment)

    def test_declared_identity_rejects_wrong_host_without_private_file(self):
        with self.assertRaisesRegex(g.SetupError, "different computer"):
            g.load_enrollment(self.state, declared={**self.enrollment, "issued_for_host": "other-host"})

    def test_declared_identity_still_requires_existing_private_login(self):
        self.auth.unlink()
        with patch.object(g.subprocess, "run") as run, self.assertRaisesRegex(g.SetupError, "Missing auth.json"):
            g.preflight(self.state, Path(sys.executable), self.enrollment)
        run.assert_not_called()

    def test_declared_identity_is_used_by_native_child(self):
        cli = self.fake_codex("time.sleep(.05)\n")
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(g.supervise(self.state, cli, declared=self.enrollment), 0)
        self.assertFalse((self.state / "enrollment.json").exists())

    def test_structured_numeric_http_denial(self):
        for record in [{"fields": {"status": 403}}, {"fields": {"status_code": 401}},
                       {"http_status": "403"}, {"fields": {"http_status_code": "401"}}]:
            with self.subTest(record=record):
                self.assertEqual(g.classify_log(json.dumps(record)), "access_denied")
        for record in [{"fields": {"requests_processed": 403}}, {"fields": {"status": 429}},
                       {"fields": {"status": "connected"}}]:
            self.assertIsNone(g.classify_log(json.dumps(record)))


if __name__ == "__main__":
    unittest.main()
