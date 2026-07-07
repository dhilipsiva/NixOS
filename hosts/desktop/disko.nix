# hosts/desktop/disko.nix — declarative partitioning (Phase 5).
#
# +===========================================================================+
# |  DUAL-BOOT WIPE HAZARD — READ BEFORE ANY REAL disko / nixos-anywhere RUN.  |
# |  Windows lives on a SEPARATE physical SSD. This spec declares ONLY the     |
# |  single Linux target disk below. It must NEVER name the Windows disk.      |
# |                                                                            |
# |  On the real machine, identify the LINUX SSD and paste its stable id:      |
# |      ls -l /dev/disk/by-id/ | grep -v -- -part                             |
# |      lsblk -o NAME,SERIAL,MODEL,SIZE          # cross-check it's the Linux |
# |  then run  scripts/preflight-disk-check.sh <the by-id path>  which refuses |
# |  if the device carries a Windows signature. NEVER use /dev/nvme0n1 or      |
# |  /dev/sdX — kernel enumeration order is not stable and could resolve onto  |
# |  the Windows disk (fail-OPEN = catastrophic).                              |
# +===========================================================================+
#
# Layout on the single Linux disk (GPT):
#   1. ESP  — 2 GiB, FAT32, EF00, UNENCRYPTED, mounted /boot (GRUB EFI; sized
#             generously because GRUB keeps kernels+initrds here — see the
#             configurationLimit in default.nix).
#   2. root — remainder, LUKS2 -> ext4, mounted /.
#
# Unlock at real boot = INTERACTIVE passphrase (keyFile stays null; no key on
# disk / in the store / in the initrd). `passwordFile` is FORMAT-TIME ONLY (read
# once by cryptsetup luksFormat during partitioning). See the LUKS note in
# TODO.md / CLEANUP.md for the Phase 6 (--vm-test) and Phase 7 (real) key channel.
{ config, lib, ... }:

let
  # ---- REPLACE on real hardware with the LINUX disk's /dev/disk/by-id path. ----
  # While it still contains "REPLACE-ME": a loud (non-fatal) eval warning fires on
  # every build AND the path resolves to no block device, so a real disko run
  # fails closed. Intentionally NOT a fatal build-time assertion, so GATE-5
  # `nixos-rebuild build` still succeeds while the real device is unknown.
  targetDisk = "/dev/disk/by-id/REPLACE-ME-with-real-linux-nvme-model_serial";
  isPlaceholder = lib.hasInfix "REPLACE-ME" targetDisk;
in
{
  disko.devices.disk.main = {
    type = "disk";
    device = lib.warnIf isPlaceholder
      "hosts/desktop/disko.nix: target disk is still the PLACEHOLDER — set the real /dev/disk/by-id/... path of the LINUX SSD (NOT the Windows disk), and run scripts/preflight-disk-check.sh, before any real disko / nixos-anywhere run"
      targetDisk;
    content = {
      type = "gpt";
      partitions = {
        # Fresh ESP on the LINUX disk (never Windows' ESP). EF00, not EF02 — EF02
        # would make disko set boot.loader.grub.devices=[disk], fighting the
        # host's devices=["nodev"]. Default priority (1000) < the 100% root's
        # (9001), so the ESP is created first.
        ESP = {
          type = "EF00";
          size = "2G";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "fmask=0077" "dmask=0077" ];
          };
        };
        # LUKS2 over the rest of the disk; ext4 root inside it.
        luksroot = {
          size = "100%";
          content = {
            type = "luks";
            name = "cryptroot"; # -> /dev/mapper/cryptroot
            settings.allowDiscards = true; # SSD TRIM through the mapper
            # FORMAT-TIME ONLY (cryptsetup luksFormat). NOT copied to the store,
            # NOT placed in the initrd -> the real system prompts interactively
            # (keyFile stays null). Phase 6 nixos-anywhere --vm-test auto-creates
            # /tmp/secret.key inside the installer so the format is non-interactive;
            # Phase 7 delivers the real passphrase via --disk-encryption-keys.
            passwordFile = "/tmp/secret.key";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
            };
          };
        };
      };
    };
  };

  # Build-hygiene guards (GATE-5-safe; they PASS today). NOTE: these are NOT the
  # wrong-disk boundary — they pass for ANY by-id path, including the Windows
  # disk's. The real wrong-disk protection is the human cross-check +
  # scripts/preflight-disk-check.sh before a real run.
  assertions = [
    {
      assertion = builtins.length (builtins.attrNames config.disko.devices.disk) == 1;
      message = "disko: exactly one disk may be declared (dual-boot safety — Windows is on a SEPARATE disk). Adding a second disk here is almost certainly a mistake.";
    }
    {
      assertion = lib.hasPrefix "/dev/disk/by-id/" targetDisk;
      message = "disko: target disk must be a stable /dev/disk/by-id/... path, never /dev/sdX or /dev/nvme0n1 (kernel enumeration is not stable and could hit the Windows disk).";
    }
  ];
}
