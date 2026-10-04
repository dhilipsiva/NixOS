# Session handoff

Repository: `/home/dhilipsiva/projects/dhilipsiva/NixOS` on every machine, owned
by dhilipsiva, tracking `origin/master`. Start any session by comparing the
running system with the published build before trusting state notes:

```bash
cd /home/dhilipsiva/projects/dhilipsiva/NixOS
git status --short --branch
readlink -f /run/current-system
nix build --no-link --print-out-paths .#nixosConfigurations.desktop.config.system.build.toplevel
```

The detailed migration record (firmware enrollment, dbx restoration, HDMI
failure analysis, CPU and Wi-Fi recovery, generation-by-generation evidence) is
in Git history up to commit `2652a41`; this file keeps only the facts a new
session needs.

## Desktop facts

- Hardware: MSI MAG X870E TOMAHAWK WIFI (MS-7E59), Ryzen 9 9950X3D (16 cores /
  32 threads online since the owner disabled X3D Gaming Mode), RTX 5090 on the
  NVIDIA open module, Samsung Odyssey G81SF 4K over HDMI-A-1, Qualcomm WCN7850
  Wi-Fi (`wlp8s0`, recovered after a motherboard power drain), CyberPower UPS.
- Display: DisplayPort (DP-1) since 2026-10-04 at 3840x2160@240, 10-bit, VRR
  in fullscreen, compositor scale 1.5, NVIDIA-only DRM device through the
  colon-free udev alias `/dev/dri/desktop-nvidia`. The HDMI FRL
  workaround is gone; HDR is an untested future change.
- Boot: Lanzaboote-signed UKIs with the owner's local certificate appended to
  the firmware db; all factory PK/KEK/db/dbx entries are preserved and the
  staging helper verifies that before every deployment. Recovery entry
  **NixOS (protected pre-migration recovery)** boots the original generation 2
  (Plasma/nouveau) from `/EFI/nixos-recovery/pre-migration.efi`. Legacy
  generation 1/2 loader entries are unusable. The encrypted recovery archive is
  `~/nixos-boot-recovery.*.tar.age`; the owner age identity lives in
  `~/.config/sops/age/keys.txt` and is backed up off-machine.
- Secrets: `secrets/desktop.yaml` is encrypted to the owner identity and the
  desktop's SSH host identity; staging verifies decryption and that the
  preserved login hash matches `/etc/shadow`. The VM fixture
  `secrets/vm-test.yaml` is encrypted to a throwaway identity that is no longer
  available locally; regenerate it (see DEPLOYMENT.md) before using the VM
  rehearsal's positive sops path.
- Publication: the desktop pushes with the repository-scoped deploy key in
  `~/.ssh/nixos-update` through `core.sshCommand`; the nightly timer runs at
  21:00 Asia/Colombo and stages verified updates for the next manual reboot.
  Acceptance and the first cleanup (36.4 GiB freed) are complete.
- Wi-Fi: password agent-owned in the keyring by the owner's choice; it connects
  automatically after login, not before. Memory runs its EXPO profile
  (2 x 48 GiB DDR5-6000) and fwupd shows no pending firmware.

## Current state (2026-10-04)

The owner reports the ThinkPad boots and works on its staged configuration and
accepted it; `system.etc.overlay` is an attended task for the laptop's VM session
(THINKPAD.md).

Generation 15 (published `44d446b`, the modernisation) is running and the owner
confirmed the 1.5 scale. The checkout adds the DisplayPort display policy
described in DEPLOYMENT.md; the previous modernisation built as
`/nix/store/vwbdamgnanaghnwwafwg27mbd8p9q6ng-nixos-system-dhilipsiva-desktop-26.05.20261002.774debe`,
passes every flake check, the `nixosctl check --stable` gate (both hosts build)
and a headless VM rehearsal of the boot path. It was rebased onto the laptop
session's ThinkPad host commit `0a3b61b`, whose checks and host policies it keeps. Staging and the reboot follow the normal `nixosctl`
workflow; nothing switches live.

## Yoga state (2026-10-04)

The owner installed NixOS 26.05 on the Yoga Slim 7 15ILL9 with the official
graphical installer (GNOME, generation 1, unencrypted ext4, unsigned
systemd-boot, Secure Boot off). The Yoga session captured that installation
into `hosts/yoga/hardware-configuration.nix` and `installation.nix`, made
`nixosConfigurations.yoga` a real host with the ThinkPad's unsigned boot policy,
kept zram as the only swap (`systemd.swap=0` leaves the installer's swap
partition unused) and installed the user Flatpak Sober 1.8.0. Pending on the
Yoga: `prepare-credentials`, one commit with the ciphertext, a push credential,
`publish`, `prepare-boot`, `stage`, a manual reboot and the physical checks in
YOGA.md. Nothing was staged or switched.
