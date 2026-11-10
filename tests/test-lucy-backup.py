import contextlib
import fcntl
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('lucy_backup', sys.argv.pop(1))
backup = importlib.util.module_from_spec(spec)
spec.loader.exec_module(backup)

# Commits made here, and by the script under test, must not depend on the machine's Git settings.
os.environ.update({'GIT_CONFIG_GLOBAL': os.devnull, 'GIT_CONFIG_NOSYSTEM': '1',
                   'GIT_AUTHOR_NAME': 'Test', 'GIT_AUTHOR_EMAIL': 'test@example.invalid',
                   'GIT_COMMITTER_NAME': 'Test', 'GIT_COMMITTER_EMAIL': 'test@example.invalid'})

# A stand-in for `lucy store backup` that writes the real layout from two fixture files. It carries
# whatever the fixtures hold, so the tests can hand the job a snapshot that breaks the list.
FAKE_LUCY = r'''#!PYTHON
import hashlib, json, os, sys, time
from pathlib import Path
args = sys.argv[1:]
assert args[:2] == ['store', 'backup'], args
root, to = Path(args[args.index('--root') + 1]), Path(args[args.index('--to') + 1])
peers = sorted(args[i + 1] for i, arg in enumerate(args) if arg == '--only-peer')
if (root / 'fake-fail').exists():
    print(json.dumps({'error': (root / 'fake-fail').read_text()}))
    sys.exit(2)
host = os.environ['LUCY_HOST']
def put(path, data):
    new = not path.exists()
    if new:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
    return new
objects, new_objects = [], 0
for record in json.loads((root / 'fake-records.json').read_text()):
    data = json.dumps(record, separators=(',', ':')).encode()
    name = hashlib.sha256(data).hexdigest()
    new_objects += put(to / 'objects' / f'{name}.json', data)
    objects.append(name)
logs, new_parts = [], 0
for log in json.loads((root / 'fake-logs.json').read_text()):
    text = ''.join(log['lines']).encode()
    name = hashlib.sha256(text).hexdigest()
    new_parts += put(to / 'parts' / f'{name}.txt', text)
    part = {'path': f'parts/{name}.txt', 'bytes': len(text), 'sha256': name}
    logs.append({'peer': log['peer'], 'archive': {'bytes': len(text), 'sha256': name, 'parts': [part]}})
body = {'format': 'lucy-memory-snapshot-v2', 'host': host, 'objects': objects,
        'replication': {'version': 2, 'logs': logs}, 'filter': {'only_peers': peers}}
if (root / 'fake-unlisted').exists():
    del body['filter']
directory = to / 'snapshots' / host
old = sorted((int(p.stem), p) for p in directory.glob('*.json') if p.stem.isdigit()) if directory.is_dir() else []
changed = not old or any(json.loads(old[-1][1].read_text()).get(key) != body[key] for key in body)
path = directory / f'{time.time_ns()}.json' if changed else old[-1][1]
if changed:
    put(path, json.dumps({**body, 'created_unix_ns': path.stem}, indent=1).encode())
print(json.dumps({'ok': True, 'snapshot': str(path), 'changed': changed, 'objects': len(objects),
                  'new_objects': new_objects, 'parts': len(logs), 'new_parts': new_parts,
                  'only_peers': peers, 'omitted_records': 0}))
'''


def git(*args, cwd=None):
    return subprocess.run(['git', *map(str, args)], cwd=cwd, check=True, capture_output=True,
                          text=True).stdout.strip()


def line(scope, identity, text='a visible message'):
    """One operation line as the canonical log writes it: JSON inside a quoted Nibli constant."""
    operation = {'id': f'actor:{identity}', 'scope': scope,
                 'payload': {'record': {'origin': 'conversation:x', 'payload': {'id': identity, 'text': text}}}}
    compact = json.dumps(operation, separators=(',', ':'))
    return f'record({json.dumps(operation["id"])}, {json.dumps(compact)}, Operation, Json).\n'


class Backup(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.data, self.state = self.root / 'data', self.root / 'state'
        self.data.mkdir()
        self.remote, self.checkout = self.root / 'remote.git', self.root / 'checkout'
        git('init', '--quiet', '--bare', '--initial-branch=main', self.remote)
        seed = self.root / 'seed'
        git('clone', '--quiet', self.remote, seed)
        (seed / 'README.md').write_text('private\n')
        git('add', 'README.md', cwd=seed)
        git('commit', '--quiet', '-m', 'Start', cwd=seed)
        git('push', '--quiet', 'origin', 'HEAD:refs/heads/main', cwd=seed)
        # Another program keeps its own branch in the same repository; the job must never touch it.
        git('push', '--quiet', 'origin', 'HEAD:refs/heads/lucy-memory', cwd=seed)
        self.memory = git('rev-parse', 'refs/heads/lucy-memory', cwd=self.remote)
        git('clone', '--quiet', '--single-branch', '--branch', 'main', self.remote, self.checkout)
        self.lucy = self.root / 'lucy'
        self.lucy.write_text(FAKE_LUCY.replace('PYTHON', sys.executable))
        self.lucy.chmod(0o700)
        self.records = [{'origin': 'conversation:["test","one"]', 'payload': {'id': 'm1', 'text': 'a visible message'}}]
        self.logs = [
            {'peer': {'name': 'kept', 'scope': 'kept-scope', 'legacy_origin': 'kept-old'}, 'lines': [line('kept-scope', 'k1')]},
            {'peer': {'name': 'local', 'scope': 'local-private', 'legacy_origin': None}, 'lines': [line('local-private', 'm1')]},
        ]
        self.notes = []
        backup.notify = lambda title, body: self.notes.append(title)
        self.seen = None
        backup.visibility = lambda remote: self.seen

    def run_backup(self, *extra, peers=('kept',), unverified=True, **changes):
        (self.data / 'fake-records.json').write_text(json.dumps(self.records))
        (self.data / 'fake-logs.json').write_text(json.dumps(self.logs))
        options = {'--state-dir': self.state, '--checkout': self.checkout, '--remote': self.remote,
                   '--host': 'host-a', '--lucy': self.lucy, '--data-dir': self.data}
        options.update({f'--{name}': value for name, value in changes.items()})
        argv = ['run'] + [str(item) for pair in options.items() for item in pair]
        for peer in peers:
            argv += ['--peer', peer]
        if unverified:
            argv.append('--allow-unverified-remote')
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            code = backup.main(argv + list(extra))
        return code, json.loads(output.getvalue().strip().splitlines()[-1])

    def head(self, where=None):
        return git('rev-parse', 'HEAD' if where else 'refs/heads/main', cwd=where or self.remote)

    def committed(self):
        return set(git('ls-files', cwd=self.checkout).splitlines())

    def add_record(self, identity, text='another visible message', origin='conversation:["test","one"]'):
        self.records.append({'origin': origin, 'payload': {'id': identity, 'text': text}})
        self.logs[1]['lines'].append(line('local-private', identity, text))

    def test_a_run_commits_what_the_manifest_names_and_pushes_main_only(self):
        stale = self.checkout / 'shared-store/objects' / ('0' * 64 + '.json')
        stale.parent.mkdir(parents=True)
        stale.write_text('{"origin":"peer:left/private.nibli"}')
        code, outcome = self.run_backup()
        self.assertEqual((code, outcome['ok'], outcome['pushed'], outcome['committed']), (0, True, True, True))
        files = self.committed()
        self.assertEqual(len([f for f in files if f.startswith('shared-store/objects/')]), 1)
        self.assertEqual(len([f for f in files if f.startswith('shared-store/parts/')]), 2)
        self.assertEqual(len([f for f in files if f.startswith('shared-store/snapshots/host-a/')]), 1)
        # A file left by an earlier attempt is neither committed nor removed.
        self.assertNotIn(str(stale.relative_to(self.checkout)), files)
        self.assertTrue(stale.exists())
        self.assertEqual(self.head(), self.head(self.checkout))
        self.assertEqual(git('rev-parse', 'refs/heads/lucy-memory', cwd=self.remote), self.memory)
        fetched = set(git('for-each-ref', '--format=%(refname)', 'refs/remotes', cwd=self.checkout).split())
        self.assertLessEqual(fetched, {'refs/remotes/origin/HEAD', 'refs/remotes/origin/main'})
        self.assertEqual(json.loads((self.state / 'backup-status.json').read_text())['failures'], 0)
        self.assertEqual(self.notes, [])

    def test_a_run_with_nothing_new_makes_no_commit(self):
        self.run_backup()
        before = self.head()
        code, outcome = self.run_backup()
        self.assertEqual((code, outcome['committed'], outcome['pushed'], outcome['changed']), (0, False, True, False))
        self.assertEqual(self.head(), before)

    def test_no_push_commits_locally_and_stops(self):
        before = self.head()
        code, outcome = self.run_backup('--no-push')
        self.assertEqual((code, outcome['ok'], outcome['committed'], outcome['pushed']), (0, True, True, False))
        self.assertEqual(self.head(), before)
        self.assertNotEqual(self.head(self.checkout), before)

    def test_a_checkout_that_is_not_at_rest_is_left_untouched(self):
        (self.checkout / 'note.txt').write_text('mine')
        code, outcome = self.run_backup()
        self.assertEqual(code, 1)
        self.assertIn('outside shared-store', outcome['error'])
        self.assertFalse((self.checkout / 'shared-store').exists())
        (self.checkout / 'note.txt').unlink()
        self.assertIn('expected repository', self.run_backup(remote=self.root / 'elsewhere.git')[1]['error'])
        git('checkout', '--quiet', '-b', 'side', cwd=self.checkout)
        self.assertIn('must be on main', self.run_backup()[1]['error'])
        self.assertFalse((self.checkout / 'shared-store').exists())
        # One notice for the whole run of failures.
        self.assertEqual(self.notes, ['Lucy backup failed'])

    def test_an_empty_peer_list_is_refused(self):
        code, outcome = self.run_backup(peers=())
        self.assertEqual(code, 1)
        self.assertIn('at least one peer', outcome['error'])
        self.assertFalse((self.checkout / 'shared-store').exists())

    def test_a_public_or_unconfirmed_destination_is_never_pushed(self):
        before = self.head()
        for seen in ('public', 'unknown', 'unverifiable'):
            self.seen = seen
            code, outcome = self.run_backup(unverified=False)
            self.assertEqual((code, outcome['pushed']), (1, False), seen)
            self.assertEqual('publicly readable' in outcome['error'], seen == 'public')
            self.assertEqual(self.head(), before, seen)
        # The snapshot is committed here and goes out once the destination is confirmed private.
        self.assertNotEqual(self.head(self.checkout), before)
        self.seen = 'private'
        code, outcome = self.run_backup(unverified=False)
        self.assertEqual((code, outcome['pushed'], outcome['committed']), (0, True, False))
        self.assertEqual(self.head(), self.head(self.checkout))
        self.assertEqual(self.notes, ['Lucy backup failed', 'Lucy backup is working again'])

    def test_another_hosts_push_is_kept_and_ours_follows_it(self):
        self.run_backup()
        other = self.root / 'other'
        git('clone', '--quiet', self.remote, other)
        theirs = other / 'shared-store/snapshots/host-b/1.json'
        theirs.parent.mkdir(parents=True)
        theirs.write_text('{}')
        git('add', '--all', cwd=other)
        git('commit', '--quiet', '-m', 'Back up host-b', cwd=other)
        git('push', '--quiet', 'origin', 'HEAD:refs/heads/main', cwd=other)
        their_commit = self.head()
        self.add_record('m2')
        code, outcome = self.run_backup()
        self.assertEqual((code, outcome['pushed']), (0, True))
        self.assertEqual(self.head(), self.head(self.checkout))
        git('merge-base', '--is-ancestor', their_commit, 'refs/heads/main', cwd=self.remote)
        self.assertIn('shared-store/snapshots/host-b/1.json', self.committed())

    def test_overlapping_runs_are_refused(self):
        self.state.mkdir()
        with open(self.state / 'backup.lock', 'w') as held:
            fcntl.flock(held, fcntl.LOCK_EX)
            code, outcome = self.run_backup()
        self.assertEqual(code, 1)
        self.assertIn('Another backup is running', outcome['error'])
        self.assertFalse((self.checkout / 'shared-store').exists())

    def test_extras_are_mirrored_but_never_keys_tokens_links_or_databases(self):
        archives = self.data / 'archives'
        (archives / 'session').mkdir(parents=True)
        (archives / 'session/visible.jsonl').write_text('a visible line\n')
        (self.state / 'notes').mkdir(parents=True)
        (self.state / 'notes/note.md').write_text('a note\n')
        for name in ('actor.key', 'api.token', 'memory.redb', 'conversations.sqlite3-wal', 'cache.remote.nibli', 'lock'):
            (archives / name).write_text('must stay')
        (archives / 'credentials').mkdir()
        (archives / 'credentials/plain.txt').write_text('must stay')
        (archives / 'linked.json').symlink_to(archives / 'session/visible.jsonl')
        (self.data / 'credentials').mkdir()
        (self.data / 'credentials/unlisted.txt').write_text('must stay')
        code, outcome = self.run_backup()
        self.assertEqual((code, outcome['extras']), (0, 2))
        extras = {f for f in self.committed() if f.startswith('shared-store/extras/')}
        self.assertEqual(extras, {'shared-store/extras/host-a/store/archives/session/visible.jsonl',
                                  'shared-store/extras/host-a/state/notes/note.md'})
        everything = b''.join(p.read_bytes() for p in (self.checkout / 'shared-store').rglob('*') if p.is_file())
        self.assertNotIn(b'must stay', everything)
        # A changed source is copied again; a removed one keeps its backup copy.
        (archives / 'session/visible.jsonl').write_text('a longer visible line\n')
        (self.state / 'notes/note.md').unlink()
        self.assertEqual(self.run_backup()[1]['extras'], 1)
        self.assertEqual({f for f in self.committed() if f.startswith('shared-store/extras/')}, extras)

    def test_a_record_or_operation_of_an_unlisted_peer_stops_the_run_before_any_commit(self):
        self.run_backup()
        before = self.head(self.checkout)
        self.add_record('s1', origin='peer:left/private.nibli')
        code, outcome = self.run_backup()
        self.assertEqual(code, 1)
        self.assertIn('outside the list', outcome['error'])
        self.assertEqual(self.head(self.checkout), before)
        self.records.pop()
        self.logs[1]['lines'].pop()
        # A record indexed under the listed peer's older name is that peer's own.
        self.add_record('k2', origin='peer:kept-old/interactions.nibli')
        self.assertEqual(self.run_backup()[0], 0)
        before = self.head(self.checkout)
        self.logs[0]['lines'].append(line('left-scope', 'x1'))
        code, outcome = self.run_backup()
        self.assertEqual(code, 1)
        self.assertIn('outside the list', outcome['error'])
        self.assertEqual(self.head(self.checkout), before)
        self.logs[0]['lines'].pop()
        self.logs.append({'peer': {'name': 'left', 'scope': 'left-scope', 'legacy_origin': None}, 'lines': []})
        self.assertIn('outside the list', self.run_backup()[1]['error'])
        self.logs.pop()
        # A snapshot made without the list is refused even when its content looks harmless.
        (self.data / 'fake-unlisted').write_text('')
        self.add_record('m4')
        before = self.head(self.checkout)
        self.assertIn('exactly the listed peers', self.run_backup()[1]['error'])
        self.assertEqual(self.head(self.checkout), before)
        (self.data / 'fake-unlisted').unlink()
        # A conversation that merely quotes those words is not an operation of that scope.
        self.add_record('m3', text='the log said \\"scope\\":\\"left-scope\\" and "scope":"left-scope"')
        self.assertEqual(self.run_backup()[0], 0)

    def test_this_hosts_own_token_or_a_credential_shape_stops_the_run(self):
        (self.data / 'credentials').mkdir()
        (self.data / 'credentials/github-memory.token').write_text('local-token-0123456789abcdef\n')
        self.add_record('t1', text='someone pasted local-token-0123456789abcdef here')
        code, outcome = self.run_backup()
        self.assertEqual(code, 1)
        self.assertIn('own keys or tokens', outcome['error'])
        self.assertNotIn('local-token', json.dumps(outcome))
        self.assertEqual(self.head(self.checkout), self.head())
        self.records.pop()
        self.logs[1]['lines'].pop()
        shaped = 'ghp_' + 'a' * 36
        self.add_record('t2', text=f'an example token {shaped}')
        code, outcome = self.run_backup()
        self.assertEqual(code, 1)
        self.assertIn('looks like a credential', outcome['error'])
        self.assertNotIn(shaped, json.dumps(outcome))
        # Read and accepted by name, the same files go through; this host's own secrets never do.
        store = self.checkout / 'shared-store'
        names = [p.name for p in store.rglob('*') if p.is_file() and shaped.encode() in p.read_bytes()]
        self.assertEqual(len(names), 2)
        (self.state / 'backup-accepted.txt').write_text('\n'.join(names) + '\n')
        self.assertEqual(self.run_backup()[0], 0)

    def test_old_manifests_are_pruned_to_seven_and_older_formats_stay(self):
        old = self.checkout / 'shared-store/snapshots/host-a/1.json'
        old.parent.mkdir(parents=True)
        old.write_text(json.dumps({'format': 'lucy-memory-snapshot-v1', 'host': 'host-a', 'objects': []}))
        git('add', '--all', cwd=self.checkout)
        git('commit', '--quiet', '-m', 'An older snapshot', cwd=self.checkout)
        git('push', '--quiet', 'origin', 'HEAD:refs/heads/main', cwd=self.checkout)
        for number in range(9):
            self.add_record(f'n{number}')
            self.assertEqual(self.run_backup()[0], 0)
        manifests = sorted(f for f in self.committed() if f.startswith('shared-store/snapshots/host-a/'))
        self.assertEqual(len(manifests), 8)
        self.assertIn('shared-store/snapshots/host-a/1.json', manifests)
        # History still holds every manifest, and no object or part was ever removed.
        added = git('log', '--no-renames', '--diff-filter=A', '--name-only', '--format=', '--',
                    'shared-store/snapshots', cwd=self.checkout)
        self.assertEqual(len(added.split()), 10)
        self.assertEqual(git('log', '--no-renames', '--diff-filter=D', '--name-only', '--format=', '--',
                             'shared-store/objects', 'shared-store/parts', cwd=self.checkout), '')

    def test_a_failed_snapshot_reports_its_reason_and_status_shows_it(self):
        (self.data / 'fake-fail').write_text('unknown peer kept; name an enrolled peer or a registered folder')
        code, outcome = self.run_backup()
        self.assertEqual(code, 1)
        self.assertIn('unknown peer kept', outcome['error'])
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            self.assertEqual(backup.main(['status', '--state-dir', str(self.state)]), 0)
        self.assertEqual(json.loads(output.getvalue())['error'], outcome['error'])


if __name__ == '__main__':
    unittest.main()
