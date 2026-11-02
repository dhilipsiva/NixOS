#!/usr/bin/env python3
"""Retain a legacy Lucy launcher outside the application search path."""
import argparse
import configparser
from pathlib import Path
import tempfile


def retire(home_dir, data_dir, state_dir):
    launcher = data_dir / 'applications/lucy.desktop'
    if launcher.is_symlink() or not launcher.is_file():
        return None
    desktop = configparser.ConfigParser(interpolation=None)
    try:
        desktop.read_string(launcher.read_text())
    except (configparser.Error, UnicodeError):
        return None
    if not desktop.has_section('Desktop Entry'):
        return None
    entry = desktop['Desktop Entry']
    if (entry.get('Type') != 'Application' or entry.get('Name') != 'Ask Lucy'
            or entry.get('Exec') != f'{home_dir}/.nix-profile/bin/lucy ui'):
        return None
    backups = state_dir / 'lucy/launcher-backups'
    backups.mkdir(parents=True, exist_ok=True, mode=0o700)
    backup = Path(tempfile.mkdtemp(prefix='legacy-', dir=backups)) / launcher.name
    launcher.rename(backup)
    return backup


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--home-dir', type=Path, required=True)
    parser.add_argument('--data-dir', type=Path, required=True)
    parser.add_argument('--state-dir', type=Path, required=True)
    args = parser.parse_args()
    backup = retire(args.home_dir, args.data_dir, args.state_dir)
    if backup:
        print(f'Saved the legacy Ask Lucy launcher in {backup}; the managed launcher now takes precedence.')


if __name__ == '__main__':
    main()
