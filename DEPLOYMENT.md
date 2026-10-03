# Remaining desktop deployment

Run commands from `/home/dhilipsiva/projects/dhilipsiva/NixOS` as dhilipsiva.
Completed preparation is recorded in [SESSION.md](SESSION.md).

## 1. Copy and verify the recovery archive off this machine

Copy `/home/dhilipsiva/nixos-boot-recovery.INuBPo.tar.age` to a USB backup drive
or a network share on another machine. This archive contains the signing keys
and boot/trust backups. Keep the separately backed-up owner age identity available
to decrypt it.

For a mounted backup destination, run the block below. When prompted, enter its
actual directory path, without adding quotes. It copies the archive, checks that
the copy matches, and verifies decryption. An existing different file is left
untouched and fails verification.

```bash
nix shell .#nixosConfigurations.desktop.pkgs.age --command bash -c '
set -euo pipefail
nixos_source=/home/dhilipsiva/nixos-boot-recovery.INuBPo.tar.age
read -r -p "Mounted external backup directory: " nixos_backup_dir </dev/tty
test -d "$nixos_backup_dir" || { echo "Backup directory does not exist." >&2; exit 1; }
nixos_copy="$nixos_backup_dir/nixos-boot-recovery.INuBPo.tar.age"
if [ "$nixos_source" -ef "$nixos_copy" ]; then
  echo "Choose a destination on your external backup storage." >&2
  exit 1
fi
if [ ! -e "$nixos_copy" ]; then
  cp -- "$nixos_source" "$nixos_copy"
fi
cmp -- "$nixos_source" "$nixos_copy"
sync -f "$nixos_copy"
age -d -i "$HOME/.config/sops/age/keys.txt" "$nixos_copy" >/dev/null
printf "Verified backup copy: %s\n" "$nixos_copy"
'
```

Proceed after the archive is copied off this machine and that copy is verified.

## 2. Append the public certificate in MSI firmware

1. Reboot manually into MSI firmware. In Advanced Mode (F7), open
   **Settings → Security → Secure Boot** and keep Secure Boot enabled.
2. Set **Secure Boot Mode → Custom** if needed to expose **Key Management**.
3. Select **Authorized Signatures (db) → Append Key**. Choose `/nixos-db.cer`
   at the root of the **1 GiB Linux EFI partition**, UUID `85B9-1188`.
4. Preserve the existing PK, KEK, Microsoft/OEM db and dbx entries. Do not clear
   or replace keys, restore factory keys, enter Secure Boot Setup Mode, or run
   `sbctl enroll-keys`. If the menu offers no append operation, leave it unchanged.
5. Save the append operation and return to the existing Linux installation using
   **NixOS generation 2**, entry `nixos-generation-2.conf`.

See the [MSI AM5 BIOS manual](https://download.msi.com/archive/mnu_exe/mb/AMDAM5BIOS.pdf),
pages 21–22. In the firmware file picker the certificate is `/nixos-db.cer`;
there is no `boot` directory to open first.

## 3. Stage the published configuration

After returning from firmware enrollment:

```bash
scripts/nixosctl stage --host desktop
```

The helper verifies the published revision, credentials, hardware, actual
certificate enrollment and preservation of existing firmware trust before
staging. It checks/builds the configuration, installs signed boot entries and a
protected recovery image, and records the staged revision. It does not change
the running session or reboot.

After staging, inspect the newly written entries:

```bash
sudo bootctl list
```

Confirm the new generation is the default and the protected recovery entry is
present. Then reboot manually into the new generation. Keep installer/recovery
media and firmware boot-menu access available.

## 4. Validate the new desktop

- Check password login and sudo, greetd/Hyprland, Alacritty/fish, Atuin, zoxide
  and ripgrep. The old shell's Atuin warning should be resolved after activation.
- Check NVIDIA rendering and `nvidia-smi`, networking, audio and the UPS.
- Confirm the screen locks/powers off after five minutes while the machine keeps
  running without suspend or hibernation.
- Check read-only Windows file copying and Secure Boot status/signatures.
- Exercise Ollama with a real model: confirm the backend is absent at boot,
  starts on request, unloads the model after a default request and stops when idle.
- Check Slack and Teams sign-in, microphone, camera and screen sharing.

## 5. Accept the deployment and run cleanup

Only after the physical checks pass:

```bash
scripts/nixosctl accept --host desktop --physical-checks-passed
scripts/nixosctl cleanup
```

Acceptance verifies that the running generation matches the staged receipt and
that credential/signature checks still pass. It enables the configured update,
GC and store-optimisation jobs. Cleanup retains the protected recovery roots and
uses the 30-day generation policy; personal files, models and Windows data remain
outside its scope.

After establishing this working baseline, inspect BIOS CCD/core/SMT and MSI
gaming-mode settings: Linux currently exposes only eight cores/eight threads.
