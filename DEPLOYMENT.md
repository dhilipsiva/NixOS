# Remaining desktop deployment

Run commands from `/home/dhilipsiva/projects/dhilipsiva/NixOS` as dhilipsiva.
Generation **11**, revision `0258f5db7c92b37f933841c4700a16f7b7ccb3e5`, is running.
The owner reports a working session. NVIDIA 595.104.02 drives the RTX 5090 and
HDMI-A-1 at 3840×2160/60 Hz, 8-bit SDR. Secure Boot is enabled; system/user failed
unit lists are empty and no NVIDIA HDMI link failure appears in this boot's log.
Full deployment acceptance still awaits the remaining physical checks below.
Completed preparation and boot evidence are in [SESSION.md](SESSION.md).

## 1. Stage the reduced-effects profile

The published configuration disables Hyprland/Hyprlock animations, window shadows,
glow and rounded corners, and Waybar transitions. Blur remains off, window opacity
is 1, and Hyprland renders on damage with `debug.vfr = true`. The working HDMI
settings, five-minute display policy and NVIDIA driver are retained.

From your local terminal:

```bash
scripts/nixosctl stage --host desktop
sudo bootctl list
```

Confirm the newly staged generation is the default and the protected recovery
entry remains present. Save your work and reboot manually into the new generation.
If needed, **NixOS (protected pre-migration recovery)** contains the original
generation 2 in `/EFI/nixos-recovery/pre-migration.efi`. The separate legacy
generation 1/2 entries have missing files and are not usable fallbacks. Keep the
recovery archive, owner age identity and recovery media available.

## 2. Verify the new profile and remaining hardware behavior

After login, open Alacritty with **Super+Enter**:

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
Check that window/workspace changes are immediate and shadows/rounded corners are
gone. Verify the active options:

```bash
hyprctl getoption animations:enabled
hyprctl getoption decoration:shadow:enabled
hyprctl getoption decoration:rounding
hyprctl getoption debug:vfr
```

Expect `false`, `false`, `0`, and `true`, respectively. Secure Boot must remain
enabled and HDMI-A-1 must retain the working 4K60/8-bit mode. Inspect failed units
or new display errors before acceptance. Higher refresh/HDR is a separate future
test; the FRL workaround stays enabled for this rollout.

- Finish checking sudo, Atuin history, zoxide/ripgrep, networking, audio and the UPS.
- Confirm the screen locks/powers off after five minutes while the machine keeps
  running without suspend or hibernation.
- Check read-only Windows file copying and Secure Boot status/signatures.
- Exercise Ollama with a real model: its backend was confirmed idle before use;
  verify request startup, model unloading after a default request and stopping
  after idle connections close.
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
