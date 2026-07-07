#!/usr/bin/env bash
# Pre-flight WRONG-DISK guard for the declarative install (Phase 5/6/7).
#
# The pinned disko has no per-device create hook, so this script REPLACES the
# in-config runtime check: run it against the intended Linux target BEFORE any
# real `disko` / `nixos-anywhere` run. It refuses if the device looks like the
# Windows disk (Windows is on a SEPARATE SSD). Eval-safe: not part of the Nix
# build, so it can never break `nix flake check`.
#
#   usage:  sudo scripts/preflight-disk-check.sh /dev/disk/by-id/<the-LINUX-ssd>
set -euo pipefail

dev="${1:-}"
if [ -z "$dev" ]; then
  echo "usage: $0 /dev/disk/by-id/<the-LINUX-ssd>" >&2
  exit 2
fi

# 1. Must be a stable by-id path (never /dev/sdX or /dev/nvme0n1 — enumeration
#    order is not stable and could resolve onto the Windows disk).
case "$dev" in
  /dev/disk/by-id/*) : ;;
  *) echo "REFUSE: use a stable /dev/disk/by-id/ path, not '$dev'." >&2; exit 1 ;;
esac
case "$dev" in
  *REPLACE-ME*) echo "REFUSE: still the placeholder — set the real Linux by-id path." >&2; exit 1 ;;
esac

# 2. Must resolve to a real block device.
real=$(readlink -f "$dev" || true)
if [ ! -b "$real" ]; then
  echo "REFUSE: '$dev' does not resolve to a block device on this machine." >&2
  exit 1
fi

echo "== target: $dev -> $real =="
lsblk -o NAME,SERIAL,MODEL,SIZE,FSTYPE,LABEL "$real" || true

# 3. Refuse if any Windows-ish signature is present on the disk or its partitions.
win_re='ntfs|ntfs3|BitLocker|ReFS|exfat'
found=""
for p in "$real" "$real"*; do
  [ -b "$p" ] || continue
  t=$(blkid -o value -s TYPE "$p" 2>/dev/null || true)
  if printf '%s' "$t" | grep -qiE "$win_re"; then found="$found $p($t)"; fi
  # A vfat ESP containing /EFI/Microsoft is a Windows boot disk even without NTFS.
  if [ "$t" = "vfat" ] && [ "$(id -u)" = "0" ]; then
    tmp=$(mktemp -d)
    if mount -o ro "$p" "$tmp" 2>/dev/null; then
      [ -d "$tmp/EFI/Microsoft" ] && found="$found $p(EFI/Microsoft)"
      umount "$tmp" 2>/dev/null || true
    fi
    rmdir "$tmp" 2>/dev/null || true
  fi
done
if [ -n "$found" ]; then
  echo "REFUSE: Windows signature(s) found on the target:$found" >&2
  echo "This must be the LINUX disk only; Windows is on a SEPARATE disk." >&2
  exit 1
fi

# 4. Require an explicit typed confirmation of the model/serial shown above.
echo
echo "No Windows signature found. CONFIRM this is the LINUX SSD to be WIPED."
read -rp "Type the disk MODEL or SERIAL exactly as shown above to proceed: " ans
if [ -z "$ans" ] || ! lsblk -dno SERIAL,MODEL "$real" | grep -qF -- "$ans"; then
  echo "REFUSE: confirmation did not match. Aborting." >&2
  exit 1
fi
echo "OK: $dev confirmed as the Linux target. Safe to proceed."
