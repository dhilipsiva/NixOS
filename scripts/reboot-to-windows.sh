# Reboot straight into Windows once. Sets the firmware's BootNext to the
# "Windows Boot Manager" entry (Windows lives on its own SSD with its own ESP)
# and reboots. The permanent boot order is untouched, so the next restart from
# Windows returns to NixOS. Packaged by hosts/desktop/windows.nix as
# `reboot-to-windows` with efibootmgr and systemd on PATH.
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
