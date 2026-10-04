import importlib.util
from contextlib import nullcontext
import json
from pathlib import Path
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

sys.path.insert(0, sys.argv.pop(1))
import deployment
from nixosctl import Error

spec = importlib.util.spec_from_file_location('migration', Path(deployment.__file__).with_name('migrate-home.py'))
migration = importlib.util.module_from_spec(spec)
spec.loader.exec_module(migration)


class BootPolicyTests(unittest.TestCase):
    def test_boot_modes_are_explicit_and_consistent(self):
        self.assertEqual(deployment.boot_mode({'secureBoot': True}), 'lanzaboote')
        self.assertEqual(deployment.boot_mode({'secureBoot': False, 'bootMode': 'systemd-boot'}), 'systemd-boot')
        for cfg in [{'secureBoot': False}, {'secureBoot': False, 'bootMode': 'lanzaboote'},
                    {'secureBoot': True, 'bootMode': 'systemd-boot'}]:
            with self.assertRaises(Error):
                deployment.boot_mode(cfg)

    def test_prepared_signed_host_cannot_be_downgraded(self):
        with tempfile.TemporaryDirectory() as directory:
            state = Path(directory)
            (state / 'boot-prepared.json').write_text('{}')
            with patch.object(deployment, 'STATE', state), patch.object(deployment, 'verify_boot_trust') as trust:
                deployment.verify_boot_policy({'secureBoot': True})
                trust.assert_called_once()
                with self.assertRaises(Error):
                    deployment.verify_boot_policy({'secureBoot': False, 'bootMode': 'systemd-boot'})

    def test_unsigned_policy_retains_firmware_and_hardware(self):
        with tempfile.TemporaryDirectory() as directory:
            state = Path(directory)
            cfg = {'secureBoot': False, 'bootMode': 'systemd-boot', 'luksDevices': {'root': '/original'}}
            record = {'bootMode': 'systemd-boot', 'hardware': deployment.hardware_identity(cfg),
                      'backup': str(state), 'firmwareVariables': ['db']}
            (state / 'boot-prepared.json').write_text(json.dumps(record))
            (state / 'db.esl').write_bytes(b'original trust')
            with patch.object(deployment, 'STATE', state), patch.object(deployment, 'var') as variable:
                variable.side_effect = lambda name: b'\x00' if name == 'SecureBoot' else b'original trust'
                deployment.verify_boot_policy(cfg)
                with self.assertRaises(Error):
                    deployment.verify_boot_policy(dict(cfg, luksDevices={}))
                variable.return_value = b'\x01'
                variable.side_effect = None
                with self.assertRaises(Error):
                    deployment.verify_boot_policy(cfg)
                variable.side_effect = lambda name: b'\x00' if name == 'SecureBoot' else b'changed trust'
                with self.assertRaises(Error):
                    deployment.verify_boot_policy(cfg)

    def test_encrypted_mapping_mismatch_is_rejected(self):
        cfg = {'boardName': 'thinkpad', 'rootDevice': '/dev/disk/by-uuid/root-uuid',
               'rootFsType': 'ext4', 'bootDevice': '/dev/disk/by-uuid/boot-uuid',
               'luksDevices': {'root': '/expected'}}
        with patch.object(Path, 'read_text', return_value='thinkpad'), \
             patch.object(deployment, 'run', side_effect=['root-uuid ext4', 'boot-uuid vfat', ' device: /wrong']):
            with self.assertRaisesRegex(Error, 'Encrypted mapping'):
                deployment.verify_hardware(cfg)


class RecoveryTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.system = self.root / 'system'
        self.system.mkdir()
        for name in ['kernel', 'initrd']:
            (self.system / name).write_bytes(name.encode())
        self.boot = {'kernel': str(self.system / 'kernel'), 'initrd': str(self.system / 'initrd'),
                     'init': str(self.system / 'init'), 'kernelParams': ['root=fstab', 'loglevel=4']}
        (self.system / 'boot.json').write_text(json.dumps({'org.nixos.bootspec.v1': self.boot}))
        self.esp = self.root / 'esp'
        self.esp.mkdir()

    def test_recovery_preserves_kernel_initrd_and_unlock_command(self):
        deployment.unsigned_recovery(str(self.system), self.esp, create=True)
        deployment.unsigned_recovery(str(self.system), self.esp, create=True)
        entry = self.esp / 'loader/entries/nixos-protected-recovery.conf'
        self.assertIn('init=' + self.boot['init'] + ' root=fstab loglevel=4', entry.read_text())
        (self.esp / 'EFI/nixos-recovery/initrd').write_bytes(b'changed')
        with self.assertRaises(Error):
            deployment.unsigned_recovery(str(self.system), self.esp, create=True)

    def test_boot_entry_checks_content_not_just_existence(self):
        deployment.unsigned_recovery(str(self.system), self.esp, create=True)
        for name in ['EFI/systemd/systemd-bootx64.efi', 'EFI/BOOT/BOOTX64.EFI']:
            target = self.esp / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(b'loader')
        deployment.verify_systemd_entries(str(self.system), str(self.system), self.esp)
        entry = self.esp / 'loader/entries/nixos-protected-recovery.conf'
        entry.write_text(entry.read_text().replace(self.boot['init'], '/wrong/init'))
        with self.assertRaises(Error):
            deployment.verify_systemd_entries(str(self.system), str(self.system), self.esp)

    def test_low_esp_space_blocks_staging(self):
        with patch.object(deployment.shutil, 'disk_usage', return_value=SimpleNamespace(free=1)):
            with self.assertRaisesRegex(Error, 'Insufficient ESP'):
                deployment.verify_esp_space(str(self.system), str(self.system), self.esp)


class CredentialTests(unittest.TestCase):
    def test_laptop_needs_only_its_password(self):
        payload = {'dhilipsiva': {'hashedPassword': 'fixture'}}
        cfg = {'requiredSecrets': ['dhilipsiva/hashedPassword']}
        deployment.validate_credentials(payload, 'fixture', cfg)
        with self.assertRaises(Error):
            deployment.validate_credentials(payload, 'changed password', cfg)
        with self.assertRaises(Error):
            deployment.validate_credentials(payload, 'fixture', {})
        payload['ups'] = {'monitorPassword': 'fixture' * 8}
        deployment.validate_credentials(payload, 'fixture', {})


class StageRollbackTests(unittest.TestCase):
    def test_failed_boot_install_restores_profile_and_esp(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            cfg = {'owner': 'fixture', 'repository': str(root), 'branch': 'master',
                   'remote': 'remote', 'secureBoot': False, 'bootMode': 'systemd-boot'}
            repo = SimpleNamespace(path=root, owner='fixture', branch='master',
                                   require_published=lambda: 'revision', snapshot=lambda revision: nullcontext(root),
                                   check=lambda candidate: ({'thinkpad': cfg}, {'thinkpad': str(root / 'system')}),
                                   git=lambda *args: 'remote')
            commands = []

            def execute(args, **kwargs):
                command = [str(arg) for arg in args]
                commands.append(command)
                if command[0].endswith('/switch-to-configuration'):
                    raise Error('boot installation failed')

            with patch.object(deployment, 'STATE', root / 'state'), \
                 patch.object(deployment, 'verify_credentials'), patch.object(deployment, 'verify_hardware'), \
                 patch.object(deployment, 'verify_boot_policy'), patch.object(deployment, 'verify_flatpak'), \
                 patch.object(deployment, 'verify_esp_space'), \
                 patch.object(deployment, 'protect_recovery', return_value='/protected'), \
                 patch.object(deployment.shutil, 'copytree'), patch.object(deployment, 'run', side_effect=execute):
                with self.assertRaisesRegex(Error, 'boot installation failed'):
                    deployment.stage(repo, 'thinkpad', cfg)
            self.assertEqual(sum(command[0] == 'nix-env' for command in commands), 2)
            self.assertTrue(any(command[:3] == ['rsync', '-rt', '--delete'] for command in commands))
            self.assertEqual(commands[-1], ['sync'])
            self.assertFalse((root / 'state/staged.json').exists())


class HomeMigrationTests(unittest.TestCase):
    def test_preserves_obs_private_data_and_existing_unmanaged_files(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            source = home / '.files/.config'
            source.mkdir(parents=True)
            obs = source / 'obs-studio'
            obs.mkdir()
            (obs / 'profile.ini').write_text('original OBS profile')
            (source / 'git').mkdir()
            (source / 'git/config').write_text('legacy managed configuration')
            (source / 'app.ini').write_text('legacy unmanaged configuration')
            destination = home / '.config'
            destination.mkdir()
            (destination / 'app.ini').write_text('current unmanaged configuration')
            (destination / 'obs-studio').mkdir()
            (destination / 'obs-studio/profile.ini').write_text('previous destination')
            migration.migrate(home, source, [Path('.config/git/config')])
            self.assertEqual((destination / 'obs-studio/profile.ini').read_text(), 'original OBS profile')
            self.assertEqual((destination / 'app.ini').read_text(), 'current unmanaged configuration')
            self.assertFalse((destination / 'git/config').exists())
            self.assertEqual((obs / 'profile.ini').read_text(), 'original OBS profile')
            marker = home / '.local/state/nixosctl/home-migration/completed.json'
            record = json.loads(marker.read_text())
            self.assertEqual((Path(record['backup']) / 'obs-studio-before-migration/profile.ini').read_text(),
                             'previous destination')
            (destination / 'obs-studio/profile.ini').write_text('new recording settings')
            migration.migrate(home, source, [])
            self.assertEqual((destination / 'obs-studio/profile.ini').read_text(), 'new recording settings')
            self.assertEqual((destination / 'obs-studio/profile.ini').stat().st_mode & 0o077, 0)


if __name__ == '__main__':
    unittest.main()
