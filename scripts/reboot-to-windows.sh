#!/usr/bin/env bash
# Reboot straight into Windows once. Sets the firmware's BootNext to the
# "Windows Boot Manager" entry (Windows lives on its own SSD with its own ESP)
# and reboots. The permanent boot order is untouched, so the next restart from
# Windows returns to NixOS. Packaged by hosts/desktop/windows.nix as
# `reboot-to-windows` with efibootmgr and systemd on PATH; run from the
# checkout, it fetches efibootmgr through the system's pinned nixpkgs registry.
set -euo pipefail
if ! command -v efibootmgr > /dev/null 2>&1; then
  if [ -n "${REBOOT_TO_WINDOWS_BOOTSTRAPPED:-}" ]; then
    echo "efibootmgr is still missing after nix shell; install the generation that packages reboot-to-windows." >&2
    exit 1
  fi
  echo "efibootmgr is not on PATH; fetching it from the pinned nixpkgs." >&2
  REBOOT_TO_WINDOWS_BOOTSTRAPPED=1 exec nix shell nixpkgs#efibootmgr --command bash "$0" "$@"
fi
entry=$(efibootmgr | sed -n 's/^Boot\([0-9A-Fa-f]\{4\}\)\*\{0,1\}[[:space:]]*Windows Boot Manager.*/\1/p' | head -n 1)
if [ -z "$entry" ]; then
  echo "No 'Windows Boot Manager' firmware boot entry found; nothing changed." >&2
  exit 1
fi
if [ "$(id -u)" -eq 0 ]; then
  efibootmgr --quiet --bootnext "$entry"
else
  # pkexec asks through the session's polkit agent, so this also works from the launcher.
  pkexec efibootmgr --quiet --bootnext "$entry"
fi
echo "Next start boots Windows (firmware entry Boot$entry); rebooting."
systemctl reboot
