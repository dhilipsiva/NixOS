# Remaining desktop deployment

Run commands from `/home/dhilipsiva/projects/dhilipsiva/NixOS` as dhilipsiva.
Completed preparation and the reported backup copy are recorded in [SESSION.md](SESSION.md).
Keep the copied recovery archive and the separately backed-up owner age identity
available during the firmware change.

## 1. Append the public certificate in MSI firmware

Your photos show **System Mode: User**, **Secure Boot: Enabled** and **Secure
Boot Mode: Custom**. Keep those settings, the preset and factory-key provisioning
unchanged. Key Management is already available.

1. Return to **Security → Secure Boot → Key Management**.
2. Open **Authorized Signatures (db)**, the row showing six existing keys in
   your screenshot.
3. The action menu contains **Details**, **Save To File**, **Set New Var**,
   **Append Key** and **Delete Var**. Use the keyboard arrows to select
   **Append Key**, then press **Enter** to activate it.
4. The screen listing Microsoft certificates and `MSI SHIP DB` shows the
   existing signatures. If you are there, press **Esc** to return to the action
   menu and activate **Append Key**. The highlighted row in a photo alone does
   not establish that the append action ran.
5. In the file-selection flow, choose the public certificate `/nixos-db.cer`
   at the root of the **1 GiB Linux EFI partition**, UUID `85B9-1188`. There is
   no `boot` directory to open first. The `.tar.age` archive is the recovery
   backup; the certificate for firmware enrollment is `nixos-db.cer`.
6. If activating Append Key opens a different dialog, keep it unchanged and
   inspect its exact wording before choosing anything. The supplied photos do
   not show this next dialog, so no Yes/No choice is assumed here.
7. After the append succeeds, save the change and return to Linux using
   **NixOS generation 2**, entry `nixos-generation-2.conf`.

Preserve the existing PK, KEK, Microsoft/OEM db and dbx entries. Leave **Set New
Var**, **Delete Var**, **Restore Factory Keys**, **Reset To Setup Mode** and
**Enroll Efi Image** unused. Staging will check the actual certificate and all
original trust entries; the displayed key count alone is not sufficient proof.

The [MSI AM5 BIOS manual](https://download.msi.com/archive/mnu_exe/mb/AMDAM5BIOS.pdf),
pages 21–22, documents appending to db. The menu labels above match your photos.

## 2. Stage the published configuration

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
