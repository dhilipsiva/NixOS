"""Local privileged preparation. Never enroll firmware keys or reboot."""
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import pwd
import secrets
import shutil
import struct
import subprocess
import tempfile

from nixosctl import Error, run

STATE = Path('/var/lib/nixos-deployment')
EFI = Path('/sys/firmware/efi/efivars')
VM_RECIPIENT = 'age10hwn77a4vpj33s9u9j8u698lwmgv0g8trd2x5hk24zt5a0fnvsss6dj8mg'
PLACEHOLDER = 'age1aqnq0cm7j0zhlwsge72za09s8m0sh2sh2gucpaudaypkfsetu97sy68cqw'
HOST_KEY = Path('/etc/ssh/ssh_host_ed25519_key')
DB_CERT = Path('/var/lib/sbctl/keys/db/db.pem')


def now():
    return datetime.now(timezone.utc).isoformat()


def state_dir():
    STATE.mkdir(mode=0o700, parents=True, exist_ok=True)
    os.chmod(STATE, 0o700)


def save_json(path, value):
    path = Path(path)
    temporary = path.with_suffix(path.suffix + '.new')
    with open(temporary, 'w') as output:
        os.chmod(temporary, 0o600)
        json.dump(value, output, indent=2)
        output.write('\n')
        output.flush()
        os.fsync(output.fileno())
    temporary.replace(path)


def verify_hardware(cfg):
    if Path('/sys/class/dmi/id/board_name').read_text().strip() != cfg['boardName']:
        raise Error('Motherboard does not match this host. Refusing to use another machine\'s configuration.')
    for target, expected, fs_type in [('/', cfg['rootDevice'], cfg['rootFsType']),
                                      ('/boot', cfg['bootDevice'], 'vfat')]:
        actual = run(['findmnt', '--noheadings', '--output', 'UUID,FSTYPE', '--mountpoint', target], capture=True).split()
        if len(actual) != 2 or expected != '/dev/disk/by-uuid/' + actual[0] or fs_type != actual[1]:
            raise Error(f'{target} filesystem/UUID does not match the selected host.')
    for name, expected in cfg.get('luksDevices', {}).items():
        mapping = Path('/dev/mapper') / name
        device = run(['cryptsetup', 'status', mapping], capture=True)
        backing = next((line.split(':', 1)[1].strip() for line in device.splitlines()
                        if line.strip().startswith('device:')), None)
        if not backing or Path(backing).resolve() != Path(expected).resolve():
            raise Error(f'Encrypted mapping {name} does not match this host.')
        if name == 'root':
            root = run(['findmnt', '--noheadings', '--output', 'SOURCE', '--mountpoint', '/'], capture=True)
            if Path(root).resolve() != mapping.resolve():
                raise Error('The root filesystem is not using the preserved encrypted mapping.')


def boot_mode(cfg):
    mode = cfg.get('bootMode', 'lanzaboote' if cfg['secureBoot'] else 'unsupported')
    if mode not in ('lanzaboote', 'systemd-boot') or cfg['secureBoot'] != (mode == 'lanzaboote'):
        raise Error('Unsupported or inconsistent boot policy.')
    return mode


def hardware_identity(cfg):
    return {name: cfg.get(name, {}) for name in ('boardName', 'rootDevice', 'rootFsType', 'bootDevice', 'luksDevices')}


def verify_boot_policy(cfg):
    mode = boot_mode(cfg)
    record_path = STATE / 'boot-prepared.json'
    if not record_path.exists():
        raise Error('Run prepare-boot for this host before staging.')
    record = json.loads(record_path.read_text())
    if record.get('bootMode', 'lanzaboote') != mode:
        raise Error('Boot mode differs from the locally prepared recovery policy.')
    if 'hardware' in record and record['hardware'] != hardware_identity(cfg):
        raise Error('Hardware/encryption policy changed since boot preparation.')
    if mode == 'lanzaboote':
        verify_boot_trust()
    else:
        if var('SecureBoot') != b'\x00':
            raise Error('The prepared unsigned systemd-boot installation requires Secure Boot to remain disabled.')
        for name in record['firmwareVariables']:
            expected = (Path(record['backup']) / (name + '.esl')).read_bytes()
            if var(name) != expected:
                raise Error(f'Firmware variable {name} changed since boot preparation.')


def var(name):
    files = list(EFI.glob(name + '-*'))
    if len(files) != 1:
        raise Error(f'Cannot uniquely read firmware variable {name}.')
    return files[0].read_bytes()[4:]  # efivarfs prepends the attribute word.


def signatures(blob):
    """Parse EFI_SIGNATURE_LIST entries, preserving type, owner and signature."""
    result = set()
    while blob:
        if len(blob) < 28:
            raise Error('Malformed EFI signature list.')
        kind = blob[:16]
        size, header, item = struct.unpack_from('<III', blob, 16)
        start = 28 + header
        if item < 16 or size < start or size > len(blob) or (size-start) % item:
            raise Error('Malformed EFI signature list sizes.')
        for offset in range(start, size, item):
            result.add((kind, blob[offset:offset+item]))
        blob = blob[size:]
    return result


def cert_der():
    return subprocess.check_output(['openssl', 'x509', '-in', str(DB_CERT), '-outform', 'DER'])


def verify_boot_trust():
    if var('SecureBoot') != b'\x01' or var('SetupMode') != b'\x00':
        raise Error('Secure Boot must be enabled in user mode; do not clear the firmware keys.')
    record_path = STATE / 'boot-prepared.json'
    if not record_path.exists():
        raise Error('Run prepare-boot first, check Windows recovery, then append the public db certificate in firmware.')
    record = json.loads(record_path.read_text())
    der = cert_der()
    if hashlib.sha256(der).hexdigest() != record['certificateSHA256']:
        raise Error('Signing certificate changed since boot preparation.')
    if not any(signature[16:] == der for _, signature in signatures(var('db'))):
        raise Error('The local signing certificate is not enrolled in firmware db. Append it; keep all existing keys.')
    for name in ['PK', 'KEK', 'db', 'dbx']:
        before = (Path(record['backup']) / (name + '.esl')).read_bytes()
        if not signatures(before).issubset(signatures(var(name))):
            raise Error(f'Existing {name} trust entries were removed. Restore/review firmware trust before staging.')


def protect_recovery(owner):
    roots = Path('/nix/var/nix/gcroots')
    roots.mkdir(parents=True, exist_ok=True)
    recovery = roots / 'nixos-recovery-before-migration'
    if not recovery.exists():
        run(['nix-store', '--add-root', recovery, '--realise', Path('/run/current-system').resolve()])
    # Retain existing standalone HM/profile roots across the initial migration.
    home = Path(pwd.getpwnam(owner).pw_dir)
    paths = [home / '.nix-profile', home / '.local/state/nix/profiles/home-manager',
             home / '.config/fish/config.fish', home / '.config/hypr/hyprland.conf']
    for index, source in enumerate(paths):
        resolved = str(source.resolve())
        root = roots / f'nixos-home-before-migration-{index}'
        if resolved.startswith('/nix/store/') and Path(resolved).exists() and not root.exists():
            store_path = '/' + '/'.join(Path(resolved).parts[1:4])
            run(['nix-store', '--add-root', root, '--realise', store_path])
    return str(recovery.resolve())


def secret_environment(identity):
    # SOPS reads only the explicitly provided identity for verification, not a
    # user's other identities or ssh-agent. Key text is never an argument/file.
    return {'SOPS_AGE_KEY': identity, 'SOPS_AGE_KEY_FILE': '/dev/null',
            'SOPS_AGE_SSH_PRIVATE_KEY_FILE': '/dev/null', 'SOPS_AGE_KEY_CMD': None}


def decrypt_host(path):
    identity = run(['ssh-to-age', '-private-key', '-i', HOST_KEY], capture=True)
    return decrypt_identity(path.read_text(), identity)


def decrypt_identity(ciphertext, identity):
    plain = run(['sops', 'decrypt', '--input-type', 'yaml', '--output-type', 'json', '/dev/stdin'],
                capture=True, env=secret_environment(identity), input=ciphertext)
    return json.loads(plain)


def encrypt_recipients(payload, recipients):
    return run(['sops', '--config', '/dev/null', 'encrypt', '--input-type', 'json', '--output-type', 'yaml',
                '--age', ','.join(recipients), '/dev/stdin'], capture=True, input=json.dumps(payload)) + '\n'


def shadow_hash(owner):
    for line in Path('/etc/shadow').read_text().splitlines():
        fields = line.split(':')
        if fields[0] == owner:
            if not fields[1].startswith('$'):
                raise Error('Installed account has no usable password hash; preserve/recover it locally before proceeding.')
            return fields[1]
    raise Error('Installed user was not found in shadow.')


def required_secrets(cfg):
    return cfg.get('requiredSecrets', ['dhilipsiva/hashedPassword', 'ups/monitorPassword'])


def validate_credentials(plain, password_hash, cfg):
    if plain.get('dhilipsiva', {}).get('hashedPassword') != password_hash:
        raise Error('Decrypted password does not match the installed password; resolve locally before staging.')
    for name in required_secrets(cfg):
        value = plain
        for component in name.split('/'):
            value = value.get(component) if isinstance(value, dict) else None
        if not isinstance(value, str) or not value:
            raise Error(f'Required encrypted credential is missing: {name}.')
        if name == 'ups/monitorPassword' and len(value) < 32:
            raise Error('UPS secret has not been prepared.')


def verify_credentials(repo, host, source=None, cfg=None):
    source = (source or repo.path) / 'secrets' / (host + '.yaml')
    ciphertext = source.read_text()
    if PLACEHOLDER in ciphertext or VM_RECIPIENT in ciphertext:
        raise Error('Host secrets still contain a placeholder/disposable recipient. Run prepare-credentials.')
    plain = decrypt_host(source)
    validate_credentials(plain, shadow_hash(repo.owner), cfg or {})
    print('Host identity decrypts the preserved login and all required credentials.')


def prepare_credentials(repo, host, cfg):
    state_dir()
    account = pwd.getpwnam(repo.owner)
    key_dir = Path(account.pw_dir) / '.config/sops/age'
    run(['mkdir', '-p', key_dir], owner=repo.owner)
    run(['chmod', '700', key_dir], owner=repo.owner)
    owner_key = key_dir / 'keys.txt'
    if not owner_key.exists():
        run(['age-keygen', '-o', owner_key], owner=repo.owner)
    run(['chmod', '600', owner_key], owner=repo.owner)
    owner_recipient = run(['age-keygen', '-y', owner_key], owner=repo.owner, capture=True)
    HOST_KEY.parent.mkdir(mode=0o755, parents=True, exist_ok=True)
    if not HOST_KEY.exists():
        run(['ssh-keygen', '-q', '-t', 'ed25519', '-N', '', '-f', HOST_KEY])
    os.chmod(HOST_KEY, 0o600)
    public = run(['ssh-keygen', '-y', '-f', HOST_KEY], capture=True)
    host_recipient = run(['ssh-to-age'], capture=True, input=public + '\n')
    if owner_recipient == host_recipient or VM_RECIPIENT in (owner_recipient, host_recipient):
        raise Error('Owner, host and VM identities must be independent.')
    source = repo.path / 'secrets' / (host + '.yaml')
    marker = STATE / (host + '-credentials.json')
    if marker.exists():
        verify_credentials(repo, host, cfg=cfg)
        print('Credentials already prepared; identities and passwords were retained.')
        return
    payload = {'dhilipsiva': {'hashedPassword': shadow_hash(repo.owner)}}
    if 'ups/monitorPassword' in required_secrets(cfg):
        payload['ups'] = {'monitorPassword': secrets.token_urlsafe(48)}
    validate_credentials(payload, shadow_hash(repo.owner), cfg)
    ciphertext = encrypt_recipients(payload, [owner_recipient, host_recipient])
    backup = STATE / ('credentials-' + datetime.now().strftime('%Y%m%dT%H%M%S'))
    backup.mkdir(mode=0o700)
    if source.exists():
        shutil.copy2(source, backup / source.name)
    shutil.copy2(repo.path / '.sops.yaml', backup / 'sops-config.yaml')
    # Verify both recipients from memory before writing any new ciphertext.
    host_identity = run(['ssh-to-age', '-private-key', '-i', HOST_KEY], capture=True)
    for identity in (owner_key.read_text(), host_identity):
        if decrypt_identity(ciphertext, identity) != payload:
            raise Error('Recipient verification failed.')
    # Per-host rules avoid sharing host private keys when another machine is added.
    config_file = repo.path / '.sops.yaml'
    config_text = config_file.read_text()
    start = f'# BEGIN {host}\n'
    end = f'# END {host}\n'
    if start not in config_text or end not in config_text:
        raise Error('Add a host-specific creation rule block before preparing this host.')
    before, remaining = config_text.split(start, 1)
    _, after = remaining.split(end, 1)
    rule = f'  - path_regex: secrets/{host}\\.yaml$\n    age: {owner_recipient},{host_recipient}\n'
    for path, content in [(source, ciphertext), (config_file, before + start + rule + end + after)]:
        temporary = path.with_suffix(path.suffix + '.new')
        temporary.write_text(content)
        os.chown(temporary, account.pw_uid, account.pw_gid)
        os.chmod(temporary, 0o644)
        temporary.replace(path)
    verify_credentials(repo, host, cfg=cfg)
    save_json(marker, {'host': host, 'ownerRecipient': owner_recipient,
                       'hostRecipient': host_recipient, 'preparedAt': now()})
    print('Encrypted credentials are ready. Commit and publish .sops.yaml and the host ciphertext.')
    print(f'Back up the owner identity securely outside this machine: {owner_key}')


def prepare_boot(cfg, windows_status=None):
    state_dir()
    mode = boot_mode(cfg)
    if (STATE / 'boot-prepared.json').exists():
        verify_boot_policy(cfg)
        print('Boot preparation already exists; existing keys/backups were retained.')
        return
    if mode == 'systemd-boot':
        if var('SecureBoot') != b'\x00':
            raise Error('Preserve the existing disabled Secure Boot state for this unsigned installation.')
        status = run(['bootctl', 'status', '--no-pager'], capture=True)
        if 'Product: systemd-boot' not in status:
            raise Error('The running bootloader is not systemd-boot.')
        recovery = protect_recovery(cfg['owner'])
        backup = STATE / ('boot-backup-' + datetime.now().strftime('%Y%m%dT%H%M%S'))
        backup.mkdir(mode=0o700)
        shutil.copytree('/boot', backup / 'esp')
        (backup / 'bootctl.txt').write_text(status)
        variables = ['SecureBoot', 'SetupMode']
        variables += [name for name in ['PK', 'KEK', 'db', 'dbx'] if list(EFI.glob(name + '-*'))]
        for name in variables:
            (backup / (name + '.esl')).write_bytes(var(name))
        save_json(STATE / 'boot-prepared.json', {
            'bootMode': mode, 'hardware': hardware_identity(cfg), 'backup': str(backup),
            'recoverySystem': recovery, 'firmwareVariables': variables, 'preparedAt': now(),
        })
        print('Systemd-boot recovery is protected and the ESP is backed up. Firmware trust is unchanged.')
        return
    if windows_status not in ('unencrypted', 'recovery-key-backed-up'):
        raise Error('Signed boot preparation requires --windows-status after checking Windows recovery.')
    if var('SecureBoot') != b'\x01' or var('SetupMode') != b'\x00':
        raise Error('Keep Secure Boot enabled and existing firmware keys installed.')
    backup = STATE / ('boot-backup-' + datetime.now().strftime('%Y%m%dT%H%M%S'))
    backup.mkdir(mode=0o700)
    shutil.copytree('/boot', backup / 'esp')
    for name in ['PK', 'KEK', 'db', 'dbx']:
        (backup / (name + '.esl')).write_bytes(var(name))
    (backup / 'bootctl.txt').write_text(run(['bootctl', 'status', '--no-pager'], capture=True))
    # Inventory signatures, including the current bootloader, before changing it.
    with open(backup / 'efi-signatures.txt', 'w') as report:
        for path in sorted(Path('/boot').rglob('*')):
            if path.is_file() and path.suffix.lower() == '.efi':
                report.write(str(path) + '\n')
                report.flush()
                subprocess.run(['sbverify', '--list', str(path)], stdout=report, stderr=report)
    if not DB_CERT.exists():
        run(['sbctl', 'create-keys'])
    run(['openssl', 'x509', '-in', DB_CERT, '-outform', 'DER', '-out', STATE / 'nixos-db.cer'])
    # A public certificate on the Linux ESP is convenient for firmware Append Key.
    # This does not change trust, loader defaults or the Windows disk.
    shutil.copy2(STATE / 'nixos-db.cer', '/boot/nixos-db.cer')
    recovery = protect_recovery(cfg['owner'])
    save_json(STATE / 'boot-prepared.json', {
        'backup': str(backup), 'certificateSHA256': hashlib.sha256(cert_der()).hexdigest(),
        'recoverySystem': recovery, 'preparedAt': now(),
        'windowsStatus': windows_status,
        'bootMode': mode, 'hardware': hardware_identity(cfg),
    })
    print(f'ESP, trust variables and signature inventory saved in {backup}')
    print(f'Windows readiness recorded: {windows_status}.')
    print('In MSI firmware: Authorized Signatures (db) -> Append Key -> Linux ESP /nixos-db.cer.')
    print('Keep PK, KEK, Microsoft/OEM db and dbx entries. Never clear or replace them.')
    print('No firmware keys were enrolled and no boot generation was staged.')


def recovery_entry(recovery, esp=Path('/boot'), certificate=DB_CERT,
                   private_key=Path('/var/lib/sbctl/keys/db/db.key')):
    """A self-contained signed recovery UKI, outside Lanzaboote's GC namespace."""
    target = esp / 'EFI/nixos-recovery/pre-migration.efi'
    if not target.exists():
        boot = json.loads((Path(recovery) / 'boot.json').read_text())['org.nixos.bootspec.v1']
        target.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=STATE, prefix='recovery-') as directory:
            cmdline = Path(directory) / 'cmdline'
            cmdline.write_text(' '.join(['init=' + boot['init'], *boot['kernelParams']]))
            run(['ukify', 'build', '--linux', boot['kernel'], '--initrd', boot['initrd'],
                 '--cmdline', '@' + str(cmdline), '--os-release', '@' + recovery + '/etc/os-release',
                 '--secureboot-private-key', private_key,
                 '--secureboot-certificate', certificate, '--output', target])
    run(['sbverify', '--cert', certificate, target], capture=True)
    (esp / 'loader/entries').mkdir(parents=True, exist_ok=True)
    (esp / 'loader/entries/nixos-protected-recovery.conf').write_text(
        'title NixOS (protected pre-migration recovery)\n'
        'sort-key nixos-recovery\nefi /EFI/nixos-recovery/pre-migration.efi\n')


def verify_signed_entries():
    entries = list(Path('/boot/EFI/Linux').glob('nixos-*.efi'))
    if not entries:
        raise Error('Expected a signed new generation on the Linux ESP.')
    for path in entries + [Path('/boot/EFI/systemd/systemd-bootx64.efi'),
                            Path('/boot/EFI/BOOT/BOOTX64.EFI'),
                            Path('/boot/EFI/nixos-recovery/pre-migration.efi')]:
        run(['sbverify', '--cert', DB_CERT, path], capture=True)


def file_digest(path):
    with open(path, 'rb') as source:
        return hashlib.file_digest(source, 'sha256').hexdigest()


def unsigned_recovery(recovery, esp=Path('/boot'), create=False):
    boot = json.loads((Path(recovery) / 'boot.json').read_text())['org.nixos.bootspec.v1']
    directory = esp / 'EFI/nixos-recovery'
    for name, source in [('kernel.efi', boot['kernel']), ('initrd', boot['initrd'])]:
        target = directory / name
        if create and not target.exists():
            directory.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target)
        if not target.is_file() or file_digest(target) != file_digest(source):
            raise Error('Protected recovery boot files are missing or changed.')
    entry = esp / 'loader/entries/nixos-protected-recovery.conf'
    contents = ('title NixOS (protected pre-migration recovery)\n'
                'sort-key nixos-recovery\nlinux /EFI/nixos-recovery/kernel.efi\n'
                'initrd /EFI/nixos-recovery/initrd\noptions '
                + ' '.join(['init=' + boot['init'], *boot['kernelParams']]) + '\n')
    if create and not entry.exists():
        entry.parent.mkdir(parents=True, exist_ok=True)
        entry.write_text(contents)
    if not entry.exists() or entry.read_text() != contents:
        raise Error('Protected recovery boot entry is missing or changed.')


def verify_systemd_entries(system, recovery, esp=Path('/boot')):
    boot = json.loads((Path(system) / 'boot.json').read_text())['org.nixos.bootspec.v1']
    expected_init = 'init=' + boot['init']
    for entry in (esp / 'loader/entries').glob('nixos*.conf'):
        fields = {}
        for line in entry.read_text().splitlines():
            parts = line.split(None, 1)
            if len(parts) == 2:
                fields.setdefault(parts[0], []).append(parts[1])
        if expected_init not in fields.get('options', [''])[0].split():
            continue
        for field, source in [('linux', boot['kernel']), ('initrd', boot['initrd'])]:
            targets = [(esp / value.lstrip('/')).resolve() for value in fields.get(field, [])]
            if not any(target.is_relative_to(esp.resolve()) and target.is_file()
                       and file_digest(target) == file_digest(source) for target in targets):
                raise Error('The staged boot entry does not reference the verified kernel/initrd.')
        break
    else:
        raise Error('No boot entry references the verified system.')
    for name in ['EFI/systemd/systemd-bootx64.efi', 'EFI/BOOT/BOOTX64.EFI']:
        if not (esp / name).is_file():
            raise Error('A systemd-boot loader is missing from the ESP.')
    unsigned_recovery(recovery, esp)


def verify_boot_entries(cfg, system, recovery):
    if boot_mode(cfg) == 'lanzaboote':
        verify_signed_entries()
    else:
        verify_systemd_entries(system, recovery)


def verify_esp_space(system, recovery, esp=Path('/boot')):
    required = 32 * 1024 * 1024
    systems = [system]
    if not (esp / 'loader/entries/nixos-protected-recovery.conf').exists():
        systems.append(recovery)
    for candidate in systems:
        boot = json.loads((Path(candidate) / 'boot.json').read_text())['org.nixos.bootspec.v1']
        required += sum(Path(boot[name]).stat().st_size for name in ['kernel', 'initrd'])
    if shutil.disk_usage(esp).free < required:
        raise Error('Insufficient ESP space for the new generation and protected recovery; nothing was staged.')


def verify_flatpak(cfg):
    apps = cfg.get('flatpakApps', [])
    if not apps:
        return
    for app in apps:
        run(['flatpak', 'info', '--user', '--show-ref', app], owner=cfg['owner'], capture=True)
    driver = 'org.freedesktop.Platform.GL.nvidia-' + cfg['nvidiaVersion'].replace('.', '-')
    run(['flatpak', 'info', '--user', '--show-ref', driver], owner=cfg['owner'], capture=True)
    print('Preserved user Flatpak applications and matching NVIDIA graphics runtime are installed.')


def stage(repo, host, cfg):
    state_dir()
    revision = repo.require_published()
    verify_credentials(repo, host, cfg=cfg)
    verify_boot_policy(cfg)
    with repo.snapshot(revision) as candidate:
        hosts, builds = repo.check(candidate)
        system = builds[host]
        # A user may edit during the build. Stage only the verified published
        # snapshot, and stop if the shared checkout/remote changed meanwhile.
        if repo.require_published() != revision:
            raise Error('Repository changed during the build; nothing was staged.')
        # A preceding sync can change host configuration. Validate the evaluated
        # snapshot we actually built, never facts cached before that sync.
        cfg = hosts[host]
        if (cfg['owner'] != repo.owner or Path(cfg['repository']) != repo.path
                or cfg['branch'] != repo.branch or repo.git('remote', 'get-url', 'origin') != cfg['remote']):
            raise Error('Built host changed its repository/owner/branch; resolve the migration explicitly.')
        verify_hardware(cfg)
        verify_credentials(repo, host, source=candidate, cfg=cfg)
        verify_boot_policy(cfg)
        verify_flatpak(cfg)
        old = str(Path('/nix/var/nix/profiles/system').resolve())
        recovery = protect_recovery(repo.owner)
        verify_esp_space(system, recovery)
        closure_diff(system)
        backup = STATE / ('stage-' + datetime.now().strftime('%Y%m%dT%H%M%S'))
        backup.mkdir(mode=0o700)
        shutil.copytree('/boot', backup / 'esp')
        try:
            run(['nix-env', '--profile', '/nix/var/nix/profiles/system', '--set', system])
            # This is the boot-only activation used by nixos-rebuild boot, using
            # the exact already verified store output, with no live activation.
            run([Path(system) / 'bin/switch-to-configuration', 'boot'])
            if boot_mode(cfg) == 'lanzaboote':
                recovery_entry(recovery)
            else:
                unsigned_recovery(recovery, create=True)
            verify_boot_entries(cfg, system, recovery)
        except BaseException:
            run(['nix-env', '--profile', '/nix/var/nix/profiles/system', '--set', old])
            verify_hardware(cfg)
            run(['rsync', '-rt', '--delete', str(backup / 'esp') + '/', '/boot/'])
            run(['sync'])
            print('Staging failed; the previous system profile and Linux ESP were restored.')
            raise
        save_json(STATE / 'staged.json', {'revision': revision, 'system': system,
                                        'host': host, 'bootMode': boot_mode(cfg),
                                        'recoverySystem': recovery, 'stagedAt': now()})
        print(f'Staged {revision}: {system}. Reboot manually when ready.')


def closure_diff(system):
    """Show what the candidate changes against the running system; never blocks."""
    current = Path('/run/current-system')
    nvd = shutil.which('nvd')
    if nvd and current.exists() and current.resolve() != Path(system):
        print('Closure changes from the running system:')
        subprocess.run([nvd, 'diff', str(current), system], check=False)


def require_acceptance():
    marker = STATE / 'accepted.json'
    if not marker.exists():
        raise Error('Updates/GC are gated until the first verified boot and physical acceptance.')
    receipt = json.loads(marker.read_text())
    recovery = Path(receipt['recoverySystem'])
    root = Path('/nix/var/nix/gcroots/nixos-recovery-before-migration')
    if not recovery.exists() or root.resolve() != recovery:
        raise Error('The protected recovery generation is missing. Cleanup/updates remain gated.')
    if receipt.get('bootMode', 'lanzaboote') == 'systemd-boot':
        unsigned_recovery(str(recovery))
    return receipt


def accept(repo, host, cfg):
    staged = json.loads((STATE / 'staged.json').read_text())
    if staged['host'] != host or Path('/run/current-system').resolve() != Path(staged['system']):
        raise Error('Reboot into the staged generation and complete the physical checks first.')
    verify_credentials(repo, host, cfg=cfg)
    verify_boot_policy(cfg)
    verify_boot_entries(cfg, staged['system'], staged['recoverySystem'])
    verify_flatpak(cfg)
    save_json(STATE / 'accepted.json', dict(staged, acceptedAt=now()))
    print('Accepted this deployment. The configured update/GC timers may now run.')


def cleanup():
    require_acceptance()
    # Nix-managed generations older than 30 days only. The explicit recovery GC
    # root remains protected independently of profile age and ESP rotation.
    run(['nix-collect-garbage', '--delete-older-than', '30d'])
    print('Collected unused Nix store paths with 30-day generation retention. Recovery roots remain.')


def setup_publisher(repo):
    if os.geteuid() == 0:
        raise Error('Run setup-publisher as the checkout owner.')
    home = Path(pwd.getpwnam(repo.owner).pw_dir)
    key = home / '.ssh/nixos-update'
    key.parent.mkdir(mode=0o700, exist_ok=True)
    if not key.exists():
        run(['ssh-keygen', '-q', '-t', 'ed25519', '-N', '', '-C', 'NixOS repository update publisher', '-f', key])
    os.chmod(key, 0o600)
    # Do not weaken host authentication or populate known_hosts with unverified scans.
    import shlex
    command = shlex.join(['ssh', '-i', str(key), '-o', 'IdentitiesOnly=yes',
                         '-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=yes',
                         '-o', 'ConnectTimeout=15', '-o', 'ServerAliveInterval=15',
                         '-o', 'ServerAliveCountMax=2'])
    repo.git('config', '--local', 'core.sshCommand', command)
    repo.git('config', '--local', 'credential.helper', '')
    repo.git('remote', 'set-url', '--push', 'origin', 'git@github.com:dhilipsiva/NixOS.git')
    print('Add this public key as a write-enabled deploy key for dhilipsiva/NixOS:')
    print(key.with_suffix('.pub').read_text().strip())
    print('Verify GitHub\'s published SSH host fingerprints in ~/.ssh/known_hosts before the first push.')
