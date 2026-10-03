#!/usr/bin/env python3
"""Home Manager collision handler: retain every original with a unique name."""
import os
from pathlib import Path
import sys
import tempfile

source = Path(sys.argv[1])
backup = Path(tempfile.mkdtemp(prefix=source.name + ".before-nixos-", dir=source.parent))
os.rename(source, backup / source.name)
print(f"Saved {source} in {backup}")
