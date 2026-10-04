#!/usr/bin/env python3
"""Operate the shared NixOS checkout without merging, discarding work or rebooting."""
import argparse
from contextlib import contextmanager
import fcntl
import json
import os
from pathlib import Path
import pwd
import shutil
import subprocess
import sys
import tempfile

DEFAULT_REPO = Path('/home/dhilipsiva/projects/dhilipsiva/NixOS')
PIN_FILES = ['flake.nix', 'flake.lock', 'pkgs/releases.json',
             'pkgs/claude-code-manifest.json', 'pkgs/stable-channels.json']


class Error(RuntimeError):
    pass


def run(args, *, cwd=None, capture=False, owner=None, env=None, input=None, timeout=None):
    args = [str(a) for a in args]
    process_env = os.environ.copy()
    for name, value in (env or {}).items():
        if value is None:
            process_env.pop(name, None)
        else:
            process_env[name] = value
    if owner and os.geteuid() == 0:
        account = pwd.getpwnam(owner)
        args = ['runuser', '-u', owner, '--', 'env', f'HOME={account.pw_dir}', *args]
    try:
        result = subprocess.run(args, cwd=cwd, env=process_env, input=input, timeout=timeout,
                                text=True, stdout=subprocess.PIPE if capture else None,
                                stderr=subprocess.PIPE if input is not None else None)
    except subprocess.TimeoutExpired as exc:
        raise Error(f'{Path(args[0]).name} timed out; no deployment will proceed.') from exc
    if result.returncode:
        # Never include stdin, environment or secret-processing output in errors.
        raise Error(f'{Path(args[0]).name} failed (exit {result.returncode}).')
    return result.stdout.strip() if capture else None


class Repository:
    def __init__(self, path, branch='master'):
        self.path = Path(path).resolve()
        self.owner = pwd.getpwuid(self.path.stat().st_uid).pw_name
        if self.owner == 'root':
            raise Error('The shared checkout must belong to its normal user, not root.')
        self.branch = branch
        if Path(self.git('rev-parse', '--show-toplevel')) != self.path:
            raise Error('Use the repository root.')

    def git(self, *args, capture=True):
        return run(['git', '-C', self.path, *args], capture=capture, owner=self.owner,
                   timeout=120 if args[0] in ('fetch', 'push') else None,
                   env={'GIT_TERMINAL_PROMPT': '0', 'GIT_ASKPASS': shutil.which('false')})

    def clean(self):
        if self.git('status', '--porcelain', '--untracked-files=all'):
            raise Error('Checkout has local changes. Commit them or move them yourself; nothing was discarded.')
        if self.git('symbolic-ref', '--quiet', '--short', 'HEAD') != self.branch:
            raise Error(f'Checkout must be on {self.branch}.')

    def head(self):
        return self.git('rev-parse', 'HEAD')

    def remote_head(self):
        self.git('fetch', 'origin', f'refs/heads/{self.branch}:refs/remotes/origin/{self.branch}', capture=False)
        return self.git('rev-parse', f'refs/remotes/origin/{self.branch}')

    def ancestor(self, older, newer):
        try:
            self.git('merge-base', '--is-ancestor', older, newer)
            return True
        except Error:
            return False

    def sync(self):
        self.clean()
        remote = self.remote_head()
        if not self.ancestor(self.head(), remote):
            raise Error('Local branch is ahead or diverged. Publish or resolve it explicitly.')
        self.git('merge', '--ff-only', remote, capture=False)
        return remote

    def require_published(self):
        self.clean()
        revision = self.head()
        if revision != self.remote_head():
            raise Error('Staging requires the exact published branch tip. Run sync or publish first.')
        return revision

    @contextmanager
    def snapshot(self, revision):
        # The worktree is solely ours, outside the shared checkout. Failure cannot
        # modify the user's files. Build receipts keep their store outputs alive.
        parent = Path(tempfile.mkdtemp(prefix='nixosctl-'))
        if os.geteuid() == 0:
            account = pwd.getpwnam(self.owner)
            os.chown(parent, account.pw_uid, account.pw_gid)
        candidate = parent / 'candidate'
        try:
            self.git('worktree', 'add', '--detach', str(candidate), revision, capture=False)
            yield candidate
        finally:
            if candidate.exists():
                self.git('worktree', 'remove', '--force', str(candidate), capture=False)
            shutil.rmtree(parent)

    def check(self, source=None, stable=False):
        source = source or self.path
        flake = f'path:{source}'
        hosts = json.loads(run(['nix', 'eval', '--json', f'{flake}#lib.hosts'], owner=self.owner, capture=True))
        if not hosts:
            raise Error('No configured hosts.')
        if stable:
            run([sys.executable, source / 'scripts/update-stable-releases.py', source,
                 '--verify'], owner=self.owner)
        run(['nix', 'flake', 'check', '--no-write-lock-file', flake], owner=self.owner)
        outputs = {}
        roots = Path(pwd.getpwnam(self.owner).pw_dir) / '.local/state/nixosctl/builds'
        roots.mkdir(parents=True, exist_ok=True)
        if os.geteuid() == 0:
            # Only this dedicated directory; never recursively chown the home.
            account = pwd.getpwnam(self.owner)
            for directory in (roots.parent, roots):
                os.chown(directory, account.pw_uid, account.pw_gid)
        for host in sorted(hosts):
            result = json.loads(run(['nix', 'build', '--json', '--no-write-lock-file',
                                     '--out-link', roots / host,
                                     f'{flake}#nixosConfigurations.{host}.config.system.build.toplevel'],
                                    owner=self.owner, capture=True))
            outputs[host] = result[0]['outputs']['out']
        return hosts, outputs

    def publish(self):
        self.clean()
        revision = self.head()
        remote = self.remote_head()
        if not self.ancestor(remote, revision):
            raise Error('Remote advanced or diverged; resolve before publishing.')
        with self.snapshot(revision) as candidate:
            self.check(candidate)
            self.git('push', 'origin', f'{revision}:refs/heads/{self.branch}', capture=False)
        # Fetch again: do not report publication after a rejected/offline push.
        if not self.ancestor(revision, self.remote_head()):
            raise Error('Published revision could not be verified at origin.')
        print(f'Published {revision}. No running system was changed.')

    def nightly(self, base=None):
        base = base or self.sync()
        self.clean()
        if self.head() != base:
            raise Error('Checkout changed after sync; refusing to publish an outdated candidate.')
        with self.snapshot(base) as candidate:
            run([sys.executable, candidate / 'scripts/update-stable-releases.py', candidate], owner=self.owner)
            run(['nix', 'flake', 'update', '--refresh', '--flake', f'path:{candidate}'], owner=self.owner)
            self.check(candidate, stable=True)
            def git(*args):
                return run(['git', '-C', candidate, *args], owner=self.owner, capture=True,
                           timeout=120 if args[0] == 'push' else None,
                           env={'GIT_TERMINAL_PROMPT': '0', 'GIT_ASKPASS': shutil.which('false')})
            changed = set(git('diff', '--name-only').splitlines())
            untracked = set(git('ls-files', '--others', '--exclude-standard').splitlines())
            if (changed | untracked) - set(PIN_FILES):
                raise Error('Updater changed a file outside the release/input allowlist.')
            if changed or untracked:
                git('add', '--', *PIN_FILES)
                git('commit', '-m', 'Update verified stable releases')
                revision = git('rev-parse', 'HEAD')
                git('push', 'origin', f'{revision}:refs/heads/{self.branch}')
            else:
                revision = base
        if revision != self.remote_head():
            raise Error('Remote moved during update; nothing will be staged.')
        self.sync()
        print(f'Verified published update: {revision}')


def manifest(repo, host):
    hosts = json.loads(run(['nix', 'eval', '--json', f'path:{repo.path}#lib.hosts'],
                           owner=repo.owner, capture=True))
    if host not in hosts:
        raise Error(f'Host {host!r} is not configured. Capture its hardware first.')
    cfg = hosts[host]
    if cfg['owner'] != repo.owner or Path(cfg['repository']) != repo.path:
        raise Error('Checkout owner/path differs from the configured single source of truth.')
    if repo.git('remote', 'get-url', 'origin') != cfg['remote']:
        raise Error('origin does not match the configured repository.')
    repo.branch = cfg['branch']
    return cfg


def escalate(args):
    launcher = os.environ.get('NIXOSCTL_LAUNCHER')
    if not launcher or not launcher.startswith('/nix/store/'):
        raise Error('For privileged operations use scripts/nixosctl (the packaged tool).')
    run(['sudo', '--', launcher, *args])


@contextmanager
def deployment_lock():
    with open('/run/lock/nixos-repository.lock', 'a') as lock:
        os.chmod(lock.name, 0o600)
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as exc:
            raise Error('A deployment or cleanup is already running; try again after it finishes.') from exc
        yield


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo', type=Path, default=DEFAULT_REPO)
    commands = parser.add_subparsers(dest='command', required=True)
    for name in ['sync', 'publish', 'check', 'status', 'cleanup', 'setup-publisher']:
        command = commands.add_parser(name)
        if name == 'check':
            command.add_argument('--stable', action='store_true', help='also verify pinned upstream channel metadata')
    for name in ['stage', 'maintain', 'prepare-credentials', 'prepare-boot', 'accept']:
        command = commands.add_parser(name)
        command.add_argument('--host', required=True)
        if name == 'accept':
            command.add_argument('--physical-checks-passed', action='store_true', required=True)
        if name == 'prepare-boot':
            command.add_argument('--windows-status',
                                 choices=['absent', 'unencrypted', 'recovery-key-backed-up'])
    args = parser.parse_args()
    root_commands = {'stage', 'maintain', 'cleanup', 'prepare-credentials', 'prepare-boot', 'accept'}
    if args.command in root_commands and os.geteuid() != 0:
        escalate(sys.argv[1:])
        return
    repo = Repository(args.repo)
    if args.command == 'sync':
        repo.sync()
    elif args.command == 'publish':
        repo.publish()
    elif args.command == 'check':
        hosts, builds = repo.check(stable=args.stable)
        print(json.dumps(builds, indent=2))
    elif args.command == 'status':
        repo.git('status', '--short', '--branch', capture=False)
        print(f'Checkout: {repo.head()}')
        print(f'Running: {Path("/run/current-system").resolve()}')
        print(f'System profile: {Path("/nix/var/nix/profiles/system").resolve()}')
        print('Boot default is separate; inspect sudo bootctl list before rebooting.')
        print('Unattended updates and GC require: /var/lib/nixos-deployment/accepted.json')
    else:
        import deployment
        if args.command == 'setup-publisher':
            deployment.setup_publisher(repo)
            return
        with deployment_lock():
            cfg = manifest(repo, args.host) if hasattr(args, 'host') else None
            if cfg:
                deployment.verify_hardware(cfg)
            if args.command == 'prepare-credentials':
                deployment.prepare_credentials(repo, args.host, cfg)
            elif args.command == 'prepare-boot':
                deployment.prepare_boot(cfg, args.windows_status)
            elif args.command == 'stage':
                deployment.stage(repo, args.host, cfg)
            elif args.command == 'accept':
                deployment.accept(repo, args.host, cfg)
            elif args.command == 'cleanup':
                deployment.cleanup()
            elif args.command == 'maintain':
                deployment.require_acceptance()
                base = repo.sync()
                cfg = manifest(repo, args.host)
                deployment.verify_hardware(cfg)
                if cfg['role'] == 'publisher':
                    # All Git and Nix work runs as the checkout owner.
                    repo.nightly(base)
                deployment.stage(repo, args.host, cfg)


if __name__ == '__main__':
    sys.modules['nixosctl'] = sys.modules[__name__]
    try:
        main()
    except (Error, OSError, ValueError, KeyError) as exc:
        print(f'nixosctl: {exc}', file=sys.stderr)
        sys.exit(1)
