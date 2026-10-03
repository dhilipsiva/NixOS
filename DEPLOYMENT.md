# Remaining desktop deployment

Run commands from `/home/dhilipsiva/projects/dhilipsiva/NixOS` as dhilipsiva.
Generation **11**, revision `0258f5db7c92b37f933841c4700a16f7b7ccb3e5`, is staged
and confirmed as the boot default. The protected recovery entry is present and
currently selected; it runs the original generation 2. Firmware preparation,
staging and the boot-menu check are complete. The remaining work is a manual boot
and physical validation. Completed preparation and boot evidence are recorded in
[SESSION.md](SESSION.md). Keep the recovery archive, owner age identity and recovery
media available.

## 1. Reboot manually into generation 11

The desktop configuration now disables NVIDIA HDMI FRL and deep colour and uses
**3840×2160 at 60 Hz, 8-bit SDR** for the connected Samsung Odyssey G81SF. This is
a temporary compatibility baseline; high refresh/HDR still need separate testing.
These settings are confined to the desktop host. The generation 11 boot entry
contains all three expected kernel parameters, but display validation is pending.

Save your work and reboot manually into **generation 11**. If the screen remains
blank or login is unusable, select
**NixOS (protected pre-migration recovery)** from the boot menu; it contains the
original generation 2 kernel/initrd in a signed recovery image, with entry ID
`nixos-protected-recovery.conf`. The separate old **generation 1/2** entries refer
to missing kernel/initrd files and are not usable fallbacks. Use the protected
recovery entry instead. Leave acceptance and cleanup pending if validation fails.
Record the attempt's time and `journalctl --list-boots`
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
For generation 11 this is
`/nix/store/z4bsvhjn75dcn1dyr3q4cq7cxjvqdrqy-nixos-system-dhilipsiva-desktop-26.05.20261002.774debe`.
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
