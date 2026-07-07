#!/usr/bin/env bash
# Guardrail (Phase 4): the disposable "vmtest" key must NEVER be a recipient of the
# real secrets file. It only ever decrypts secrets/vm-test.yaml (fake values); if it
# could decrypt secrets/secrets.yaml, the real secret would be effectively published
# (its private half is injected into throwaway VMs). Run before committing anything
# under secrets/ or .sops.yaml.
set -euo pipefail
cd "$(dirname "$0")/.."

VMTEST=age10hwn77a4vpj33s9u9j8u698lwmgv0g8trd2x5hk24zt5a0fnvsss6dj8mg
fail=0

if [ -f secrets/secrets.yaml ]; then
  if grep -q "$VMTEST" secrets/secrets.yaml; then
    echo "FAIL: throwaway vmtest key is a recipient of secrets/secrets.yaml — real secret exposed!"
    fail=1
  fi
  if ! grep -q 'age1' secrets/secrets.yaml; then
    echo "FAIL: secrets/secrets.yaml has no age recipient"
    fail=1
  fi
fi

# The plaintext login hash and the old UPS path must not reappear in any .nix.
if git grep -nE 'hashedPassword[[:space:]]*=' -- '*.nix' >/dev/null 2>&1; then
  echo "FAIL: a plaintext hashedPassword = ... assignment exists in a .nix file"; fail=1
fi
if git grep -n 'ups-password' -- '*.nix' >/dev/null 2>&1; then
  echo "FAIL: /etc/nixos/ups-password still referenced in a .nix file"; fail=1
fi

if [ "$fail" -eq 0 ]; then echo "OK: sops recipient + plaintext-secret guardrails passed"; fi
exit "$fail"
