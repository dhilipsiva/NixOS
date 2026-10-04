# Yoga Slim 7 host

The owner installed NixOS 26.05 on the Yoga with the official graphical
installer on 2026-10-04 (GNOME, generation 1) instead of the earlier signed and
encrypted plan. This repository captures that installation as it is:
`hosts/yoga/hardware-configuration.nix` and `hosts/yoga/installation.nix` were
generated and read on the laptop itself, and `nixosConfigurations.yoga` is a
real host. Nothing on its disk was repartitioned, formatted or encrypted, and no
firmware trust was changed.

Deployment state: credentials enrolled, `1ee1bc2` published, boot prepared,
staged and booted on 2026-10-04. The runtime audit on that generation (below)
produced the hardware-tuning commit that follows it; publishing and staging that
commit and the physical acceptance are still pending (see "Operator steps").

## Inventory observed on 2026-10-04

| Item | Installed hardware or policy |
| --- | --- |
| Machine | Lenovo Yoga Slim 7 15ILL9, machine type `83HM`, board `LNVNB161216`, Insyde UEFI 2.90, BIOS `NYCN76WW` (2026-03-26, current on LVFS) |
| CPU / RAM | Intel Core Ultra 7 258V, 8 cores / 8 threads (P-cores to 4.7 GHz); 32 GiB (30 GiB visible) |
| Graphics | Intel Arc 140V (Lunar Lake) integrated GPU `8086:64a0` at `0000:00:02.0`, driver `xe`, Mesa 26.1.8 Vulkan 1.4 |
| NPU | Intel NPU `8086:643e` at `0000:00:0b.0`, driver `intel_vpu`, firmware `vpu_40xx_v1.bin`, `/dev/accel/accel0` |
| Panel | BOE `NS153B9M-K61` on eDP-1, 2880×1800, 330×206 mm (about 222 PPI), modes 60 Hz (preferred) and 120 Hz, EDID range 30–120 Hz with continuous frequency (VRR) |
| Wi-Fi / Bluetooth | Intel Wi-Fi 7 BE201 320 MHz on `iwlwifi`/`iwlmld` (`wlp0s20f3`), Intel Bluetooth `8087:0037` |
| Camera / audio | Chicony UVC camera `04f2:b7f5`; SOF SoundWire audio (`cs42l43`, `cs35l56`), firmware 2.14.1.1 |
| SSD | Samsung `MZAL81T0HDLB-00BL2`, serial `S77LNF1X652296`, 1 TB; the only disk; `none` scheduler, weekly TRIM |
| ESP | 1 GiB FAT, UUID `73D4-F5E3`, mounted at `/boot` |
| Root | ext4 UUID `5054780a-381e-4518-8493-df4929682c36`, **not encrypted** |
| Swap partition | 8.8 GiB, UUID `71f0e008-aa66-4607-87b2-029119bb4548`; retained on disk, **not used** |
| Boot | systemd-boot, unsigned; Secure Boot disabled; no signing keys; TPM 2.0 present |
| Thunderbolt | USB4 domain, firmware security level `user` |
| Sleep / battery | `s2idle` (Low-power S0 idle); BAT0 Celxpert `L23C4PF3`, about 64 Wh full / 70 Wh design |
| Windows | Absent: a single disk with only the three NixOS partitions |
| Original generation | 1: GNOME/GDM, NixOS 26.05.11150.825e2028c29b, Linux 6.18.55, hostname `nixos`, user `dhilipsiva` (uid 1000) |
| Compatibility | `system.stateVersion = "26.05"`, `home.stateVersion = "26.05"` |

## Decisions

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
- **zram only.** One zstd zram device at 25 % of RAM (7.7 GiB), priority 100,
  no writeback. The kernel parameter `systemd.swap=0` stops systemd's GPT
  auto-generator from activating the installer's swap partition by partition
  type (verified after the first boot: only `/dev/zram0` is active); the
  partition itself is untouched and may be removed or reused by the owner
  later in an attended session.
- **Release-branch Intel media and compute runtimes.** The prepared host took
  `intel-media-driver` and `intel-compute-runtime` from `nixpkgs-apps` (master).
  On the hardware, master's media driver 26.2.4 exports `__vaDriverInit_1_24`
  for libva 2.24 while 26.05 ships libva 2.23, so `vainfo` failed and every
  VA-API user fell back to software; master's compute runtime 26.31 aborted in
  `command_stream_receiver.cpp` on `clinfo`. The release builds (26.1.6 and
  26.18.38308.1) were tested on the Arc 140V with the installed libva: H.264,
  HEVC, HEVC 10-bit, VP9 and AV1 decode, H.264/HEVC/AV1 encode and OpenCL
  enumeration. `level-zero` stays on `nixpkgs-apps` (1.32.0) because the NPU
  driver, its compiler and OpenVINO are built against that loader; the compute
  runtime is overridden to the release `level-zero` build input so it is the
  exact binary-cached derivation that was tested. The policy test pins both
  packages to the release store paths.
- **Display.** Hyprland's automatic scale picks 2 above 200 PPI, so the panel
  runs at 1440×900 logical pixels; the owner kept it after seeing it. The
  monitor rule uses `highrr` for the panel's 120 Hz mode (the EDID-preferred
  mode is 60 Hz), `vrr = 2` for adaptive sync only while a window is
  fullscreen, and `render.direct_scanout = 2` (auto) as on the desktop. The
  text console and tuigreet use Terminus 12×24 (`ter-124n`).
- **Ollama on the integrated GPU.** Ollama 0.35 drops integrated GPUs unless
  `OLLAMA_IGPU_ENABLE=1`; the service ran on CPU. With the variable, the
  Vulkan runner reports `Vulkan0 Intel(R) Graphics (LNL)` with about 21 GiB of
  shared memory available (verified with a temporary user-level server).
- **All cores for one build.** `nix.settings.cores = 0` with `max-jobs = 1`;
  the daemon's CPU/IO weights of 50 keep the session responsive.
- **Thunderbolt.** `services.hardware.bolt` on the Yoga only, so USB4 and
  Thunderbolt docks can be authorised with `boltctl` at security level `user`.
- **5 GHz Wi-Fi band is a local NetworkManager setting**, not a Nix change:
  CLAUDE.md keeps Wi-Fi profiles in the host's local store. The SSID
  `C-008 One Piece` is visible on 2.4 GHz (channel 4) and 5 GHz (channel 153).
- **Battery conservation mode** (Lenovo charge limit): declined by the owner,
  not configured.
- `hosts/yoga/bootstrap.nix` and `tests/yoga-fixture.nix` are no longer used:
  the flake builds the real host, and no fixture or bootstrap is exposed as a
  deployable host. They were left in the tree for the owner to delete.

## Configured behavior

- Stable kernel (`pkgs/kernel.nix`), upstream `xe`, redistributable firmware
  and Intel microcode (0x128 loaded early), Mesa OpenGL/Vulkan including
  32-bit, release-branch Intel media driver 26.1.6 and compute runtime
  26.18.38308.1 with the Level Zero loader from `nixpkgs-apps`. No NVIDIA,
  PRIME, NVENC or Dynamic Boost configuration.
- Hyprland/UWSM and the shared `dhilipsiva` environment: the panel's 120 Hz
  mode, fullscreen-only adaptive sync, automatic direct scanout, automatic
  scale (2), the battery indicator and brightness keys.
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
  on `NPU` and rejects other devices (it accepts the plain string OpenVINO
  returns for a single execution device).
- Ollama with the Vulkan runner and `OLLAMA_IGPU_ENABLE=1`, socket activation,
  five-minute idle stop and model unloading after each request.
- One Nix build may use all eight cores; bolt manages Thunderbolt
  authorisation; `clinfo`, `vainfo` and `intel_gpu_top` are in the user profile
  for the acceptance checks.
- Shared defaults: userborn accounts with the sops-nix login hash, sudo-rs,
  NetworkManager with systemd-resolved and an nftables firewall with no open
  ports (sshd runs for the host key only), rootless Docker, Bluetooth, fwupd,
  tmpfs `/tmp`, Nix 2.35 with flakes, greetd/tuigreet. GNOME, GDM, CUPS and the
  `en_IN` locale of the installer configuration are not carried over; the
  hostname is `dhilipsiva-yoga`, the locale `en_US.UTF-8`, the time zone
  `Asia/Kolkata`. The saved Wi-Fi profile lives in
  `/etc/NetworkManager/system-connections` and persists across generations.
  `/etc/nixos/configuration.nix` from the installer stays on disk unused.

## Runtime audit (2026-10-04, running 1ee1bc2)

Checked on the booted generation `vs793z6…-nixos-system-dhilipsiva-yoga`:

- Working as intended: no failed units; `intel_pstate` active with HWP, turbo
  on, EPP `balance_performance` on AC, Power Profiles Daemon on the firmware's
  platform profiles, thermald (polling mode), microcode updated early, S0ix
  idle; `xe` with GuC/DMC firmware, Vulkan 1.4 on `Intel(R) Graphics (LNL)`;
  NPU firmware loaded and the device at runtime suspend when idle; zram the
  only swap with swappiness 180; NVMe `none` scheduler and the TRIM timer;
  Wi-Fi 7 firmware 106, Bluetooth, SOF audio with speaker and microphone, UVC
  camera; LVFS reports no pending firmware.
- Defects found and fixed in the hardware-tuning commit: VA-API unusable
  (libva ABI mismatch), OpenCL aborting, panel at 60 Hz, Ollama on CPU, half the
  cores for builds, no Thunderbolt authorisation daemon, and the `npu-smoke`
  probe rejecting its own successful `NPU` result (OpenVINO returns a string for
  a single execution device). With the probe fixed, inference passed on
  "Intel(R) AI Boost" in 0.2 s and the NPU returned to runtime suspend.
- Not a Nix change: the laptop associates on 2.4 GHz; the 5 GHz band step is
  below.

Repository verification of the tuning commit is recorded in the commit's
message and SESSION.md; the checks are the same as for the capture:
`nix fmt`, the full `nix flake check` (both VM tests), `nixosctl check
--stable`, and `nix eval` of the Yoga's `intel-media-driver` and
`intel-compute-runtime` output paths equal to the release builds that were
tested on the hardware. The `nix flake check --no-build` form fails locally on
the desktop-login fixture derivation with Nix 2.34 on earlier commits too; use
the full check or `nixosctl check`.

## Operator steps for the tuning commit

```bash
cd /home/dhilipsiva/projects/dhilipsiva/NixOS
scripts/nixosctl stage --host yoga      # sudo; expect intel-media-driver 26.2.4→26.1.6,
                                        # intel-compute-runtime 26.31→26.18, bolt added
systemctl reboot
```

After the reboot, run the acceptance checklist below. The Wi-Fi band change is
local to NetworkManager (never committed):

```bash
nmcli connection modify "C-008 One Piece" 802-11-wireless.band a
nmcli connection up "C-008 One Piece"
nmcli -f IN-USE,SSID,CHAN,FREQ,SIGNAL device wifi list   # the * row on channel 153
```

Revert with `nmcli connection modify "C-008 One Piece" 802-11-wireless.band ""`
and reconnect if 5 GHz is unreliable.

## Physical acceptance checklist

- `readlink -f /run/current-system` equals the staged path; tuigreet login,
  sudo, `systemctl --failed` and `systemctl --user --failed` empty;
  `sops-install-secrets-for-users.service` and `userborn.service` ok.
- Wi-Fi reconnects automatically (on channel 153 after the band step); audio
  output, microphone, camera, touchpad, brightness keys, battery indicator.
- `hyprctl monitors` shows eDP-1 at `2880x1800@120.00` with scale 2; `vrr`
  turns true only while a window is fullscreen.
- `swapon --show` lists only `/dev/zram0`; `cat /proc/cmdline` contains
  `systemd.swap=0`; `zramctl` shows zstd, priority 100.
- Undocked lid-close suspend/resume on AC and battery; docked lid stays awake;
  lock and display off after five minutes; no hibernation.
- `lspci -nnk` reports `xe`; `vulkaninfo --summary` reports Intel Arc, not
  llvmpipe; `vainfo` loads iHD 26.1.6 without a `__vaDriverInit` error and
  lists H.264/HEVC/HEVC10/VP9/AV1 decode and H.264/HEVC/AV1 encode;
  `clinfo -l` lists `Intel(R) OpenCL Graphics` with `Intel(R) Arc(TM) Graphics`.
- `nix config show cores` prints 0; `systemctl status bolt` is active and
  `boltctl domains` lists the host domain (`boltctl list` is empty without a
  dock).
- Launch **Roblox (Sober)** from Fuzzel, log in and play an actual game.
- Select the **Yoga** OBS profile and the Intel VA-API render device, record
  and play back a PipeWire capture with audio; the log must report VA-API
  hardware encoding.
- Run `npu-smoke` as `dhilipsiva`; it prints `execution=['NPU']`. Then check
  the `intel_vpu` device's `power/runtime_status` returns to `suspended`.
- Pull a small Ollama model, run inference, confirm `Vulkan0 Intel(R) Graphics
  (LNL)` in `journalctl -u ollama -b` and that `ollama.service` stops after
  the idle timeout.
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
