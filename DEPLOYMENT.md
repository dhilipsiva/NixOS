# Remaining desktop deployment

Run commands from `/home/dhilipsiva/projects/dhilipsiva/NixOS` as dhilipsiva.
Firmware enrollment, restoration of all saved dbx entries and staging are complete.
Generation **10**, from published revision `3a9fa98970d18e2198a8d2ff334d4479d8479b01`,
is staged. Generation 2 is still running. Completed preparation and the reported
backup copy are recorded in [SESSION.md](SESSION.md). Keep the copied recovery
archive, separately backed-up owner age identity and recovery media available.

## 1. Check the boot menu and reboot manually

Inspect the newly written entries from your local terminal:

```bash
sudo bootctl list
```

Confirm that **NixOS generation 10** is the **default**, and that
**NixOS (protected pre-migration recovery)** is present, with entry ID
`nixos-protected-recovery.conf`. The current/selected entry can still refer to
generation 2 until the reboot. If the new default or recovery entry is missing,
resolve the boot-menu output before rebooting.

Once those entries are confirmed, save your work and reboot manually into
generation 10. If the new system cannot boot or provide a usable login, select
**NixOS (protected pre-migration recovery)** from the boot menu; it contains the
original generation 2 kernel/initrd in a signed recovery image.

## 2. Validate the new desktop

Log in through the text login screen and open Alacritty with **Super+Enter**.
Collect the initial read-only checks:

```bash
scripts/nixosctl status
sudo bootctl status
nvidia-smi
systemctl --failed
systemctl --user --failed
```

The running system must match the staged system:
`/nix/store/s5mcwfgiihwlya0rjjf03yvg86a5947m-nixos-system-dhilipsiva-desktop-26.05.20261002.774debe`.
Secure Boot must remain enabled. Inspect any failed units before acceptance.

- Check password login and sudo, greetd/Hyprland, Alacritty/fish, Atuin, zoxide
  and ripgrep. The old shell's Atuin warning should be resolved after activation.
- Check NVIDIA rendering and `nvidia-smi`, networking, audio and the UPS.
- Confirm the screen locks/powers off after five minutes while the machine keeps
  running without suspend or hibernation.
- Check read-only Windows file copying and Secure Boot status/signatures.
- Exercise Ollama with a real model: confirm the backend is absent at boot,
  starts on request, unloads the model after a default request and stops when idle.
- Check Slack and Teams sign-in, microphone, camera and screen sharing.

## 3. Accept the deployment and run cleanup

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
