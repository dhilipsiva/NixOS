#!/usr/bin/env python3
"""Check encrypted file structure; --prepared also rejects enrollment placeholders."""
import argparse
from pathlib import Path
import re

VM = 'age10hwn77a4vpj33s9u9j8u698lwmgv0g8trd2x5hk24zt5a0fnvsss6dj8mg'
PLACEHOLDER = 'age1aqnq0cm7j0zhlwsge72za09s8m0sh2sh2gucpaudaypkfsetu97sy68cqw'
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('repo', type=Path)
parser.add_argument('--prepared', action='store_true')
args = parser.parse_args()
for path in (args.repo / 'secrets').glob('*.yaml'):
    text = path.read_text()
    recipients = re.findall(r'recipient: (age1[a-z0-9]+)', text)
    if not recipients or 'sops:' not in text:
        raise SystemExit(f'{path.name}: not an age-encrypted SOPS document')
    if path.name != 'vm-test.yaml':
        if VM in recipients:
            raise SystemExit(f'{path.name}: disposable VM recipient in real secrets')
        if args.prepared and (PLACEHOLDER in recipients or len(recipients) < 2):
            raise SystemExit(f'{path.name}: owner and real host enrollment is required')
        if PLACEHOLDER in recipients:
            print(f'{path.name}: enrollment pending; staging remains blocked')
    fields = ['hashedPassword']
    if path.name in ('desktop.yaml', 'vm-test.yaml') or re.search(r'^ups:', text, re.M):
        fields.append('monitorPassword')
    for field in fields:
        if not re.search(r'^\s+' + field + r': ENC\[AES256_GCM,', text, re.M):
            raise SystemExit(f'{path.name}: {field} is not encrypted')
for path in args.repo.rglob('*.nix'):
    if '.git' in path.parts:
        continue
    text = path.read_text()
    if re.search(r'hashedPassword\s*=', text):
        raise SystemExit(f'{path}: inline password hash is forbidden')
print('Encrypted-file structure and recipient isolation checks passed.')
