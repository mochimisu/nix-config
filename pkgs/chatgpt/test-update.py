"""Offline updater regression checks; no real pins or network are touched."""
import base64
from contextlib import redirect_stdout
import importlib.util
import io
import os
from pathlib import Path
import re
import tempfile
import unittest
from unittest.mock import patch

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('updater', HERE / 'update.py')
updater = importlib.util.module_from_spec(spec)
spec.loader.exec_module(updater)


class UpdateTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.old_cwd = Path.cwd()
        os.chdir(self.tmp.name)
        self.addCleanup(os.chdir, self.old_cwd)
        self.package = Path('pkgs/chatgpt/package.nix')
        self.package.parent.mkdir(parents=True)
        self.original = (HERE / 'package.nix').read_text()
        self.package.write_text(self.original)
        self.current = updater.VERSION_FIELD.search(self.original)['version']
        self.next_version = self.current + '.1'

    def index(self, version):
        def fetch(args, **kwargs):
            arch = 'amd64' if 'binary-amd64' in args[-1] else 'arm64'
            system = next(s for s, a in updater.ARCHES.items() if a == arch)
            sri = re.search(rf'{re.escape(system)} = \{{\s*arch = "[^"]+";\s*hash = "sha256-([^"]+)"', self.original)[1]
            digest = base64.b64decode(sri).hex() if version == self.current else 'ab' * 32
            return f'Package: chatgpt\nVersion: {version}\nArchitecture: {arch}\nFilename: pool/main/c/chatgpt/chatgpt_{version}_{arch}.deb\nSHA256: {digest}\n'
        return fetch

    def run_update(self, version):
        with patch.object(updater.subprocess, 'check_output', side_effect=self.index(version)), redirect_stdout(io.StringIO()):
            updater.main()

    def test_updates_only_application_and_source_hashes(self):
        self.assertIn('version = "0.15.2";', self.original)
        self.run_update(self.next_version)
        updated = self.package.read_text()
        expected = self.original.replace(f'version = "{self.current}";', f'version = "{self.next_version}";', 1)
        for system in updater.ARCHES:
            expected = re.sub(rf'({re.escape(system)} = \{{\s*arch = "[^"]+";\s*hash = ")[^"]+', lambda m: m[1] + 'sha256-' + base64.b64encode(bytes.fromhex('ab' * 32)).decode(), expected)
        self.assertEqual(updated, expected)

    def test_current_release_is_noop(self):
        self.run_update(self.current)
        self.assertEqual(self.package.read_text(), self.original)

    def test_ambiguous_application_fails_before_network(self):
        self.package.write_text(self.original + f'\n  pname = "chatgpt";\n  version = "{self.current}";\n')
        before = self.package.read_text()
        with patch.object(updater.subprocess, 'check_output') as fetch:
            with self.assertRaisesRegex(ValueError, 'exactly one pinned'):
                updater.main()
            fetch.assert_not_called()
        self.assertEqual(self.package.read_text(), before)

    def test_dependency_version_alone_is_not_application(self):
        self.package.write_text(self.original.replace('pname = "chatgpt";', 'pname = "other";'))
        with patch.object(updater.subprocess, 'check_output') as fetch:
            with self.assertRaisesRegex(ValueError, 'exactly one pinned'):
                updater.main()
            fetch.assert_not_called()


if __name__ == '__main__':
    unittest.main()
