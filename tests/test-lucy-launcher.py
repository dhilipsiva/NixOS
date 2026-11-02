import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('launcher', sys.argv.pop(1))
launcher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(launcher)


class LauncherMigration(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.data = self.root / 'data'
        self.state = self.root / 'state'
        self.entry = self.data / 'applications/lucy.desktop'
        self.entry.parent.mkdir(parents=True)
        self.original = ('[Desktop Entry]\nType=Application\nName=Ask Lucy\n'
                         f'Exec={self.root}/.nix-profile/bin/lucy ui\n')

    def retire(self):
        return launcher.retire(self.root, self.data, self.state)

    def test_legacy_override_is_preserved_outside_applications_and_retry_is_inert(self):
        self.entry.write_text(self.original)
        backup = self.retire()
        self.assertFalse(self.entry.exists())
        self.assertTrue(backup.is_relative_to(self.state))
        self.assertEqual(backup.read_text(), self.original)
        self.assertIsNone(self.retire())
        self.assertEqual(len(list(self.state.rglob('lucy.desktop'))), 1)

    def test_custom_launchers_are_preserved(self):
        for content in [self.original.replace(' ui', ' ui --files %F'),
                        self.original.replace('.nix-profile/bin', 'custom/bin'),
                        self.original.replace('Ask Lucy', 'My custom launcher'),
                        'not a desktop entry']:
            with self.subTest(content=content):
                self.entry.write_text(content)
                self.assertIsNone(self.retire())
                self.assertEqual(self.entry.read_text(), content)

    def test_managed_symlink_is_untouched(self):
        target = self.root / 'managed.desktop'
        target.write_text(self.original)
        self.entry.symlink_to(target)
        self.assertIsNone(self.retire())
        self.assertTrue(self.entry.is_symlink())
        self.assertEqual(target.read_text(), self.original)


if __name__ == '__main__':
    unittest.main()
