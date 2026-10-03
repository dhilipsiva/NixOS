"""Two-machine Git failure tests: no unpublished or unverified deployment source."""
import importlib.util
from pathlib import Path
import os
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, sys.argv.pop(1))
import nixosctl as ctl
import deployment


class GitWorkflowTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.root = Path(self.directory.name)
        self.bare = self.root / 'origin.git'
        self.git(self.root, 'init', '--bare', '--initial-branch=master', str(self.bare))
        self.desktop = self.root / 'desktop'
        self.laptop = self.root / 'laptop'
        self.git(self.root, 'clone', str(self.bare), str(self.desktop))
        self.configure(self.desktop)
        self.commit(self.desktop, 'initial')
        self.git(self.desktop, 'push', '-u', 'origin', 'master')
        self.git(self.root, 'clone', str(self.bare), str(self.laptop))
        self.configure(self.laptop)
        self.repo = ctl.Repository(self.desktop)

    def tearDown(self):
        self.directory.cleanup()

    def git(self, directory, *args):
        return subprocess.check_output(['git', '-C', str(directory), *args],
                                       text=True, stderr=subprocess.DEVNULL).strip()

    def configure(self, directory):
        self.git(directory, 'config', 'user.name', 'Workflow test')
        self.git(directory, 'config', 'user.email', 'test@invalid')
        self.git(directory, 'config', 'commit.gpgsign', 'false')

    def commit(self, directory, text):
        (directory / 'configuration').write_text(text)
        self.git(directory, 'add', 'configuration')
        self.git(directory, 'commit', '-m', text)
        return self.git(directory, 'rev-parse', 'HEAD')

    def remote(self):
        return self.git(self.bare, 'rev-parse', 'master')

    def test_two_clones_sync_only_fast_forward(self):
        revision = self.commit(self.laptop, 'laptop change')
        self.git(self.laptop, 'push', 'origin', 'master')
        self.assertEqual(self.repo.sync(), revision)
        self.assertEqual(self.repo.require_published(), revision)

    def test_dirty_checkout_preserved(self):
        (self.desktop / 'configuration').write_text('uncommitted work')
        with self.assertRaises(ctl.Error):
            self.repo.sync()
        self.assertEqual((self.desktop / 'configuration').read_text(), 'uncommitted work')

    def test_diverged_checkout_preserved(self):
        local = self.commit(self.desktop, 'desktop work')
        self.commit(self.laptop, 'laptop work')
        self.git(self.laptop, 'push', 'origin', 'master')
        with self.assertRaises(ctl.Error):
            self.repo.sync()
        self.assertEqual(self.repo.head(), local)

    def test_offline_remote_prevents_publication_and_staging(self):
        self.git(self.desktop, 'remote', 'set-url', 'origin', str(self.root / 'missing'))
        for action in [self.repo.sync, self.repo.publish, self.repo.require_published]:
            with self.assertRaises(ctl.Error):
                action()

    def test_failed_build_never_publishes(self):
        before = self.remote()
        self.commit(self.desktop, 'broken configuration')
        with patch.object(self.repo, 'check', side_effect=ctl.Error('build failed')):
            with self.assertRaises(ctl.Error):
                self.repo.publish()
        self.assertEqual(self.remote(), before)
        with self.assertRaises(ctl.Error):
            self.repo.require_published()

    def test_rejected_push_never_becomes_stageable(self):
        before = self.remote()
        self.commit(self.desktop, 'candidate')
        hook = self.bare / 'hooks/pre-receive'
        hook.write_text('#!/bin/sh\nexit 1\n')
        hook.chmod(0o755)
        with patch.object(self.repo, 'check'):
            with self.assertRaises(ctl.Error):
                self.repo.publish()
        self.assertEqual(self.remote(), before)
        with self.assertRaises(ctl.Error):
            self.repo.require_published()

    def test_remote_advancing_during_build_rejects_push(self):
        self.commit(self.desktop, 'candidate')
        def concurrent_change(_):
            self.commit(self.laptop, 'published while building')
            self.git(self.laptop, 'push', 'origin', 'master')
        with patch.object(self.repo, 'check', side_effect=concurrent_change):
            with self.assertRaises(ctl.Error):
                self.repo.publish()
        self.assertNotEqual(self.remote(), self.repo.head())

    def test_unpublished_stage_stops_before_credentials_or_efi(self):
        self.commit(self.desktop, 'unpublished')
        with patch.object(deployment, 'state_dir'), patch.object(deployment, 'verify_credentials') as credentials:
            with self.assertRaises(ctl.Error):
                deployment.stage(self.repo, 'desktop', {})
            credentials.assert_not_called()

    def test_successful_publish_is_exact_revision(self):
        revision = self.commit(self.desktop, 'verified')
        with patch.object(self.repo, 'check') as check:
            self.repo.publish()
            check.assert_called_once()
        self.assertEqual(self.remote(), revision)
        self.assertEqual(self.repo.require_published(), revision)

    def test_staging_rechecks_the_built_hardware_not_cached_configuration(self):
        cfg = {'owner': self.repo.owner, 'repository': str(self.desktop), 'branch': 'master',
               'remote': str(self.bare), 'boardName': 'wrong board from a newly synced commit', 'secureBoot': True}
        with patch.object(deployment, 'state_dir'), patch.object(deployment, 'verify_credentials'), \
             patch.object(deployment, 'verify_boot_trust'), \
             patch.object(self.repo, 'check', return_value=({'desktop': cfg}, {'desktop': '/unused'})), \
             patch.object(deployment, 'verify_hardware', side_effect=ctl.Error('hardware mismatch')) as hardware, \
             patch.object(deployment, 'protect_recovery') as recovery:
            with self.assertRaises(ctl.Error):
                deployment.stage(self.repo, 'desktop', {'boardName': 'previously cached board'})
            hardware.assert_called_once_with(cfg)
            recovery.assert_not_called()


class FirmwareTests(unittest.TestCase):
    def test_signature_list_retains_old_and_new_certificates(self):
        import struct
        def entry(payload):
            size = 16 + len(payload)
            return b't' * 16 + struct.pack('<III', 28 + size, 0, size) + b'o' * 16 + payload
        original = entry(b'original vendor')
        appended = original + entry(b'local signing key')
        self.assertTrue(deployment.signatures(original).issubset(deployment.signatures(appended)))
        self.assertFalse(deployment.signatures(original).issubset(deployment.signatures(entry(b'local signing key'))))
        for malformed in [b'x', b'x' * 28, appended[:-1]]:
            with self.assertRaises(ctl.Error):
                deployment.signatures(malformed)


class HomeBackupTests(unittest.TestCase):
    def test_home_manager_collision_probe_does_not_move_files(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / 'config.toml'
            source.write_text('original')
            helper = Path(ctl.__file__).with_name('backup-home-file.py')
            result = subprocess.run([sys.executable, helper], cwd=directory,
                                    check=True, capture_output=True, text=True)
            self.assertEqual(result.stdout.strip(), 'unique-file backup')
            self.assertEqual(result.stderr, '')
            self.assertEqual(source.read_text(), 'original')
            self.assertEqual(list(Path(directory).iterdir()), [source])

    def test_repeated_collisions_keep_both_originals(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / 'config.toml'
            helper = Path(ctl.__file__).with_name('backup-home-file.py')
            for contents in ['first original', 'second original']:
                source.write_text(contents)
                subprocess.run([sys.executable, helper, source], check=True, stdout=subprocess.DEVNULL)
                self.assertFalse(source.exists())
            saved = sorted(path.read_text() for path in Path(directory).glob('config.toml.before-nixos-*/config.toml'))
            self.assertEqual(saved, ['first original', 'second original'])


if __name__ == '__main__':
    unittest.main()
