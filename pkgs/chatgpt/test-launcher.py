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
            self.assertNotIn('CHATGPT_DISABLE_MINI', result)
            args, result = configure(['--show-window', '--enable-mini', '--ozone-platform=wayland'], env)
            self.assertEqual(args, ['--ozone-platform=wayland'])
            self.assertEqual(result['CHATGPT_START_MINIMIZED'], '0')
            self.assertNotIn('CHATGPT_DISABLE_MINI', result)
            _, result = configure([], {**env, 'CHATGPT_DISABLE_MINI': '1'})
            self.assertNotIn('CHATGPT_DISABLE_MINI', result)
            args, result = configure(['--disable-mini', '--start-minimized'], env)
            self.assertEqual(args, [])
            self.assertNotIn('CHATGPT_DISABLE_MINI', result)
            self.assertEqual(result['CHATGPT_START_MINIMIZED'], '1')
            path.write_text('{"startMinimized":true}')
            _, result = configure([], env)
            self.assertEqual(result['CHATGPT_START_MINIMIZED'], '1')
            self.assertNotIn('CHATGPT_DISABLE_MINI', result)
            args, _ = configure(['--', '--disable-mini'], env)
            self.assertEqual(args, ['--', '--disable-mini'])
            for invalid in ['[]', '{"disableMini":"false"}', '{"typo":true}', '{']:
                path.write_text(invalid)
                with self.assertRaises(ValueError):
                    configure([], env)


unittest.main()
