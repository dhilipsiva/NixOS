#!/usr/bin/env python3
"""Exercise firmware selection and failure paths without touching host firmware."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(sys.argv.pop(1)).resolve()


class RebootToWindows(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.log = self.root / 'calls'
        self.env = dict(os.environ, PATH=f'{self.root}:{os.environ["PATH"]}',
                        CALLS=str(self.log), TEST_UID='0', WRITE_STATUS='0')
        self.env['BOOT_ENTRIES'] = (
            'BootOrder: 0001,000A\n'
            'Boot0001* Linux Boot Manager\n'
            'Boot000A* Windows Boot Manager\n'
        )
        self.stub('id', 'echo "$TEST_UID"')
        self.stub('efibootmgr', '''
if [ "$#" -eq 0 ]; then
  printf '%s' "$BOOT_ENTRIES"
else
  echo "efibootmgr $*" >> "$CALLS"
  exit "$WRITE_STATUS"
fi
''')
        self.stub('systemctl', 'echo "systemctl $*" >> "$CALLS"')
        self.stub('pkexec', 'echo "pkexec $*" >> "$CALLS"; exec "$@"')

    def stub(self, name, body):
        path = self.root / name
        path.write_text(f'#!{shutil.which("bash")}\nset -euo pipefail\n{body}\n')
        path.chmod(0o755)

    def run_script(self, *args):
        return subprocess.run(['bash', str(SCRIPT), *args], env=self.env,
                              text=True, capture_output=True, check=False)

    def calls(self):
        return self.log.read_text().splitlines() if self.log.exists() else []

    def test_root_selects_windows_once_before_reboot(self):
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls(), ['efibootmgr --quiet --bootnext 000A',
                                       'systemctl reboot'])

    def test_user_authenticates_before_writing(self):
        self.env['TEST_UID'] = '1000'
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls(), ['pkexec efibootmgr --quiet --bootnext 000A',
                                       'efibootmgr --quiet --bootnext 000A',
                                       'systemctl reboot'])

    def test_missing_windows_does_not_write_or_reboot(self):
        self.env['BOOT_ENTRIES'] = 'Boot0001* Linux Boot Manager\n'
        result = self.run_script()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('nothing changed', result.stderr)
        self.assertEqual(self.calls(), [])

    def test_failed_firmware_write_does_not_reboot(self):
        self.env['WRITE_STATUS'] = '1'
        self.assertNotEqual(self.run_script().returncode, 0)
        self.assertEqual(self.calls(), ['efibootmgr --quiet --bootnext 000A'])

    def test_help_and_invalid_arguments_never_reboot(self):
        self.assertEqual(self.run_script('--help').returncode, 0)
        self.assertEqual(self.run_script('--bootnext', '0001').returncode, 2)
        self.assertEqual(self.calls(), [])


if __name__ == '__main__':
    unittest.main()
