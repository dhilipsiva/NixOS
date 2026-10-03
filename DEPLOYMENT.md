# First desktop deployment

Repository implementation and builds do not change the running system. Staging
is deliberately blocked until real credentials and Secure Boot trust are ready.
Run these steps from `/home/dhilipsiva/projects/dhilipsiva/NixOS` as dhilipsiva.
The packaged helper invokes sudo locally. Never send a password, hash, private key
or Windows recovery key through chat.

Before the first reboot into Windows or firmware, run `sudo bootctl list` and
identify the existing Linux entry to return to. At implementation time the
running/booted installation was generation 2, while the system profile already
pointed to generation 9 from earlier work. A system profile does not establish
the EFI boot default. Keep the working generation 2 entry available throughout
this migration; the helper protects the running system as its recovery baseline.

## 1. Preserve the installed login

```bash
scripts/nixosctl prepare-credentials --host desktop
```

This reads the existing Linux password hash directly into memory, creates or
retains `/etc/ssh/ssh_host_ed25519_key`, creates or retains the separate owner
identity `~/.config/sops/age/keys.txt`, and encrypts the hash plus a fresh local UPS
monitor password. Both identities must decrypt the result before it is written.
Only public recipients and ciphertext change in this checkout. Existing encrypted
files are backed up under `/var/lib/nixos-deployment`. The root recovery public
key is the owner's existing ECDSA public key in `secrets/owner.pub`.

Back up the owner age identity securely off the machine. Keep host private keys
on their own hosts. Do not copy the desktop host identity to the ThinkPad.

## 2. Check Windows and prepare signing

For this desktop, the owner ran a fresh read-only probe directly against the raw
Windows system partition:

```bash
sudo blkid --probe --output export /dev/disk/by-partuuid/fb38feee-5c40-4b28-ae3f-68faac3342e5
```

The result was `TYPE=ntfs`, `USAGE=filesystem`, UUID `263CE1813CE14BFD`. No
BitLocker container was detected; this supports the `unencrypted` assessment for
this partition. This goes beyond a cached `lsblk` label: blkid validates NTFS
metadata on the raw partition and has a separate BitLocker probe. See its
[NTFS](https://github.com/util-linux/util-linux/blob/master/libblkid/src/superblocks/ntfs.c)
and [BitLocker](https://github.com/util-linux/util-linux/blob/master/libblkid/src/superblocks/bitlocker.c)
format checks. This Linux probe does not query Windows policy or verify a backup.

For an encrypted or uncertain result, inspect Device encryption / BitLocker in
Windows (or run `manage-bde -status` in an administrator terminal). If encryption
is enabled, verify that the correct recovery key is accessible from a separate
device or offline copy. Firmware trust changes can trigger Windows recovery.

Use the command matching the status you actually checked:

```bash
scripts/nixosctl prepare-boot --host desktop --windows-status unencrypted
# OR, only after confirming your external recovery-key backup:
scripts/nixosctl prepare-boot --host desktop --windows-status recovery-key-backed-up
```

The helper checks the motherboard, root UUID and Linux ESP UUID. It backs up that
ESP, PK/KEK/db/dbx and an EFI signature inventory; generates local sbctl signing
keys when absent; protects the current system/home closures from GC; and exports
only the public certificate to `/boot/nixos-db.cer`. The signing keys themselves
remain in `/var/lib/sbctl`; they are separate from the ESP backup. It does not enroll keys,
change the boot default, touch the Windows ESP or reboot.

Before firmware enrollment, create an encrypted recovery archive as dhilipsiva:

```bash
nix shell .#nixosConfigurations.desktop.pkgs.age .#nixosConfigurations.desktop.pkgs.gnutar --command bash <<'SH'
set -euo pipefail
umask 077
nixos_backup=$(mktemp "$HOME/nixos-boot-recovery.XXXXXX.tar.age")
trap 'rm -f -- "$nixos_backup"' EXIT
nixos_recipient=$(age-keygen -y "$HOME/.config/sops/age/keys.txt")
sudo -v
sudo tar -C / -cf - var/lib/sbctl var/lib/nixos-deployment |
  age -r "$nixos_recipient" -o "$nixos_backup"
age -d -i "$HOME/.config/sops/age/keys.txt" "$nixos_backup" >/dev/null
trap - EXIT
printf 'Verified encrypted backup: %s\n' "$nixos_backup"
SH
```

This streams the signing keys and deployment backups directly into encryption;
it writes no plaintext archive. It checks decryption with the owner identity
before reporting success. Copy the resulting `.tar.age` file off the machine and
verify the copied file (substitute its actual destination):

```bash
nix shell .#nixosConfigurations.desktop.pkgs.age --command age -d \
  -i ~/.config/sops/age/keys.txt /path/to/copied.tar.age >/dev/null
```

Keep the already backed-up owner age identity available separately; it is needed
to decrypt this archive. Creating the local archive alone is not an off-machine
backup.

Run `sudo bootctl list` and identify `nixos-generation-2.conf`, the currently
working Linux entry, before the manual reboot into firmware.

In MSI Advanced Mode (F7), open **Settings → Security → Secure Boot**. Keep
Secure Boot enabled. Set **Secure Boot Mode → Custom** if needed to expose
**Key Management**. Use **Authorized Signatures (db) → Append Key**, selecting the
public `nixos-db.cer` on the Linux ESP. Preserve the existing PK, KEK, Microsoft/OEM
db and dbx entries. Keep Secure Boot enabled. Do not use Clear Keys, Replace Key,
factory-key replacement, Secure Boot Setup Mode or sbctl enroll-keys. MSI's Custom
mode exposes key management; it does not require deleting the Platform Key.
If firmware does not
provide the append flow, stop and inspect the menu before proceeding. See the
[MSI AM5 BIOS manual](https://download.msi.com/archive/mnu_exe/mb/AMDAM5BIOS.pdf),
pages 21–22. In the firmware file picker the certificate is `/nixos-db.cer`, at
the root of the 1 GiB Linux ESP (UUID `85B9-1188`), not inside a `boot` directory.

Save the append operation, then return to the existing Linux installation using
generation 2. Staging checks that the local db
certificate is actually enrolled and all prior trust entries remain. A Secure
Boot enabled flag alone is not accepted as proof of correct signing.

## 3. Configure publication and publish

The desktop's unattended publisher uses a write-enabled deploy key scoped to
this GitHub repository:

```bash
scripts/nixosctl setup-publisher
```

Add the displayed **public** key under
[repository deploy keys](https://github.com/dhilipsiva/NixOS/settings/keys), with
write access. The private key stays in `~/.ssh/nixos-update`. Verify GitHub's SSH
host fingerprints from its [official documentation](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints)
before adding them to known_hosts. The helper uses strict host checking and does
not trust an unauthenticated ssh-keyscan. SSH settings apply only to this checkout;
the plaintext Git credential helper is disabled. Remove any old stored credential
through your credential manager after moving other repositories to SSH; the helper
does not inspect, print or delete unrelated credentials.

Commit the prepared encrypted files and public recipient rules, then publish:

```bash
git add .sops.yaml secrets/desktop.yaml
git commit -m 'Enroll desktop and owner secret identities'
scripts/nixosctl publish
```

`publish` requires a clean master, checks/builds an isolated snapshot of every
configured host and pushes normally. Rejected/offline pushes cannot become staged
updates. Never force-push to get past this check.

## 4. Stage the exact published revision

```bash
scripts/nixosctl stage --host desktop
```

The helper verifies host identity and mounts, real secret decryption/password
preservation, firmware trust, the published Git revision and all builds. It
backs up the Linux ESP, sets the system profile to the verified store output and
runs that generation's **boot-only** installer (the same activation action as
`nixos-rebuild boot`). It does not live-switch or reboot.

Lanzaboote signs the loader and generation entries. The helper also creates a
self-contained signed UKI for the original recovery generation in
`EFI/nixos-recovery`, outside normal generation pruning. It verifies the signatures
before recording `/var/lib/nixos-deployment/staged.json`. On installer/signature
failure it restores the previous profile and Linux ESP. A power failure during
ESP writes still requires the retained offline recovery media/backups.

Home Manager will back up colliding regular files into unique sibling directories
at first activation. Existing Atuin and Zellij files need these backups; previous
Home Manager/profile store roots remain protected.

Inspect `sudo bootctl list` after staging to confirm the new default and retained
recovery entry. Reboot manually when ready. Keep an installer USB and firmware boot-menu access
available. Windows still boots from its own SSD. No old firmware entry is deleted.

## 5. Physical acceptance and cleanup

Check normal password login and sudo, greetd/Hyprland, NVIDIA rendering and
`nvidia-smi`, networking, audio, the UPS, screen lock/off after five minutes,
Windows read-only file copying, and Secure Boot status/signatures. Exercise Ollama
with a real model; confirm it is absent at boot, loads on request, unloads VRAM
when idle and eventually stops. Check Slack and Teams sign-in, microphone, camera
and portal-based screen sharing interactively. Browser permissions are not granted
automatically. A mock-backend VM test does not prove physical CUDA behavior.

Only after those checks succeed:

```bash
scripts/nixosctl accept --host desktop --physical-checks-passed
scripts/nixosctl cleanup
```

Acceptance requires that the running store generation equals the staged receipt
and that credential and signature checks still pass. Until then the nightly
update, GC and store-optimisation jobs remain gated. The original recovery closure,
signed recovery entry and home-profile roots are retained beyond 30 days.

The BIOS currently exposes only eight cores/eight threads. Inspect CCD/core/SMT
and MSI gaming-mode settings separately after a working baseline; they are not
changed by this deployment.
