#!/usr/bin/env python3
"""Back up Lucy's private memory into its private Git repository, adding only what is new."""
import argparse
import base64
import fcntl
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.request

KEEP = 7
MAX_FILE = 16 * 1024 * 1024
SNAPSHOT = 'lucy-memory-snapshot-v2'
STORE = 'shared-store'
# What a snapshot leaves out and only this disk holds: label -> (base, directory).
EXTRAS = {
    'store/archives': ('data', 'archives'),
    'store/pending': ('data', 'pending'),
    'store/room-imports': ('data', 'room-imports'),
    'state/pending-records': ('state', 'pending-records'),
    'state/notes': ('state', 'notes'),
}
# Never mirrored, whatever is listed above.
DENIED_PARTS = {'credentials', 'replication-v1', 'keys', '.git'}
DENIED_NAMES = re.compile(r'(\.key|\.token|\.redb|\.lock|\.sqlite3?(-wal|-shm)?)$|\.remote\.|^lock$')
# Recognisable credentials. A match stops the run; nothing is committed.
SECRETS = [re.compile(pattern) for pattern in (
    rb'gh[pousr]_[A-Za-z0-9]{36}',
    rb'github_pat_[A-Za-z0-9_]{60}',
    rb'-----BEGIN [A-Z ]*PRIVATE KEY-----',
    rb'AGE-SECRET-KEY-1[0-9A-Z]{58}',
    rb'AKIA[0-9A-Z]{16}',
    rb'nvapi-[A-Za-z0-9_-]{40}',
    rb'sk-ant-[A-Za-z0-9_-]{40}',
)]
# An operation's own scope inside a log line; the same words quoted in a message are escaped deeper.
SCOPE = re.compile(rb'(?<!\\)\\"scope\\":\\"([^"\\]+)\\"')
GITHUB = re.compile(r'git@github\.com:([A-Za-z0-9._-]+)/([A-Za-z0-9._-]+?)(?:\.git)?')


class Error(RuntimeError):
    pass


def run(args, *, cwd=None, env=None, stdin=None, timeout=None):
    """Return (exit code, stdout, stderr). Arguments never carry a secret."""
    process_env = os.environ.copy()
    process_env.update(env or {})
    try:
        result = subprocess.run([str(a) for a in args], cwd=cwd, env=process_env, input=stdin,
                                timeout=timeout, text=True, capture_output=True)
    except subprocess.TimeoutExpired as exc:
        raise Error(f'{Path(str(args[0])).name} timed out.') from exc
    except FileNotFoundError as exc:
        raise Error(f'{Path(str(args[0])).name} is not installed.') from exc
    return result.returncode, result.stdout, result.stderr


class Checkout:
    def __init__(self, path, remote, branch):
        self.path = Path(path).resolve()
        self.remote = remote
        self.branch = branch
        self.upstream = f'origin/{branch}'

    def attempt(self, *args, stdin=None):
        """Run git without prompting. The global ignore list must not hide a backup file."""
        env = {'GIT_TERMINAL_PROMPT': '0', 'GIT_ASKPASS': shutil.which('false') or 'false',
               'GIT_SSH_COMMAND': 'ssh -o BatchMode=yes -o StrictHostKeyChecking=yes -o ConnectTimeout=20'}
        code, out, _ = run(['git', '-C', self.path, '-c', 'core.excludesFile=', '-c', 'commit.gpgsign=false',
                            *args], env=env, stdin=stdin,
                           timeout=120 if args[0] in ('fetch', 'push') else 600)
        return code, out

    def git(self, *args, stdin=None):
        code, out = self.attempt(*args, stdin=stdin)
        if code:
            raise Error(f'git {args[0]} failed (exit {code}).')
        return out.rstrip('\n')

    def ok(self, *args):
        return self.attempt(*args)[0] == 0

    def status(self):
        """Every path Git does not hold as it is now, exactly as named on disk."""
        entries = self.git('status', '--porcelain', '--untracked-files=all', '-z').split('\0')
        paths = []
        while entries:
            entry = entries.pop(0)
            if len(entry) > 3:
                paths.append(entry[3:])
                if entry[0] in 'RC':
                    paths.append(entries.pop(0))
        return paths

    def tracked(self, directory):
        return set(filter(None, self.git('ls-files', '-z', '--', directory).split('\0')))

    def preflight(self):
        """Refuse a checkout that is not exactly the expected private repository at rest."""
        if not (self.path / '.git').exists() or Path(self.git('rev-parse', '--show-toplevel')) != self.path:
            raise Error('The backup checkout must be the root of its own repository.')
        if self.attempt('symbolic-ref', '--quiet', '--short', 'HEAD')[1].strip() != self.branch:
            raise Error(f'The backup checkout must be on {self.branch}.')
        urls = {self.git('remote', 'get-url', 'origin'), self.git('remote', 'get-url', '--push', 'origin')}
        if urls != {self.remote}:
            raise Error('The backup checkout does not point at the expected repository.')
        git_dir = Path(self.git('rev-parse', '--absolute-git-dir'))
        if any((git_dir / name).exists() for name in ('rebase-merge', 'rebase-apply', 'MERGE_HEAD')):
            raise Error('A rebase or merge is unfinished in the backup checkout.')
        if any(not path.startswith(f'{STORE}/') for path in self.status()):
            raise Error(f'The backup checkout has changes outside {STORE}; nothing was touched.')

    def fetch(self):
        """Fetch the one branch. Never the other refs that live in this repository."""
        return self.ok('fetch', '--no-tags', 'origin',
                       f'+refs/heads/{self.branch}:refs/remotes/{self.upstream}')

    def onto_upstream(self):
        """Put local backup commits after whatever another host pushed. Never forces."""
        if not self.ok('rev-parse', '--verify', '--quiet', self.upstream):
            return
        if self.ok('merge-base', '--is-ancestor', self.upstream, 'HEAD'):
            return
        if self.ok('merge-base', '--is-ancestor', 'HEAD', self.upstream):
            self.git('merge', '--ff-only', self.upstream)
            return
        if not self.ok('rebase', '--no-autosquash', self.upstream):
            self.attempt('rebase', '--abort')
            raise Error('Backups from another host could not be combined; the checkout was left as it was.')

    def ahead(self):
        if not self.ok('rev-parse', '--verify', '--quiet', self.upstream):
            return True
        return self.git('rev-list', '--count', f'{self.upstream}..HEAD') != '0'

    def head(self):
        return self.git('rev-parse', 'HEAD')


def visibility(remote):
    """Whether anyone can read the destination: an anonymous request must be refused."""
    match = GITHUB.fullmatch(remote)
    if not match:
        return 'unverifiable'
    request = urllib.request.Request(f'https://github.com/{match[1]}/{match[2]}', method='HEAD',
                                     headers={'User-Agent': 'lucy-backup'})
    try:
        with urllib.request.urlopen(request, timeout=15):
            return 'public'
    except urllib.error.HTTPError as error:
        return 'private' if error.code == 404 else 'unknown'
    except (urllib.error.URLError, TimeoutError, OSError):
        return 'unknown'


def snapshot(lucy, destination, peers, host, data_dir):
    """Ask Lucy for a snapshot that carries only the listed peers."""
    args = [lucy, 'store', 'backup', '--root', data_dir, '--to', destination]
    for peer in peers:
        args += ['--only-peer', peer]
    code, out, _ = run(args, env={'LUCY_HOST': host}, timeout=900)
    try:
        report = json.loads(out)
    except ValueError:
        report = {}
    if code or report.get('ok') is not True:
        reason = report.get('error') if isinstance(report.get('error'), str) else f'exit {code}'
        raise Error(f'lucy store backup failed: {reason[:200]}')
    return report


def mirror(sources, destination):
    """Copy changed regular files. Links, keys, tokens and databases are never copied; nothing is deleted."""
    present = []
    for label, source in sources:
        if source.is_symlink() or not source.is_dir():
            continue
        for root, directories, names in os.walk(source, followlinks=False):
            directories[:] = sorted(name for name in directories
                                    if name not in DENIED_PARTS and not (Path(root) / name).is_symlink())
            for name in sorted(names):
                path = Path(root) / name
                relative = path.relative_to(source)
                if (path.is_symlink() or not path.is_file() or DENIED_NAMES.search(name)
                        or DENIED_PARTS & set(relative.parts) or path.stat().st_size > MAX_FILE):
                    continue
                target = destination / label / relative
                data = path.read_bytes()
                if not target.is_file() or target.read_bytes() != data:
                    target.parent.mkdir(parents=True, exist_ok=True)
                    partial = target.with_name(f'.{target.name}.partial')
                    partial.write_bytes(data)
                    partial.replace(target)
                present.append(target)
    return present


def known_secrets(data_dir, config_dir):
    """The exact bytes of this host's own keys and tokens, held in memory only for comparison."""
    files = [data_dir / 'replication-v1/actor.key', data_dir / 'replication-v1/cursor.key']
    for directory in (data_dir / 'credentials', config_dir / 'keys'):
        if directory.is_dir() and not directory.is_symlink():
            files += sorted(path for path in directory.iterdir() if path.is_file())
    secrets = set()
    for path in files:
        if path.is_file() and not path.is_symlink():
            raw = path.read_bytes()
            secrets |= {raw, raw.strip(), base64.b64encode(raw)}
    return [secret for secret in secrets if len(secret) >= 16]


def verify(checkout, manifest_path, peers, host, fresh, secrets, accepted):
    """Check what this run is about to commit. Returns every path the manifest names."""
    store = checkout.path / STORE
    try:
        manifest = json.loads(manifest_path.read_text())
    except (OSError, ValueError) as exc:
        raise Error('The new manifest cannot be read.') from exc
    if manifest_path.parent != store / 'snapshots' / host or manifest.get('host') != host:
        raise Error('The snapshot was written for another host.')
    if manifest.get('format') != SNAPSHOT or manifest.get('filter') != {'only_peers': sorted(peers)}:
        raise Error('The snapshot does not carry exactly the listed peers.')
    logs = manifest.get('replication', {}).get('logs', [])
    names = {log['peer']['name'] for log in logs}
    if not names <= set(peers) | {'local'}:
        raise Error('The snapshot holds the log of a peer outside the list.')
    admitted = set(peers) | {log['peer'].get('legacy_origin') for log in logs} - {None}
    scopes = {log['peer']['scope'].encode() for log in logs}
    objects = {f'{STORE}/objects/{name}.json' for name in manifest.get('objects', [])}
    parts = {f"{STORE}/{part['path']}" for log in logs for part in log['archive']['parts']}
    if any(not re.fullmatch(rf'{STORE}/(objects|parts)/[0-9a-f]{{64}}\.(json|txt)', path)
           for path in objects | parts):
        raise Error('The manifest names a file outside the store.')
    for relative in sorted((objects | parts) & fresh):
        path = checkout.path / relative
        if path.is_symlink() or not path.is_file() or path.stat().st_size > MAX_FILE:
            raise Error(f'{relative} is missing, linked or too large.')
        data = path.read_bytes()
        inspect(relative, data, secrets, accepted)
        if relative in objects:
            origin = json.loads(data).get('origin', '')
            if origin.startswith('peer:') and origin[5:].split('/')[0] not in admitted:
                raise Error('A record of a peer outside the list reached the backup; nothing was committed.')
        elif not set(SCOPE.findall(data)) <= scopes:
            raise Error('An operation of a peer outside the list reached the backup; nothing was committed.')
    return objects | parts


def inspect(relative, data, secrets, accepted):
    """Stop on this host's own keys or tokens, or on anything shaped like a credential."""
    if any(secret in data for secret in secrets):
        raise Error(f'{relative} holds one of this host\'s own keys or tokens; nothing was committed.')
    if Path(relative).name not in accepted and any(pattern.search(data) for pattern in SECRETS):
        raise Error(f'{relative} holds what looks like a credential; nothing was committed.')


def prune(checkout, host):
    """Keep this host's newest manifests in the tree. Git history keeps the rest; objects and parts stay."""
    directory = checkout.path / STORE / 'snapshots' / host
    stamped = sorted((int(path.stem), path) for path in directory.glob('*.json') if path.stem.isdigit())
    removed = []
    for _, path in stamped[:-KEEP]:
        try:
            if json.loads(path.read_text()).get('format') != SNAPSHOT:
                continue
        except (OSError, ValueError):
            continue
        path.unlink()
        removed.append(str(path.relative_to(checkout.path)))
    return removed


def backup(args):
    data_dir, state_dir = Path(args.data_dir), Path(args.state_dir)
    config_dir = Path(os.environ.get('XDG_CONFIG_HOME') or Path.home() / '.config') / 'lucy'
    peers = sorted(set(args.peer))
    if not peers:
        raise Error('List at least one peer; an unlisted backup would carry every peer.')
    checkout = Checkout(args.checkout, args.remote, args.branch)
    checkout.preflight()
    report = snapshot(args.lucy, checkout.path / STORE, peers, args.host, data_dir)
    manifest_path = Path(report['snapshot'])
    bases = {'data': data_dir, 'state': state_dir}
    extras = mirror([(label, bases[base] / name) for label, (base, name) in EXTRAS.items()],
                    checkout.path / STORE / 'extras' / args.host)
    fresh = set(checkout.status())
    secrets = known_secrets(data_dir, config_dir)
    accepted_file = state_dir / 'backup-accepted.txt'
    accepted = set(accepted_file.read_text().split()) if accepted_file.is_file() else set()
    named = verify(checkout, manifest_path, peers, args.host, fresh, secrets, accepted)
    extra_paths = [str(path.relative_to(checkout.path)) for path in extras]
    for relative in sorted(set(extra_paths) & fresh):
        inspect(relative, (checkout.path / relative).read_bytes(), secrets, accepted)
    held = checkout.tracked(f'{STORE}/snapshots/{args.host}')
    removed = prune(checkout, args.host)
    wanted = named | set(extra_paths) | {str(manifest_path.relative_to(checkout.path))}
    # Only what this run names is staged; stale files from an earlier attempt stay untracked.
    stage = sorted((wanted & fresh) | (set(removed) & held))
    outcome = {'changed': bool(report.get('changed')), 'new_objects': report.get('new_objects', 0),
               'new_parts': report.get('new_parts', 0), 'objects': report.get('objects', 0),
               'omitted_records': report.get('omitted_records', 0), 'extras': len(set(extra_paths) & fresh),
               'committed': False, 'pushed': False}
    if stage:
        checkout.git('add', '--force', '--all', '--pathspec-from-file=-', '--pathspec-file-nul',
                     stdin='\0'.join(stage))
    if checkout.attempt('diff', '--cached', '--quiet')[0]:
        checkout.git('commit', '--quiet', '-m',
                     f"Back up {args.host}: {outcome['new_objects']} new records, "
                     f"{outcome['new_parts']} new parts, {outcome['extras']} extras")
        outcome['committed'] = True
    reachable = checkout.fetch()
    if reachable:
        checkout.onto_upstream()
    outcome['commit'] = checkout.head()
    if not checkout.ahead():
        outcome['pushed'] = True
        return outcome
    if args.no_push:
        outcome['pending'] = 'not pushed, as asked'
        return outcome
    if not reachable:
        raise Pending('The private repository could not be reached; the backup is committed here and waits.', outcome)
    seen = 'private' if args.allow_unverified_remote else visibility(args.remote)
    if seen == 'public':
        raise Pending('The destination repository is publicly readable; nothing was pushed.', outcome)
    if seen != 'private':
        raise Pending('The destination\'s privacy could not be confirmed; nothing was pushed.', outcome)
    for _ in range(3):
        if checkout.ok('push', 'origin', f'refs/heads/{args.branch}:refs/heads/{args.branch}'):
            break
        if not checkout.fetch():
            break
        checkout.onto_upstream()
    if not checkout.fetch() or checkout.ahead():
        outcome['commit'] = checkout.head()
        raise Pending('The push was not accepted; the backup is committed here and waits.', outcome)
    outcome['commit'] = checkout.head()
    outcome['pushed'] = True
    return outcome


class Pending(Error):
    """The snapshot is safe in the local checkout but has not reached the remote."""

    def __init__(self, message, outcome):
        super().__init__(message)
        self.outcome = outcome


def notify(title, body):
    tool = shutil.which('notify-send')
    if tool:
        subprocess.run([tool, '--app-name=Lucy', title, body], check=False,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def conclude(state_dir, outcome):
    """Record the result where it can be read, and speak up once per run of failures."""
    path = state_dir / 'backup-status.json'
    try:
        previous = json.loads(path.read_text())
    except (OSError, ValueError):
        previous = {}
    outcome['failures'] = 0 if outcome['ok'] else previous.get('failures', 0) + 1
    outcome['time'] = time.strftime('%Y-%m-%dT%H:%M:%S%z')
    partial = path.with_name('.backup-status.json.partial')
    partial.write_text(json.dumps(outcome, indent=1) + '\n')
    partial.replace(path)
    if not outcome['ok'] and outcome['failures'] == 1:
        notify('Lucy backup failed', outcome['error'])
    elif outcome['ok'] and previous.get('failures'):
        notify('Lucy backup is working again', '')
    return outcome


def main(argv=None):
    data_home = Path(os.environ.get('XDG_DATA_HOME') or Path.home() / '.local/share')
    state_home = Path(os.environ.get('XDG_STATE_HOME') or Path.home() / '.local/state')
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    for name in ('run', 'status'):
        command = sub.add_parser(name)
        command.add_argument('--state-dir', default=state_home / 'lucy')
        if name == 'status':
            continue
        command.add_argument('--checkout', default=data_home / 'lucy-private-backup')
        command.add_argument('--remote', required=True)
        command.add_argument('--branch', default='main')
        command.add_argument('--host', required=True)
        command.add_argument('--peer', action='append', default=[],
                             help='a peer the backup may carry; repeat for each')
        command.add_argument('--lucy', default='lucy')
        command.add_argument('--data-dir', default=os.environ.get('LUCY_DATA_DIR') or data_home / 'lucy')
        command.add_argument('--no-push', action='store_true', help='commit locally and stop')
        command.add_argument('--allow-unverified-remote', action='store_true',
                             help='rehearsals and tests only: push where privacy cannot be checked')
    args = parser.parse_args(argv)
    state_dir = Path(args.state_dir)
    if args.command == 'status':
        path = state_dir / 'backup-status.json'
        print(path.read_text().strip() if path.is_file() else '{"ok": null, "error": "no backup has run"}')
        return 0
    state_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
    os.umask(0o077)
    with open(state_dir / 'backup.lock', 'w') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError:
            print(json.dumps({'ok': False, 'error': 'Another backup is running.'}))
            return 1
        try:
            outcome = {'ok': True, 'error': None, 'host': args.host, **backup(args)}
        except Pending as pending:
            outcome = {'ok': False, 'error': str(pending), 'host': args.host, **pending.outcome}
        except Error as error:
            outcome = {'ok': False, 'error': str(error), 'host': args.host}
        print(json.dumps(conclude(state_dir, outcome)))
    return 0 if outcome['ok'] else 1


if __name__ == '__main__':
    sys.exit(main())
