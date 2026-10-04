"""Exercise the real SOPS/age path with independent temporary identities."""
from pathlib import Path
import os
import pwd
import sys
import tempfile
from types import SimpleNamespace
from unittest.mock import patch

sys.path.insert(0, sys.argv[1])
import deployment
from nixosctl import Error, run

with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    owner = root / 'owner.agekey'
    stranger = root / 'stranger.agekey'
    host = root / 'host'
    for key in (owner, stranger):
        run(['age-keygen', '-o', key])
    run(['ssh-keygen', '-q', '-t', 'ed25519', '-N', '', '-f', host])
    owner_recipient = run(['age-keygen', '-y', owner], capture=True)
    host_recipient = run(['ssh-to-age'], capture=True, input=host.with_suffix('.pub').read_text())
    payload = {'dhilipsiva': {'hashedPassword': 'test fixture, not a password hash'},
               'ups': {'monitorPassword': 'test fixture, not a UPS password'}}
    cipher = deployment.encrypt_recipients(payload, [owner_recipient, host_recipient])
    assert 'test fixture' not in cipher
    host_identity = run(['ssh-to-age', '-private-key', '-i', host], capture=True)
    for identity in (owner.read_text(), host_identity):
        assert deployment.decrypt_identity(cipher, identity) == payload
    try:
        deployment.decrypt_identity(cipher, stranger.read_text())
    except Error:
        pass
    else:
        raise AssertionError('An unrelated identity decrypted the host secret')
    repository = root / 'repository'
    (repository / 'secrets').mkdir(parents=True)
    (repository / '.sops.yaml').write_text('creation_rules:\n# BEGIN thinkpad\n# END thinkpad\n')
    home = root / 'home'
    home.mkdir()
    actual = pwd.getpwuid(os.getuid())
    account = SimpleNamespace(pw_dir=str(home), pw_uid=os.getuid(), pw_gid=os.getgid())
    repo = SimpleNamespace(path=repository, owner=actual.pw_name)
    cfg = {'requiredSecrets': ['dhilipsiva/hashedPassword']}
    with patch.object(deployment, 'STATE', root / 'state'), \
         patch.object(deployment, 'HOST_KEY', host), \
         patch.object(deployment.pwd, 'getpwnam', return_value=account), \
         patch.object(deployment, 'shadow_hash', return_value='test fixture, not a password hash'):
        deployment.prepare_credentials(repo, 'thinkpad', cfg)
        first = (repository / 'secrets/thinkpad.yaml').read_text()
        deployment.prepare_credentials(repo, 'thinkpad', cfg)
        assert first == (repository / 'secrets/thinkpad.yaml').read_text()
        assert 'test fixture' not in first
        assert 'ups:' not in first
        assert host_recipient in first
        assert deployment.decrypt_identity(first, host_identity) == {'dhilipsiva': payload['dhilipsiva']}
print('Owner/host decryption passed; unrelated identity rejected; values stayed encrypted.')
