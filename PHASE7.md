# PHASE 7 — real-hardware install runbook (dual-boot, separate SSDs)

> **Resume anchor.** Phases 0–6 are done and committed; GATE 6 (VM install rehearsal +
> human Hyprland sign-off) is green. This file is the durable handoff — agent memory does
> NOT cross from NixOS-WSL to a Windows Claude Code session, but this repo does. Design was
> research + adversarially verified (workflow wf_73fb207c-af6). Read alongside
> [CLEANUP.md](CLEANUP.md) (§ Phase 4/5/6 owner items) and [TODO.md](TODO.md) Phase 7.

## Can NixOS be installed from Windows / WSL2? — NO.

You must **boot a real NixOS installer USB on the desktop** and install there. Not from
Windows, not from WSL2. The *separate physical disks* make the wipe **safe** (the Windows
SSD is never named), but they don't make a Windows-driven install *possible*. Verified
blockers for a WSL2-driven install of THIS config:

1. **No UEFI runtime in WSL2** — `/sys/firmware/efi` is absent (checked live on this box),
   so `efibootmgr` / `boot.loader.efi.canTouchEfiVariables = true` **cannot register the
   NixOS NVRAM boot entry**. A WSL install would drop GRUB files on the ESP with no firmware
   entry ⇒ unbootable NixOS.
2. **`wsl --mount --bare` can't yield a bootable UEFI install** — MS docs call it
   "fundamentally different from installing Linux to bare metal on UEFI". It also hands WSL a
   *writable whole-disk* handle (one wrong `PHYSICALDRIVE` number = catastrophe) for zero
   payoff — **do not use it.**
3. **Single box** — booting the installer powers Windows/WSL OFF, so WSL can never drive the
   install over the LAN either.

*(Note: `dm_crypt` **is** available in NixOS-WSL, so LUKS could form there — but blockers 1
and 3 still make a WSL install impossible/unbootable.)*

**Division of labor:** Windows Claude Code session = **PREPARE + DRAFT + BUILD USB**; a human
at the booted installer = **EXECUTE**.

---

## Part A — Windows session PREP (before touching hardware)

Do these from the Windows Claude Code session. **Route every Linux command explicitly through
`wsl.exe -d NixOS -- …`** and confirm with `uname -a` first — Claude Code on Windows can
silently run its Bash tool via Git Bash/PowerShell, which has no `nix`/`disko`/`sops`.

1. **Rotate the placeholder secrets/keys** (all in CLEANUP.md § Phase 4):
   - `ssh-to-age < ~/.ssh/id_ed25519.pub` → set as `&operator` in `.sops.yaml`.
   - `sops secrets/secrets.yaml` → set the real login `$6$` hash (`mkpasswd -m sha-512`) + real UPS password.
   - `sops updatekeys secrets/secrets.yaml`; keep `bash scripts/check-sops-recipients.sh` green.
   - Replace the root break-glass `authorizedKeys` placeholder in `hosts/desktop/default.nix` with your real ed25519 pubkey.
2. **Remove Phase-6 test scaffolding** — **✅ DONE 2026-07-07** (the `disko.tests` block,
   `modules/nixos/vmtest-install.nix`, and `keys/vmtest_host_ed25519_key` are removed;
   `nix flake check` + `nixos-rebuild build .#desktop` verified green without them).
3. **Set the target disk** — you can *pre-stage* a candidate from PowerShell
   `Get-PhysicalDisk | Get-Disk` (model+serial → `nvme-<model>_<serial>`) as a **cross-check only**;
   the real binding happens at the installer (Part B). Paste it into `targetDisk` in `hosts/desktop/disko.nix`.
4. **Validate**: `wsl.exe -d NixOS -- nix flake check` and `nixos-rebuild build --flake .#desktop`
   (build-only — proves the closure builds before the box goes offline).
5. **Make the USB**: download the NixOS **26.05 minimal x86_64** ISO from nixos.org, verify sha256,
   and write it with **balenaEtcher (DD mode)** or **Rufus ("DD Image")**. **Do NOT `dd` from WSL2**
   (usbipd can't reliably expose the stick — microsoft/WSL#7770). Confirm the writer target is the
   removable USB by size+model; unplug other external disks.
6. **COMMIT + PUSH** the repo to a git remote reachable from the installer (or copy it to an
   **exFAT** data USB). **This is the only channel that survives the reboot** — neither the WSL
   working tree nor agent memory exists in the booted installer. Committed `secrets/*.yaml` are
   age-encrypted and safe to carry.
7. In Windows: **disable Fast Startup** (Power Options → uncheck "Turn on fast startup") and
   `powercfg /h off`, so Windows always does a clean shutdown (prevents os-prober skipping a
   "dirty" NTFS and dropping the dual-boot entry).

## Part B — Human install (at the desktop, booted from the USB)

**STEP 0 — MANDATORY wrong-disk safety: physically unplug (or BIOS-disable) the Windows SSD for
the entire install.** This makes a wrong-disk wipe *physically impossible* — the Nix assertions in
`disko.nix` are fail-OPEN (they pass for any by-id, including Windows'), and there is no guard hook
at the physical console. Re-attach only in STEP 11.

1. **BIOS**: disable **Secure Boot** (this is plain unsigned GRUB, no lanzaboote). If the RTX 5090
   console is black under the installer's nouveau, connect the monitor to the **motherboard/iGPU**
   output, or append `nomodeset` at the ISO GRUB menu, or go headless (`passwd`, `systemctl start sshd`, SSH in).
2. Boot the USB via the one-time firmware boot menu **in UEFI mode** (not legacy/CSM).
3. **Confirm UEFI**: `ls /sys/firmware/efi/efivars` must be **non-empty** (proves efibootmgr can write the NixOS entry).
4. **Get the repo**: `git clone <remote> /root/nixos` (or copy from the exFAT USB).
5. **Identify + verify the Linux SSD** (the real wrong-disk boundary):
   `ls -l /dev/disk/by-id/ | grep -v -- -part` and `lsblk -o NAME,SERIAL,MODEL,SIZE`, then
   `sudo /root/nixos/scripts/preflight-disk-check.sh /dev/disk/by-id/<linux-ssd>` (fails closed if
   not root; refuses NTFS/BitLocker/ReFS/exFAT/`EFI/Microsoft`; requires the FULL serial). Ensure
   `targetDisk` in `disko.nix` matches.
6. **Regenerate hardware config on the real box** (the committed scan is generic and may miss real
   nvme/storage modules → unbootable initrd): `sudo nixos-generate-config --no-filesystems --show-hardware-config`
   and merge the CPU/kernel-module/nvme bits into `hosts/desktop/hardware-configuration.nix`.
   **Keep disko's ownership of `fileSystems`/`swap`** (do NOT re-add them).
7. **LUKS format key** — no trailing newline (a stray `\n` makes every interactive unlock fail):
   `echo -n 'YOUR-PASSPHRASE' > /tmp/secret.key`. This is what you'll type at every boot.
8. **Install**: `sudo disko --mode destroy,format,mount --flake /root/nixos#desktop`
   then `sudo nixos-install --flake /root/nixos#desktop --no-root-passwd`
   (`--no-root-passwd` is required — accounts are declarative sops + `mutableUsers = false`;
   the default root prompt would hang). *(Equivalent: `nixos-anywhere --flake .#desktop
   --target-host localhost --disk-encryption-keys /tmp/secret.key /run/luks.key` from the installer.)*
9. **PRE-REBOOT boot gate** (do NOT skip): `sudo efibootmgr -v` must show a **NixOS/GRUB entry**
   present and first in `BootOrder`. If absent (buggy/full firmware NVRAM), re-run the bootloader
   install or add `boot.loader.grub.efiInstallAsRemovable = true` + `canTouchEfiVariables = false`
   (a second rebuild — the two flags are mutually exclusive) to drop `\EFI\BOOT\BOOTX64.EFI`.
   **Keep the USB plugged until NixOS has booted once.**
10. **Reboot.** GRUB prompts for the LUKS passphrase from STEP 7. **dhilipsiva will be LOCKED on
    first boot** — the freshly generated host key isn't a sops recipient yet. Recover via **GRUB
    `init=/bin/sh`**: `mount -o remount,rw /`, set a temporary root password in `/etc/shadow`
    (it survives to a normal boot since no activation runs), reboot, log in at the console.
11. **Enroll the real host key (Phase 7 sops)** — from the console (or, easier, do the re-encryption
    back in WSL/Windows using the pubkey read off the box, so the box only pulls+rebuilds):
    `ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub` → add that recipient under the `secrets.yaml`
    rule in `.sops.yaml` → `sops updatekeys secrets/secrets.yaml` → commit/push →
    `sudo nixos-rebuild switch --flake .#desktop`. This unlocks the declarative password; remove the
    temporary root password.
12. **Re-attach the Windows SSD**, ensure Fast Startup is off, then `sudo nixos-rebuild switch --flake .#desktop`
    so os-prober (read-only grub-mount) adds the Windows dual-boot entry. Verify BOTH OSes boot,
    `efibootmgr -v` still lists **Windows Boot Manager**, and `upsc cyberpower@localhost` sees the UPS.

## Windows-disk safety invariants (never violate)

- The Windows SSD is **never** named in `disko.devices` (exactly one by-id disk; assertion-enforced).
- NixOS gets its **own** fresh ESP on the Linux SSD; **Windows' ESP is never mounted or written**.
- `grub.devices = ["nodev"]` → GRUB writes **no** MBR/boot code to any raw disk, only EFI files to the NixOS ESP.
- `efibootmgr` writes firmware NVRAM only — **additive** NixOS entry, never deletes Windows Boot Manager.
- **Never** add the Windows NTFS to `fileSystems`/fstab; if ever mounted for data, only **read-only** after a
  full Windows shutdown. os-prober's read-only grub-mount is the ONLY permitted touch of the Windows disk.
- Physical unplug during install (STEP 0) is the absolute guarantee.
