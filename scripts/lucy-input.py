#!/usr/bin/env python3
"""Run the temporary input device only while an unlocked Wayland login exists."""
import os
import signal
import subprocess
import sys
import time


def unlocked(uid):
    sessions = subprocess.check_output(
        ['loginctl', 'list-sessions', '--no-legend'], text=True, timeout=2
    )
    for row in sessions.splitlines():
        fields = row.split()
        if len(fields) < 2 or fields[1] != str(uid):
            continue
        properties = subprocess.check_output(
            ['loginctl', 'show-session', fields[0], '-p', 'Type', '-p', 'LockedHint', '-p', 'Active'],
            text=True, timeout=2,
        ).splitlines()
        if all(p in properties for p in ('Type=wayland', 'LockedHint=no', 'Active=yes')):
            return True
    return False


def main():
    import pwd
    user = pwd.getpwnam('dhilipsiva')
    if not unlocked(user.pw_uid):
        sys.exit('Lucy input requires an active unlocked Wayland session')
    child = subprocess.Popen([
        sys.argv[1], '--socket-path=/run/lucy-input/socket', '--socket-perm=0600',
        f'--socket-own={user.pw_uid}:{user.pw_gid}',
    ])
    def stop(_signum, _frame):
        child.terminate()
        raise SystemExit(0)
    signal.signal(signal.SIGTERM, stop)
    try:
        deadline = time.monotonic() + 14
        while child.poll() is None and time.monotonic() < deadline and unlocked(user.pw_uid):
            time.sleep(0.05)
    finally:
        if child.poll() is None:
            child.terminate()
        child.wait(timeout=1)
        try:
            os.unlink('/run/lucy-input/socket')
        except FileNotFoundError:
            pass


if __name__ == '__main__':
    main()
