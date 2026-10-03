#!/usr/bin/env bash
# Conservative command guard for Claude Code. Deployment is routed through
# nixosctl stage, which checks published revisions, credentials and firmware.
# This is a convenience guard, not a security boundary or an authorization source.
set -euo pipefail

INPUT="$(cat)"
if command -v jq >/dev/null 2>&1; then
  CMD="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')"
else
  # Fallback: no jq — treat the whole payload as the command (errs toward blocking).
  CMD="$(printf '%s' "$INPUT" | tr -d '\n')"
fi

blk() { echo "BLOCKED by guard.sh: $1" >&2; exit 2; }

# Normalize whitespace so multi-space / newline variants can't slip patterns.
N="$(printf '%s' "$CMD" | tr -s '[:space:]' ' ')"

# --- destructive deletes (any recursive rm; `rm -f <file>` without -r stays allowed) ---
echo "$N" | grep -Eq '(^|[^a-zA-Z0-9_])rm +(-[a-zA-Z]*[rR]|--recursive)' \
  && blk "rm -r (recursive delete)"

# --- activating a config on the running machine ---
# Two-step so the subcommand is matched as a space-delimited TOKEN — otherwise the
# 'test' inside a flake attr like .#vmtest would false-positive. Also excludes the
# fallback tool `nixos-rebuild-ng` (no space after -rebuild) used for build-image.
if echo "$N" | grep -Eq '(^|[^a-zA-Z0-9_])nixos-rebuild +'; then
  echo " $N " | grep -Eq ' (switch|boot|test|dry-activate) ' \
    && blk "Use nixosctl stage --host HOST for boot-only deployment; live activation is not part of this workflow"
fi

# --- declarative partitioner run directly (must go through nixos-anywhere --vm-test) ---
echo "$N" | grep -Eq '(^|[^a-zA-Z0-9_])disko( |$)' \
  && blk "disko — use 'nixos-anywhere --vm-test' against the VM instead"

# --- irreversible git ---
echo "$N" | grep -Eq 'git +push +.*--force' && blk "git push --force"
echo "$N" | grep -Eq 'git +reset +--hard'   && blk "git reset --hard"

# --- nixos-anywhere: allow ONLY --vm-test or a localhost target ---
if echo "$N" | grep -Eq 'nixos-anywhere'; then
  if echo "$N" | grep -Eq -- '--vm-test'; then
    :
  elif echo "$N" | grep -Eq -- '--target-host +([a-zA-Z0-9_.-]+@)?(localhost|127\.0\.0\.1)([: "]|$)'; then
    :
  else
    blk "nixos-anywhere without --vm-test and without --target-host localhost/127.0.0.1"
  fi
fi

# --- raw block-device writes (the net for wipes outside disko) ---
echo "$N" | grep -Eq 'of=/dev/(sd|nvme|vd|hd|disk)' \
  && blk "dd to a raw block device (of=/dev/...)"
echo "$N" | grep -Eq '(mkfs|wipefs|sgdisk|parted|blkdiscard|shred)[^;&|]*/dev/(sd|nvme|vd|hd|disk)' \
  && blk "destructive block-device tool targeting /dev/*"

exit 0
