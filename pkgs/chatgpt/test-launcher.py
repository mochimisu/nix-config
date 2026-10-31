from pathlib import Path
import runpy
import sys
import tempfile
import unittest

configure = runpy.run_path(sys.argv.pop(1))['configure']


class LauncherTest(unittest.TestCase):
    def test_options(self):
        with tempfile.TemporaryDirectory() as directory:
            env = {'XDG_CONFIG_HOME': directory}
            args, result = configure(['codex://thread/test'], env)
            self.assertEqual(args, ['codex://thread/test'])
            self.assertEqual(result['CHATGPT_START_MINIMIZED'], '0')
            path = Path(directory) / 'chatgpt-nix/window-options.json'
            path.parent.mkdir()
            path.write_text('{"startMinimized":true,"disableMini":true}')
            _, result = configure([], env)
            self.assertEqual(result['CHATGPT_START_MINIMIZED'], '1')
            self.assertEqual(result['CHATGPT_DISABLE_MINI'], '1')
            args, result = configure(['--show-window', '--enable-mini', '--ozone-platform=wayland'], env)
            self.assertEqual(args, ['--ozone-platform=wayland'])
            self.assertEqual(result['CHATGPT_START_MINIMIZED'], '0')
            self.assertEqual(result['CHATGPT_DISABLE_MINI'], '0')
            _, result = configure([], {**env, 'CHATGPT_DISABLE_MINI': '0'})
            self.assertEqual(result['CHATGPT_DISABLE_MINI'], '0')
            args, _ = configure(['--', '--disable-mini'], env)
            self.assertEqual(args, ['--', '--disable-mini'])
            for invalid in ['[]', '{"disableMini":"false"}', '{"typo":true}', '{']:
                path.write_text(invalid)
                with self.assertRaises(ValueError):
                    configure([], env)


unittest.main()
