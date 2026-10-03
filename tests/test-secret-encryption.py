"""Exercise the real SOPS/age path with independent temporary identities."""
from pathlib import Path
import sys
import tempfile

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
print('Owner/host decryption passed; unrelated identity rejected; values stayed encrypted.')
