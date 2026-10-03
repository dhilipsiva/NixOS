# Remaining desktop deployment

Run commands from `/home/dhilipsiva/projects/dhilipsiva/NixOS` as dhilipsiva.
Generation **10** booted but failed display validation: the screen stayed blank
at the NVIDIA framebuffer takeover. Blind login successfully started Hyprland;
the kernel reported `HDMI FRL link training failed`. The desktop is back on the
original generation 2. Firmware preparation is complete; do not repeat enrollment.
Completed preparation and the reported backup copy are in [SESSION.md](SESSION.md).
Keep the copied recovery archive, owner age identity and recovery media available.

## 1. Stage the HDMI compatibility change and reboot manually

The desktop configuration now disables NVIDIA HDMI FRL and deep colour and uses
**3840×2160 at 60 Hz, 8-bit SDR** for the connected Samsung Odyssey G81SF. This is
a temporary compatibility baseline; high refresh/HDR still need separate testing.
These settings are confined to the desktop host. The change
requires a new boot generation and has not yet been validated on the display.

From your local terminal, stage the published revision, then inspect the entries:

```bash
scripts/nixosctl stage --host desktop
sudo bootctl list
```

Confirm the **newly staged generation** is the **default**, and that
**NixOS (protected pre-migration recovery)** is present, with entry ID
`nixos-protected-recovery.conf`. The current/selected entry can still refer to
generation 2 until the reboot. If the new default or recovery entry is missing,
resolve the boot-menu output before rebooting.

Once those entries are confirmed, save your work and reboot manually into
the newly staged generation. If the screen remains blank or login is unusable, select
**NixOS (protected pre-migration recovery)** from the boot menu; it contains the
original generation 2 kernel/initrd in a signed recovery image. Leave acceptance
and cleanup pending. Record the attempt's time and `journalctl --list-boots`
output so its logs can be identified even if other generations were tried.

## 2. Validate the new desktop

Log in through the text login screen and open Alacritty with **Super+Enter**.
Collect the initial read-only checks:

```bash
scripts/nixosctl status
readlink -f /run/current-system
sudo cat /var/lib/nixos-deployment/staged.json
sudo bootctl status
nvidia-smi
hyprctl monitors
systemctl --failed
systemctl --user --failed
```

The running system must match the `system` path in the new staged receipt.
Secure Boot must remain enabled. Confirm the login screen is visible and Hyprland
reports HDMI-A-1 at 3840×2160, approximately 60 Hz and 8-bit SDR. Inspect any failed
units before acceptance. Check the HDMI workaround and kernel log:

```bash
sudo cat /sys/module/nvidia_modeset/parameters/disable_hdmi_frl
sudo cat /sys/module/nvidia_modeset/parameters/hdmi_deepcolor
journalctl -b -k --grep='nvidia|NVRM|HDMI'
```

The two parameter values should be `Y` and `N`, respectively. There should be no
new HDMI FRL link-training failure. A successful build or blind login alone is
not a successful display validation.

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
