# Remaining desktop deployment

Run commands from `/home/dhilipsiva/projects/dhilipsiva/NixOS` as dhilipsiva.
Completed preparation and the reported backup copy are recorded in [SESSION.md](SESSION.md).
Keep the copied recovery archive and the separately backed-up owner age identity
available during the firmware change.

## 1. Restore the missing dbx revocations

Certificate enrollment is complete and verified against the preparation backup.
Secure Boot is enabled in User mode; PK, KEK and all six original db certificates
are preserved, with the local certificate added as the seventh entry.

Staging stopped before changing the system profile or boot entries because the
forbidden-signature database (`dbx`) has lost 29 SHA-256 revocations. The backup
has 445 entries; the current 416 entries exactly match the firmware's factory
`dbxDefault`. This is a real loss of revocations, not an entry-order or owner-GUID
difference. Its cause has not been established. Keep the staging guard and its
original backup intact.

Copy the saved public revocation list to the Linux ESP from your local terminal:

```bash
sudo install -m 0600 \
  /var/lib/nixos-deployment/boot-backup-20261003T190354/dbx.esl \
  /boot/nixos-dbx-restore.esl
sudo cmp \
  /var/lib/nixos-deployment/boot-backup-20261003T190354/dbx.esl \
  /boot/nixos-dbx-restore.esl
```

A successful `cmp` prints nothing. The file contains only the public revocation
list that was installed before preparation. These commands do not enroll it.
Private signing keys and the original backup stay in place.

Then, manually in MSI firmware:

1. Open **Security → Secure Boot → Key Management → Forbidden Signatures (dbx)**.
2. Choose **Append Key → Local File**.
3. Select the Linux ESP. In `PXL_20261003_142445764.jpg`, it is the **first/top
   entry**, containing `PCI(1|2)\PCI(0|0)`. This matches the Linux SSD's actual PCI
   path. Its EFI partition is 1 GiB, UUID `85B9-1188`; the other paths beginning
   with `PCI(2|1)` lead to the Windows SSD.
4. Select **`nixos-dbx-restore.esl`** at the partition's root. This is an
   **EFI Signature List**, containing the original revocations. If the firmware
   offers that exact format, select it. Inspect or photograph any differently
   worded format dialog before confirming. Do not choose an operation that
   hashes the file as an executable.
5. Complete only the append to **dbx**, save and return to Linux using
   **NixOS generation 2**, entry `nixos-generation-2.conf`.

Use the recovery `.esl` only with **Forbidden Signatures (dbx)**. Never put
`nixos-db.cer` in dbx: that would revoke your new signing certificate. Preserve
PK, KEK and db, and leave **Set New Var**, **Delete Var**, **Restore Factory
Keys**, **Reset To Setup Mode** and **Enroll Efi Image** unused. Keep Secure Boot
enabled in Custom mode. Staging will verify the actual saved entries after the
reboot; displayed key counts alone do not establish successful restoration.

The [MSI AM5 BIOS manual](https://download.msi.com/archive/mnu_exe/mb/AMDAM5BIOS.pdf),
page 22, documents appending to Forbidden Signatures. The exact file-format
dialog on this firmware has not yet been observed.

## 2. Stage the published configuration

After restoring the missing revocations and returning from firmware:

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

## 3. Validate the new desktop

- Check password login and sudo, greetd/Hyprland, Alacritty/fish, Atuin, zoxide
  and ripgrep. The old shell's Atuin warning should be resolved after activation.
- Check NVIDIA rendering and `nvidia-smi`, networking, audio and the UPS.
- Confirm the screen locks/powers off after five minutes while the machine keeps
  running without suspend or hibernation.
- Check read-only Windows file copying and Secure Boot status/signatures.
- Exercise Ollama with a real model: confirm the backend is absent at boot,
  starts on request, unloads the model after a default request and stops when idle.
- Check Slack and Teams sign-in, microphone, camera and screen sharing.

## 4. Accept the deployment and run cleanup

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
