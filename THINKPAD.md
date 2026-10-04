# ThinkPad migration and rollout

This upgrades an existing encrypted NixOS installation. Preserve the owner's
development tools and their child's Roblox and OBS setup. Never repartition,
reinstall, change LUKS keyslots or import the desktop's hardware configuration.

## Inventory observed on 2026-10-04

| Item | Installed hardware or policy |
| --- | --- |
| Machine | ThinkPad T15g Gen 2i; model/board `20YSS01K00` |
| CPU / RAM | Intel i7-11850H, 8 cores / 16 threads; 16 GiB |
| Graphics | Intel UHD `PCI:0:2:0`; NVIDIA RTX 3070 Mobile `PCI:1:0:0` |
| Panel | Intel-connected eDP-1; NVIDIA also has external connectors |
| Wi-Fi | Intel AX210, iwlwifi |
| Root encryption | LUKS UUID `4a7c2f90-d44a-479c-82f6-f764d6cab51d`, mapper `root` |
| Root filesystem | ext4 UUID `84250d8e-f63c-4427-99dd-db945a069258` |
| EFI partition | 511 MiB FAT, UUID `BE19-6095`, mounted at `/boot` |
| Boot | systemd-boot; Secure Boot disabled; existing firmware trust retained |
| Swap / sleep | No disk swap; deep suspend available |
| Battery | BAT0; about 74 Wh full / 94 Wh design |
| Original generation | 291; NixOS 26.11 prerelease, Linux 6.18.43 |
| System compatibility | Preserve `system.stateVersion = "24.11"` |
| Home compatibility | Owner selected `home.stateVersion = "26.05"` |

The old standalone Home Manager profile reports release 24.05, but its original
compatibility setting could not be recovered. The owner's selection of 26.05 is
a new managed-home baseline. The old profile remains a recovery GC root.

## Configured behavior

`hosts/thinkpad/` uses the shared stable software and Hyprland/UWSM configuration,
Intel desktop graphics and NVIDIA PRIME offload. The production NVIDIA driver is
built against the selected stable kernel. Desktop HDMI, AMD performance and
no-sleep settings are not imported. Builds use one job / four cores.

The ThinkPad explicitly uses compositor scale **1 (100%, unscaled)** for all
outputs at their preferred resolution, replacing the shared automatic scaling
rule. This is declared only in `hosts/thinkpad/graphics.nix`; the desktop keeps
its independent 1.5 scale. Host-policy checks guard both settings.

Host-specific udev aliases select Intel first in `AQ_DRM_DEVICES`, retaining
NVIDIA for its external display connectors. This follows the
[Hyprland multi-GPU configuration](https://wiki.hypr.land/configuring/extra/multi-gpu/)
without relying on changeable `card0`/`card1` numbering.

The selected laptop policy locks and powers off the display after five idle
minutes, honoring inhibitors. Lid-close suspends when undocked, including on AC;
it is ignored while docked. There is no idle suspend or hibernation. Battery and
brightness controls are enabled. Suspend/resume requires physical validation.

### Roblox and OBS

- Preserve the existing **user** Flatpak `org.vinegarhq.Sober`, its stable
  installation, account data, overrides, launcher and Roblox URL handling.
  Native Vinegar is also retained; it is not the installed Roblox Player.
- Staging requires the installed NVIDIA Flatpak graphics runtime to match the
  candidate driver. Keep the old runtime for recovery; do not uninstall app data.
- Native OBS uses the verified stable package. Preserve its original x264
  settings, profiles/scenes and `/home/dhilipsiva/recordings`. The ThinkPad-only
  `cudaSupport` package override adds the driver search path to OBS executables,
  including the NVENC capability helper. This fixes the missing
  `libnvidia-encode.so.1` lookup observed during the hardware audit; no global
  `LD_LIBRARY_PATH` override is used. Recording still requires a physical test.
- On the first new boot, Home Manager runs `scripts/migrate-home.py` before
  linking managed files. It privately backs up `~/.files/.config`, imports
  unmanaged settings into `~/.config` and retains existing destination files on
  collisions. Active legacy OBS settings take precedence, with any previous
  destination saved separately. A completion marker prevents repeated imports.
- Backups and collision reports are under
  `~/.local/state/nixosctl/home-migration/`. Private application data never enters
  Git or the Nix store. The original configuration tree remains available for
  generation 291. No global `XDG_CONFIG_HOME` override is retained.

### Hardware acceleration and compressed swap

The ThinkPad enables NVIDIA Dynamic Boost through `nvidia-powerd`; the laptop
reports firmware support for it. Intel-first graphics, NVIDIA PRIME offload,
idle GPU power management and the balanced CPU power profile remain unchanged.
Performance improvements must be measured under actual load, not assumed from
the service being enabled.

One RAM-only zram swap device uses zstd compression, priority 100 and a logical
capacity of 25% of RAM (about 4 GiB). This is not a reservation of 4 GiB of
physical RAM; usage grows with compressed pages. There is no disk swap or
writeback device. LUKS, discard policy, filesystems, hibernation, thermald and
OOM-killer policy are unchanged. These settings do not affect the desktop.

After publishing, staging and manually booting this hardware-tuning generation:

1. Confirm the running system matches the staged receipt. Check
   `systemctl status nvidia-powerd.service`, `swapon --show` and `zramctl`.
   Expect an active power daemon and one zstd zram swap device at priority 100,
   approximately one quarter of RAM, with no disk swap.
2. Run `env -u LD_LIBRARY_PATH /run/current-system/sw/bin/obs-nvenc-test`.
   Expect `nvenc_supported=true` and H.264/HEVC support. The RTX 3070 does not
   provide AV1 encoding. This capability test does not record or stream.
3. Close OBS, then back up its configuration privately before creating a profile:

   ```bash
   umask 077
   backup=$(mktemp -d "$HOME/.local/state/nixosctl/obs-before-nvenc.XXXXXXXX")
   cp -a -- "$HOME/.config/obs-studio" "$backup/"
   ```

   Keep this backup local and outside Git/the Nix store; it may contain stream
   credentials. No Home Manager activation changes OBS profiles or encoders.
4. Open OBS and use **Profile → Duplicate** on the original **Untitled** profile,
   naming the copy **ThinkPad NVENC**. If that copy already exists, use it rather
   than overwriting it. Retain the current scene collection. In **Settings →
   Output**, keep Simple mode and set both recording and streaming encoders to
   **Hardware (NVENC, H.264)**. Keep P5, 1080p60, the recording destination,
   hybrid MP4 container, quality, audio settings and bitrates unchanged. Do not
   start a live stream.
5. Record a short Roblox gameplay session to `/home/dhilipsiva/recordings`, play
   it back, and verify video, game audio and microphone where configured. Check
   OBS's log/statistics for encoder errors and rendering/encoding lag. Keep the
   NVENC profile selected for normal use only after this succeeds; otherwise
   return to **Untitled**, leaving the original profile and scenes intact.
6. After closing GPU applications and allowing idle time, check
   `/sys/bus/pci/devices/0000:01:00.0/power/runtime_status` for `suspended`.
   Avoid polling `nvidia-smi` during this check because it wakes the GPU. Retest
   lid suspend/resume and inspect failed system/user services. Retain the
   protected recovery generation; no live switch or automatic reboot is used.

The flake's `obs-nvenc-runpath` check verifies the actual capability helper's ELF
driver search path without requiring GPU access in the build sandbox. Host-policy
checks guard Dynamic Boost, zram, encrypted-storage and suspend settings. Physical
recording, GPU power and suspend validation for these changes remains separate
from the already accepted migration.

## Preparation and verification

Work at `/home/dhilipsiva/projects/dhilipsiva/NixOS` as dhilipsiva. The owner
completed these commands on 2026-10-04:

```bash
scripts/nixosctl prepare-credentials --host thinkpad
scripts/nixosctl prepare-boot --host thinkpad
```

Enrollment generated independent laptop/owner identities and verified the
encrypted password against the installed account. No laptop UPS secret is needed.
The owner confirmed an external backup of `~/.config/sops/age/keys.txt` after
accepting the migration. Never copy desktop private keys onto this host.

Boot preparation protected generation 291 and the existing home/profile roots,
backed up the ESP and recorded the firmware trust and encrypted layout. It did
not stage a generation. Staging installs a protected recovery boot entry outside
normal rotation, retaining the original kernel, initrd and encrypted-root command
line. The desktop continues to require its signed recovery UKI.

The existing Wi-Fi profile reports autoconnect enabled, unrestricted users and
password flags `0`. Its password stays in the local NetworkManager store; Wi-Fi
was connected after the accepted migration's reboots.

Before publishing, check/build both hosts and repeat verification in a clean
tracked checkout:

```bash
nix flake check .
scripts/nixosctl check --stable
scripts/nixosctl publish
```

The checks cover both Hyprland configurations, stable releases, encrypted
credentials, recovery, staging failures, home migration and Ollama's lifecycle.
Git publication uses this laptop's own credentials. Missing credentials or failed
checks block publication and staging.

## Stage, reboot and accept

Only after publication succeeds:

```bash
scripts/nixosctl stage --host thinkpad
```

The helper checks the exact published revision, board/filesystems/LUKS mapping,
boot policy, password decryption, Sober graphics runtime and ESP space. It restores
the previous system profile and ESP on staging failure. Three regular generations
plus protected recovery fit the smaller ESP, subject to the actual space check.
Never stage the desktop here, live-switch or reboot automatically.

After a manual reboot:

1. Confirm the original disk passphrase unlocks the existing root and login works.
2. Check Wi-Fi autoconnect, display, audio/microphone, brightness, battery and
   lid suspend/resume; test an external display if used.
3. Launch Sober from the launcher and play Roblox. Verify NVIDIA offload and
   account access without deleting its existing application data.
4. Open OBS and confirm its original profile/scenes and recording destination.
   Record gameplay with PipeWire capture and play it back, checking video, game
   audio and microphone where configured. Keep x264 as the baseline.
5. Boot the protected recovery entry and verify the same encrypted root unlocks,
   then return to the staged generation. Check Ollama starts on demand and
   releases models after requests.
6. Check system/user failed units and compare the running system to the staged
   receipt. Only after the owner confirms these physical tests, run:

```bash
scripts/nixosctl accept --host thinkpad --physical-checks-passed
```

Acceptance enables persistent subscriber updates at 21:30 Asia/Colombo and
guarded 30-day cleanup. Build success does not establish gameplay, recording,
suspend or recovery success. The owner accepted the migration and 100% scaling
generation on 2026-10-04. Later hardware-tuning changes require the applicable
post-boot checks above; their build does not establish physical success.

## Attended task for the laptop VM session: `system.etc.overlay`

Immutable `/etc` is the last deferred modernisation. It hides the on-disk `/etc`
that holds state, so it must be rehearsed and migrated with someone at the
machine. Do it on the ThinkPad first, then the desktop. Steps:

1. Move the laptop to `boot.initrd.systemd.enable = true` (a prerequisite of the
   overlay; systemd-cryptsetup unlocks the LUKS root). Rehearse in the VM, stage,
   reboot, confirm the passphrase prompt and login.
2. Inventory unmanaged `/etc` state on the real machine as root:
   `find /etc -xtype f ! -lname '/etc/static/*'`, plus `/etc/machine-id`,
   `/etc/ssh/ssh_host_*` (the sops identity), `/etc/NetworkManager/system-connections`
   and `/etc/nixos`. Everything else is regenerated from the store.
3. Rehearse `system.etc.overlay.enable = true` with `mutable = true` in the VM:
   sops must still decrypt, userborn must still create the user, saved
   NetworkManager profiles must persist across a reboot.
4. Before staging on hardware, pre-seed `/.rw-etc/upper/` with the inventoried
   files at their original relative paths, preserving owner and mode (the
   overlay's upper layer becomes the writable `/etc`).
5. Stage, reboot, verify login, Wi-Fi, and that `ssh-keygen -lf
   /etc/ssh/ssh_host_ed25519_key.pub` prints the same fingerprint as before.
   Only then repeat on the desktop, where the host key also decrypts
   `secrets/desktop.yaml`, so step 4 is mandatory there.

## Shared defaults inherited since the desktop modernisation (2026-10-04)

The shared modules now provide: userborn-managed accounts with sops-nix systemd
activation (the login hash is installed before `userborn.service`; staging must
verify decryption with this laptop's own host key), `sudo-rs` for the wheel group,
NetworkManager with systemd-resolved and an nftables firewall with no open ports,
rootless Docker in dhilipsiva's session only (no docker, input or plugdev groups),
Bluetooth with Blueman, fwupd, Nix 2.35 with XDG base directories and
`nix-channel` disabled, tmpfs `/tmp`, the application set in the Home Manager
profile (`home/dhilipsiva/packages.nix`), Zellij through its module with fish and
upstream keybindings, hyprpolkitagent, a Bibata cursor and the dark colour-scheme
preference. The desktop-only parts (systemd initrd, compositor scale 1.5, Terminus
console font, systemd-oomd user slices, no-sleep policy, display rule) live in
`hosts/desktop/`. The ThinkPad's compositor scale is explicitly 1 in
`hosts/thinkpad/graphics.nix`; its console font is not enlarged. Shared Alacritty
and Waybar sizes remain logical sizes. Run `nix fmt`
before publishing: the `formatting` flake check rejects unformatted Nix files,
unused bindings and ruff findings.
