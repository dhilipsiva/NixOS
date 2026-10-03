#!/usr/bin/env python3
"""Home Manager collision handler: retain every original with a unique name."""
import os
from pathlib import Path
import sys
import tempfile


def main():
    # Home Manager 26.05 uses unescaped shell backticks around backupCommand
    # in its collision-check message. That executes us WITHOUT a path, before
    # the activation write boundary. Describe the command without moving files.
    if len(sys.argv) == 1:
        print("unique-file backup")
        return
    if len(sys.argv) != 2:
        raise SystemExit("usage: backup-home-file.py [FILE]")

    source = Path(sys.argv[1])
    backup = Path(tempfile.mkdtemp(prefix=source.name + ".before-nixos-", dir=source.parent))
    os.rename(source, backup / source.name)
    print(f"Saved {source} in {backup}")


if __name__ == "__main__":
    main()
