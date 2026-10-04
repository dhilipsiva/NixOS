# Remaining desktop deployment

Run commands from `/home/dhilipsiva/projects/dhilipsiva/NixOS` as dhilipsiva.
Generation **12** is running, confirmed on 2026-10-04. Its system path is
`/nix/store/r5ycb7kq8nhd7hgzh2h9k9g3yzzb15gc-nixos-system-dhilipsiva-desktop-26.05.20261002.774debe`.
The reduced-effects profile is active: animations and shadows are disabled,
rounding is zero and `debug.vfr` is enabled. HDMI-A-1 retains 3840×2160/60 Hz,
8-bit SDR. Secure Boot is enabled and system/user failed-unit lists are empty.

The owner restored Wi-Fi by draining motherboard power for about one minute.
The Qualcomm WCN7850 is detected again and `wlp8s0` is connected using
`ath12k_wifi7_pci`. Wi-Fi recovery and staging the reduced-effects profile are
complete. Evidence and earlier recovery history are in [SESSION.md](SESSION.md).

## 1. Restore full CPU availability

The CPU issue remains unresolved. Both the agent and the owner's separate
terminal report eight cores and eight logical CPUs, with SMT `notsupported`.
The boot log activated only eight processors and the system-wide `possible`
CPU list is `0-7`. This is not a per-process CPU-affinity limit. AMD specifies
[16 cores and 32 threads for the 9950X3D](https://shop-us-en.amd.com/amd-ryzen-9-9950x3d-processor/).
Those are the expected capabilities, not the currently enabled configuration.

The owner reports **X3D Gaming Mode was enabled before this boot**.
[MSI documents that this mode changes core and SMT settings](https://us.msi.com/blog/how-to-boost-amd-ryzen-9-9950x3d-gaming-performance),
making it the leading explanation. Recovery still needs an actual boot with the
mode disabled. AMD P-State, the performance governor/EPP and frequency boost are
already active; the Nix configuration and running kernel command line contain no
core-count limit or SMT-disabling setting.

Generation 2's Linux 6.18.1 boot log also activated only eight CPUs. The current
kernel has `CONFIG_NR_CPUS=384` and `CONFIG_SCHED_SMT=y`, so it is not built with
an eight-CPU ceiling or without SMT support.

The X3D optimizer is also already loaded: module `amd_3d_vcache` is bound to
`AMDI0101:00`, its `amd_x3d_mode` reports `frequency`, and AMD P-State `prefcore`
reports `enabled`. CPPC/core-affinity tools tune work placement on available cores;
they cannot expose cores disabled by firmware. Do not add
`processor.max_cstate=1` for this issue: it limits CPU idle states and does not
restore cores or SMT. These controls are separate from system suspend.

Save work and enter MSI BIOS manually with **Delete** during boot. Disable
**X3D Gaming Mode**, save that change with **F10**, and boot generation 12 again.
Use **F7** for Advanced mode and **Ctrl+F** to search if needed. Preserve Secure
Boot keys and existing boot/storage settings; do not reset CMOS or load firmware
defaults. No Nix rebuild is needed for this BIOS test.

After login, verify:

```bash
LC_ALL=C lscpu | rg 'CPU\(s\)|Core\(s\)|Thread\(s\)|Socket\(s\)'
cat /sys/devices/system/cpu/possible
cat /sys/devices/system/cpu/online
cat /sys/devices/system/cpu/smt/active
cat /sys/devices/system/cpu/smt/control
```

Expected after recovery: **32 CPUs, 16 cores per socket, 2 threads per core**,
CPU lists `0-31`, SMT active `1` and control `on`. If the counts remain limited,
record the BIOS settings for **CCD0 Core Control / CCD1 Core Control** (Auto/all
cores on both CCDs) and **SMT Control** (Enabled, or Auto where that enables it).
The [MSI AMD 800 BIOS guide](https://download.msi.com/archive/mnu_exe/mb/AMDAM5800BIOS_English.pdf)
lists these controls on page 38; exact menus/options vary by BIOS version. Their
current values have not been inspected. A Nix build alone cannot confirm that
firmware has exposed the missing cores.

## 2. Finish the remaining physical checks

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

The running system must match the `system` path in the staged receipt. Recheck
Secure Boot, display and Wi-Fi after any CPU firmware changes. Higher refresh/HDR
is a separate future test; the working HDMI FRL workaround stays enabled.

- Finish checking sudo, Atuin history, zoxide/ripgrep, audio and the UPS.
- Confirm the screen locks/powers off after five minutes while the machine keeps
  running without suspend or hibernation.
- Check read-only Windows file copying and Secure Boot status/signatures.
- Exercise Ollama with a real model: its backend was confirmed idle before use;
  verify request startup, model unloading after a default request and stopping
  after idle connections close.
- Check Slack and Teams sign-in, microphone, camera and screen sharing.

If recovery is needed, select **NixOS (protected pre-migration recovery)**, which
contains the original generation 2 in `/EFI/nixos-recovery/pre-migration.efi`.
The separate legacy generation 1/2 entries have missing files and are not usable
fallbacks. Keep the recovery archive, owner age identity and recovery media.

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
