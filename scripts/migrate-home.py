#!/usr/bin/env python3
"""Preserve local application settings when leaving the legacy XDG directory."""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import shutil
import tempfile


def migrate(home, source, managed):
    home, source = Path(home), Path(source)
    state = home / '.local/state/nixosctl/home-migration'
    marker = state / 'completed.json'
    if marker.exists():
        return
    if not source.is_dir():
        raise RuntimeError('The legacy application configuration directory is missing.')
    os.umask(0o077)
    state.mkdir(mode=0o700, parents=True, exist_ok=True)
    destination = home / '.config'
    destination.mkdir(mode=0o700, exist_ok=True)
    backup = state / datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%f')
    backup.mkdir(mode=0o700)
    shutil.copytree(source, backup / 'legacy', symlinks=True)
    if (destination / 'obs-studio').exists():
        shutil.copytree(destination / 'obs-studio', backup / 'obs-studio-destination', symlinks=True)
    retained = []
    copied = []

    def managed_path(relative):
        target = Path('.config') / relative
        return any(target == path or path in target.parents for path in managed)

    def copy_directory(current, target, relative):
        for item in sorted(current.iterdir()):
            child = relative / item.name
            output = target / item.name
            if managed_path(child):
                continue
            if item.is_dir() and not item.is_symlink():
                if output.is_symlink() or (output.exists() and not output.is_dir()):
                    retained.append(str(child))
                    continue
                output.mkdir(mode=0o700, exist_ok=True)
                copy_directory(item, output, child)
            elif output.exists() or output.is_symlink():
                retained.append(str(child))
            else:
                if item.is_symlink():
                    output.symlink_to(os.readlink(item))
                else:
                    with tempfile.NamedTemporaryFile(dir=target, prefix='.nixos-import-', delete=False) as temporary:
                        temporary_path = Path(temporary.name)
                    try:
                        shutil.copyfile(item, temporary_path)
                        temporary_path.chmod((item.stat().st_mode & 0o700) | 0o600)
                        temporary_path.replace(output)
                    finally:
                        temporary_path.unlink(missing_ok=True)
                copied.append(str(child))

    obs = destination / 'obs-studio'
    if obs.exists() or obs.is_symlink():
        if (source / 'obs-studio').is_dir():
            obs.rename(backup / 'obs-studio-before-migration')
    copy_directory(source, destination, Path())
    temporary_marker = marker.with_suffix('.json.new')
    temporary_marker.write_text(json.dumps({'backup': str(backup), 'copied': copied, 'retained': retained}, indent=2) + '\n')
    temporary_marker.replace(marker)
    print('Legacy application settings preserved; private backup and collision report: ' + str(state))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--home', type=Path, required=True)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--managed', type=Path, required=True)
    args = parser.parse_args()
    migrate(args.home, args.source, [Path(path) for path in json.loads(args.managed.read_text())])
