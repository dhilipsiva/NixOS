# Yoga Slim 7 host

The owner installed NixOS 26.05 on the Yoga with the official graphical
installer on 2026-10-04 (GNOME, generation 1) instead of the earlier signed and
encrypted plan. This repository captures that installation as it is:
`hosts/yoga/hardware-configuration.nix` and `hosts/yoga/installation.nix` were
generated and read on the laptop itself, and `nixosConfigurations.yoga` is a
real host. Nothing on its disk was repartitioned, formatted or encrypted, and no
firmware trust was changed. Credential enrollment, publication, boot
preparation, staging, the first reboot and physical acceptance are still
pending (see "Remaining steps").

## Inventory observed on 2026-10-04

| Item | Installed hardware or policy |
| --- | --- |
| Machine | Lenovo Yoga Slim 7 15ILL9, machine type `83HM`, board `LNVNB161216`, Insyde UEFI 2.90, BIOS `NYCN76WW` (2026-03-26) |
| CPU / RAM | Intel Core Ultra 7 258V, 8 cores / 8 threads; 32 GiB (30 GiB visible) |
| Graphics | Intel Arc (Lunar Lake) integrated GPU `8086:64a0` at `0000:00:02.0`, driver `xe`, `/dev/dri/card0` and `renderD128` |
| NPU | Intel NPU `8086:643e` at `0000:00:0b.0`, driver `intel_vpu`, `/dev/accel/accel0` |
| Panel | BOE `NS153B9M-K61` on eDP-1, 2880×1800, 330×206 mm (about 222 PPI) |
| Wi-Fi / Bluetooth | Intel Wi-Fi on `iwlwifi`/`iwlmld` (`wlp0s20f3`), Intel Bluetooth `8087:0037` |
| Camera / audio | Chicony UVC camera `04f2:b7f5`; SOF SoundWire audio (`cs42l43`, `cs35l56`) |
| SSD | Samsung `MZAL81T0HDLB-00BL2`, serial `S77LNF1X652296`, 1 TB; the only disk |
| ESP | 1 GiB FAT, UUID `73D4-F5E3`, mounted at `/boot` |
| Root | ext4 UUID `5054780a-381e-4518-8493-df4929682c36`, **not encrypted** |
| Swap partition | 8.8 GiB, UUID `71f0e008-aa66-4607-87b2-029119bb4548`; retained on disk, **not used** |
| Boot | systemd-boot 260.4, unsigned; Secure Boot disabled; no signing keys; TPM 2.0 present |
| Sleep / battery | `s2idle` only; BAT0 Celxpert `L23C4PF3`, about 64 Wh full / 70 Wh design |
| Windows | Absent: a single disk with only the three NixOS partitions |
| Original generation | 1: GNOME/GDM, NixOS 26.05.11150.825e2028c29b, Linux 6.18.55, hostname `nixos`, user `dhilipsiva` (uid 1000) |
| Compatibility | `system.stateVersion = "26.05"`, `home.stateVersion = "26.05"` |

## Decisions that differ from the earlier plan

- **Unencrypted root, installer partition layout.** The repository preserves
  the installed ext4 root, the 1 GiB ESP and the swap partition exactly as the
  installer created them. Moving to LUKS would be a reinstall; it is the
  owner's decision and has not been made. The host assertions and
  `tests/yoga-policies.nix` pin the captured UUIDs, `fsType`s and the absence
  of LUKS devices.
- **Unsigned systemd-boot with Secure Boot disabled**, the ThinkPad's boot
  policy. No signing keys exist on this machine, and `nixosctl`'s signed path
  requires Secure Boot to be enabled by an already signed generation before
  `prepare-boot`, which this installation cannot satisfy without an out-of-band
  bootloader install. Whether the Lenovo firmware can append a certificate
  without clearing trust is also unverified. A later signed migration is a
  separate attended task that needs tooling changes; it is not planned.
- **zram only.** One zstd zram device at 25 % of RAM (about 8 GiB), priority
  100, no writeback. The kernel parameter `systemd.swap=0` stops systemd's GPT
  auto-generator from activating the installer's swap partition by partition
  type; the partition itself is untouched and may be removed or reused by the
  owner later in an attended session.
- **Display.** Hyprland's automatic scale picks 2 above 200 PPI, so the panel
  runs at 1440×900 logical pixels; `hosts/yoga/graphics.nix` says where to
  override it (1.5 gives 1920×1200) after seeing it on the hardware. The text
  console and tuigreet use Terminus 12×24 (`ter-124n`) because the default
  16-pixel font is under 2 mm tall on this panel.
- `hosts/yoga/bootstrap.nix` and `tests/yoga-fixture.nix` are no longer used:
  the flake builds the real host, and no fixture or bootstrap is exposed as a
  deployable host. They were left in the tree for the owner to delete.

## Configured behavior

- Stable kernel (`pkgs/kernel.nix`), upstream `xe`, redistributable firmware
  and Intel microcode, Mesa OpenGL/Vulkan including 32-bit, Intel media and
  compute runtimes. No NVIDIA, PRIME, NVENC or Dynamic Boost configuration.
- Hyprland/UWSM and the shared `dhilipsiva` environment with the preferred
  panel mode and automatic scale, the battery indicator and brightness keys.
- Power Profiles Daemon (balanced on a new installation; `low-power`,
  `balanced` and `performance` are offered by the firmware), thermald, lid
  close suspends when undocked and is ignored when docked, displays lock and
  turn off after 300 seconds, no hibernation.
- Native OBS with a writable initial **Yoga** recording profile: H.264 VA-API,
  1080p30, MKV. Select that profile and the Intel render device after capture;
  configure PipeWire screen/audio sources interactively.
- User-scoped Sober, installed on 2026-10-04 from Flathub as `org.vinegarhq.Sober`
  1.8.0 with the Freedesktop 26.08 runtime, Mesa 26.2.2 and Intel VA-API
  extensions, with a launcher searchable as **Roblox (Sober)**.
- Intel NPU driver/firmware 1.38.0, its checksum-pinned compiler and OpenVINO
  2026.4.1's NPU plugin; `npu-smoke` compiles and runs a tiny graph explicitly
  on `NPU` and rejects other devices.
- Ollama with the Vulkan runner, socket activation, five-minute idle stop and
  model unloading after each request. Arc offload must be verified on hardware.
- Shared defaults: userborn accounts with the sops-nix login hash, sudo-rs,
  NetworkManager with systemd-resolved and an nftables firewall with no open
  ports (sshd runs for the host key only), rootless Docker, Bluetooth, fwupd,
  tmpfs `/tmp`, Nix 2.35 with flakes, greetd/tuigreet. GNOME, GDM, CUPS and the
  `en_IN` locale of the installer configuration are not carried over; the
  hostname becomes `dhilipsiva-yoga`, the locale `en_US.UTF-8`, the time zone
  stays `Asia/Kolkata`. The saved Wi-Fi profile lives in
  `/etc/NetworkManager/system-connections` and persists across generations.
  `/etc/nixos/configuration.nix` from the installer stays on disk unused.

## Repository verification (2026-10-04)

Verified on the Yoga itself, from a scratch copy of this working tree that
carried a throwaway fixture `secrets/yoga.yaml` (the real host refuses to
evaluate without that file, by design): the Yoga system built as
`nixos-system-dhilipsiva-yoga-26.05.20261002.774debe` with Linux 7.2.9 from the
binary cache, its boot entry carries `systemd.swap=0`, and the desktop and
ThinkPad systems built unchanged. The complete `nix flake check` passed:
formatting (nixfmt, deadnix, ruff), repository workflow and secret-encryption
tests, stable releases, host and Yoga policies, Hyprland Lua for all three
hosts, Zellij, the Ollama on-demand VM, the NPU runtime library check and the
desktop login VM (that VM test failed once while the other builds were running
and passed on a clean re-run; its derivation is identical to the previous
commit). `update-stable-releases.py --verify` matched every official channel.
The light checks also pass on the real tree. Nothing was staged or switched.
The `nix flake check --no-build` form fails locally on the desktop-login
fixture derivation with Nix 2.34 on the previous commit too; use the full
check or `nixosctl check`.

## Remaining steps

The real host cannot evaluate until `secrets/yoga.yaml` exists, so the capture
and the credentials must be published together.

1. **Enroll credentials** (asks for your sudo password; reads the installed
   login hash from `/etc/shadow` in memory, creates the owner identity
   `~/.config/sops/age/keys.txt` if missing, converts the SSH host key that the
   installer's sshd already generated, writes `secrets/yoga.yaml` and the
   `yoga` rule in `.sops.yaml`):

   ```bash
   cd /home/dhilipsiva/projects/dhilipsiva/NixOS
   scripts/nixosctl prepare-credentials --host yoga
   ```

   Back up `~/.config/sops/age/keys.txt` off-device afterwards.
2. **Commit** the capture together with the ciphertext (one commit):
   `flake.nix`, `hosts/yoga/*.nix`, `tests/yoga-policies.nix`, `.sops.yaml`,
   `secrets/yoga.yaml`, `.github/workflows/check.yml` and the documents.
3. **Publish.** This clone uses the HTTPS origin and `publish` pushes with
   terminal prompts disabled, so add a push credential first (an SSH key
   registered with GitHub plus an SSH push URL, or a credential helper). Then:

   ```bash
   scripts/nixosctl check --stable
   scripts/nixosctl publish
   ```

4. **Prepare boot** (unsigned mode: requires Secure Boot to stay disabled,
   backs up the ESP and firmware variables, protects generation 1 as the
   recovery root; no `--windows-status` is needed):

   ```bash
   scripts/nixosctl prepare-boot --host yoga
   ```

5. **Stage and reboot manually.** Staging checks the published revision, the
   board name, both filesystem UUIDs, the decrypted password, the user Flatpak
   and ESP space, prints the closure diff, installs the boot entries and the
   protected recovery entry, and restores the previous profile and ESP on
   failure. Never use `switch`.

   ```bash
   scripts/nixosctl stage --host yoga
   systemctl reboot
   ```

## Physical acceptance checklist (all pending)

- tuigreet login, sudo, `systemctl --failed` and `systemctl --user --failed`
  empty; `sops-install-secrets-for-users.service` and `userborn.service` ok.
- Wi-Fi reconnects automatically; audio output, microphone, camera, touchpad,
  brightness keys, battery indicator; `hyprctl monitors` shows eDP-1 at
  2880×1800 with scale 2 (decide whether to keep it).
- `swapon --show` lists only `/dev/zram0`; `cat /proc/cmdline` contains
  `systemd.swap=0`; `zramctl` shows zstd, priority 100.
- Undocked lid-close suspend/resume on AC and battery; docked lid stays awake;
  lock and display off after five minutes; no hibernation.
- `lspci -nnk` reports `xe`; `vulkaninfo --summary` reports Intel Arc, not
  llvmpipe; `vainfo` lists H.264 encode.
- Launch **Roblox (Sober)** from Fuzzel, log in and play an actual game.
- Select the **Yoga** OBS profile and the Intel VA-API render device, record
  and play back a PipeWire capture with audio; the log must report VA-API
  hardware encoding.
- Run `npu-smoke` as `dhilipsiva`; it must complete inference on `NPU`. Then
  check the `intel_vpu` device's `power/runtime_status`.
- Pull a small Ollama model, run inference, confirm Vulkan/Arc offload in the
  service log and that `ollama.service` stops after the idle timeout.
- Boot **NixOS (protected pre-migration recovery)** (the GNOME generation) once
  and return to the staged generation.

Only after all checks pass, on the Yoga:

```bash
scripts/nixosctl accept --host yoga --physical-checks-passed
```

Acceptance enables the 21:30 Asia/Colombo subscriber updates and the guarded
30-day cleanup. A successful build is not a successful deployment.

## Recovery

Select **NixOS (protected pre-migration recovery)** in the boot menu for the
original GNOME generation, or an earlier generation from the systemd-boot menu.
If the system does not boot, start the verified installer USB (SanDisk Cruzer
Blade, serial `4C531001530918117442`, NixOS 26.05.11150.825e2028c29b), mount the
root by UUID `5054780a-381e-4518-8493-df4929682c36` and the ESP by UUID
`73D4-F5E3`, and repair from there. Never format, repartition or copy another
host's UUIDs or keys as a recovery step. Keep Secure Boot disabled: the loader
and generations are unsigned.
