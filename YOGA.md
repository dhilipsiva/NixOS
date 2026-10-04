# Yoga Slim 7 installation and acceptance

Repository support is prepared for the Core Ultra 7 258V Yoga. **The laptop is
not connected. Its disks, DMI, panel, firmware trust and peripherals have not
been captured or tested. No Yoga internal disk has been written, no keys
enrolled and no Yoga deployment accepted.** The verified installer USB described
below is ready for a manual boot.

`hosts/yoga/` contains software and policy only. `nixosConfigurations.yoga` and
`lib.hosts.yoga` appear only after both `hosts/yoga/hardware-configuration.nix`
and `hosts/yoga/installation.nix` exist. Never substitute another laptop's
configuration. `tests/yoga-fixture.nix` uses clearly fictitious storage and a VM
credential fixture solely for checks; it is never a deployable flake host.

## Prepared software

- Stable kernel, upstream `xe`, redistributable firmware, Mesa OpenGL/Vulkan
  including 32-bit support, Intel media and compute runtimes. No NVIDIA, PRIME,
  NVENC or Dynamic Boost configuration is imported.
- Hyprland/UWSM and the shared `dhilipsiva` environment with preferred panel
  mode and **automatic scale**, battery status and brightness keys.
- Power Profiles Daemon starts balanced on a new installation. Lid close
  suspends when undocked, displays lock/off after 300 seconds, and hibernation
  is disabled. One zstd zram device uses 25% RAM (about 8 GiB on a 32 GiB Yoga),
  with no disk swap or writeback.
- Native OBS with a writable initial **Yoga** recording profile: H.264 VA-API,
  1080p30, MKV. Select that profile in OBS and set the recordings directory and
  the Intel render device after capture. Configure PipeWire screen/audio sources
  interactively; AV1 recording is a separate test. [Intel's media driver lists
  Lunar Lake support](https://github.com/intel/media-driver).
- User-scoped Sober, with a launcher searchable as **Roblox (Sober)**. There is
  no ThinkPad legacy application migration.
- Intel NPU driver/firmware 1.38.0, its checksum-pinned compiler bundle and
  OpenVINO 2026.4.1's NPU plugin. Level Zero and the media/compute libraries use
  the locked package recipes; they are dependencies, not independently updated
  application channels. The compiler is from the same [stable Intel driver
  release](https://github.com/intel/linux-npu-driver/releases/tag/v1.38.0).
  `npu-smoke` explicitly compiles a tiny in-memory graph for `NPU` with the
  driver compiler, runs inference, checks its output and rejects other execution
  devices. It requires non-root access and downloads no model. The [OpenVINO NPU
  documentation](https://docs.openvino.ai/2026/openvino-workflow/running-inference/inference-devices-and-modes/npu-device.html)
  describes the plugin/driver compiler selection. Runtime compatibility still
  requires inference on the actual Yoga.
- Ollama retains socket activation, five-minute idle stop and model unloading
  after each request. Its pinned package checks for the Vulkan runner and
  excludes CUDA/ROCm payloads. [Ollama documents Vulkan GPU support](https://docs.ollama.com/gpu).
  Arc use must be verified on hardware. Ollama, Roblox and OBS do not acquire NPU
  acceleration merely because the NPU is enabled.

## Repository verification (2026-10-04)

Formatting, workflow/deployment tests, the full flake checks (including the
desktop login VM), and `scripts/nixosctl check --stable` passed from a clean Git
checkout. All 29 tracked software versions matched their official stable
channels. Desktop and ThinkPad system builds passed with their storage,
graphics, scaling and power policies preserved. The Yoga software fixture also
built; the NPU plugin, driver and matching compiler loaded and their compiler
API versions agreed. These checks do not establish physical NPU inference or
any of the hardware acceptance items below.

## 1. Installer and non-destructive capture

The owner's disposable USB was prepared on the ThinkPad on **2026-10-04**:

- Image: official stable [NixOS 26.05.11150.825e2028c29b graphical x86_64 installer](https://releases.nixos.org/nixos/26.05/nixos-26.05.11150.825e2028c29b/nixos-graphical-26.05.11150.825e2028c29b-x86_64-linux.iso), 3,893,821,440 bytes.
- USB: SanDisk Cruzer Blade, 15,597,568,000 bytes, serial `4C531001530918117442`.
- Persistent device: `/dev/disk/by-id/usb-SanDisk_Cruzer_Blade_4C531001530918117442-0:0`.
- SHA-256: `7e759ef8a4e9bbfe9ed302873532c67cf329d670ef550b56f675d17ed8790c64`.

The downloaded ISO matched the official release checksum. The writer rechecked
the USB identity and unmounted state, wrote the image, flushed it, invalidated
the block cache and read the entire image back; its checksum matched as well.
The refreshed partitions expose the NixOS ISO filesystem and FAT `EFIBOOT`
partition, both unmounted. **Physical boot on the Yoga remains pending.** The
ISO and local verification receipt are in `/var/tmp/nixos-installer-20261004/`.

For a later replacement installer:

Download the latest **released stable x86_64 NixOS installer** from the
[official download page](https://nixos.org/download/), and verify its checksum
against the official release checksum. Record the exact URL, release and digest.
Do not use an unstable/nightly image. Inventory USB devices with
`lsblk -d -o NAME,PATH,SIZE,MODEL,SERIAL,TRAN,RM` and `udevadm info`.
Before writing, confirm the USB's by-id path, model, serial and capacity and
obtain the owner's authorization to erase that USB. Never infer a target from
`/dev/sdX` ordering.

Boot the Yoga live without writing its disks. A standard installer may need
attended temporary Secure Boot disablement; record the original setting and
restore it for signed-bootstrap validation. Do not clear PK, KEK, db or dbx.
Capture these read-only facts privately:

```bash
lsblk -o NAME,PATH,SIZE,MODEL,SERIAL,FSTYPE,UUID,PARTUUID,MOUNTPOINTS
ls -l /dev/disk/by-id
cat /sys/class/dmi/id/{sys_vendor,product_name,product_version,board_name}
lspci -nnk
lsusb
cat /sys/class/drm/card*-eDP-*/modes
bootctl status
```

Test Wi-Fi, keyboard/touchpad, sound, microphone, camera and panel brightness.
Record the actual panel mode/physical size; automatic scaling is intentional.
In Lenovo firmware, confirm there is an **append certificate to db** operation
that preserves every existing trust entry. Save the original PK/KEK/db/dbx
signature lists privately before enrollment. Stop if the firmware only offers
reset/replace trust; this plan does not authorize clearing keys.

## 2. Confirm the disk before replacing Windows

The owner must explicitly confirm the **Yoga disk's by-id path, model, serial,
capacity, and that its Windows/data contents may be erased**. USB confirmation
does not authorize erasing the internal SSD. Back up required data and any
Windows recovery key before that confirmation. Disconnect unrelated storage
where practical. Desktop and ThinkPad disks are outside this installation.

Only after that confirmation, use the installer tools interactively to create
GPT with a 2 GiB FAT32 ESP and the remaining space as LUKS2, opened as `root`,
containing ext4. Set the LUKS boot passphrase interactively. Mount ext4 at `/mnt`
and the ESP at `/mnt/boot`. Do not create swap, enroll TPM automatic unlock or
enable discard/writeback. This repository intentionally supplies no disk-wipe
script. Run `nixos-generate-config --root /mnt` **on the Yoga** and retain the
generated hardware file. Normalize the LUKS mapping name to `root` if needed;
verify every filesystem UUID against `lsblk` and `cryptsetup status root`.

## 3. Minimal signed bootstrap

Use `hosts/yoga/bootstrap.nix` with the generated hardware file in a separate
temporary flake on the Yoga. Pin this repository to a checked commit (which pins
NixOS and Lanzaboote through its lock), rather than following a moving branch:

```nix
{
  inputs.repo.url = "github:dhilipsiva/NixOS/<checked-commit>";
  outputs = { repo, ... }: {
    nixosConfigurations.yoga-bootstrap = repo.inputs.nixpkgs.lib.nixosSystem {
      specialArgs.inputs = repo.inputs;
      modules = [
        repo.nixosModules.yoga-bootstrap
        ./hardware-configuration.nix
        { system.stateVersion = "26.05"; } # use the stable release installed today
      ];
    };
  };
}
```

Create independent signing keys locally in the live Yoga environment with
`sbctl create-keys`, then securely copy its newly created `/var/lib/sbctl` bundle
to `/mnt/var/lib/sbctl` with root-only private-key permissions. Never take these
keys from the ThinkPad/desktop, put them into a flake directory, or use automatic
enrollment. Copy only the public db certificate to the ESP for firmware import.
Use the confirmed firmware append operation, retaining the saved trust entries.

Install the minimal signed configuration using `nixos-install --no-root-passwd
--flake <bootstrap-directory>#yoga-bootstrap`. Set the login password using
`nixos-enter --root /mnt -c 'passwd dhilipsiva'`, interactively, before reboot.
Do not put a hash or passphrase in Nix, shell history, command arguments or logs.
Restore Secure Boot and manually boot the installed bootstrap. Require successful
LUKS unlock, user login, network access, Secure Boot enabled in user mode,
signed loader/UKIs and retention of the original trust entries. Keep the USB.

## 4. Capture the real host and enroll credentials

From the working bootstrap, run `nixos-generate-config --show-hardware-config`
and save the output as `hosts/yoga/hardware-configuration.nix`. Retain the actual
root/ESP/LUKS UUIDs and module list; remove no storage safeguards. Add
`hosts/yoga/installation.nix` with the **captured** DMI board name and the two
compatibility anchors (record the actual NixOS/Home Manager installation release):

```nix
{
  repo.maintenance.boardName = "<actual /sys/class/dmi/id/board_name>";
  system.stateVersion = "26.05";
  home-manager.users.dhilipsiva.home.stateVersion = "26.05";
}
```

The checkout must be owned by `dhilipsiva` at
`/home/dhilipsiva/projects/dhilipsiva/NixOS`, with the normal origin/master remote.
Confirm `nix eval --json path:$PWD#lib.hosts.yoga` reports only Yoga identifiers.
Then use the local helper (it reads the installed login hash in memory):

```bash
scripts/nixosctl prepare-credentials --host yoga
scripts/nixosctl prepare-boot --host yoga --windows-status absent
```

`absent` is an owner attestation after inspecting all installed disks; do not use
it for a retained Windows installation. It does not relax Secure Boot checks.
The first command creates Yoga's own host/owner encryption recipients and
`secrets/yoga.yaml`; only public recipients and ciphertext are committed.
The second preserves the working signed bootstrap and ESP and records the
certificate/trust baseline. Compare that baseline to the pre-enrollment backup
as well. The bootstrap must already boot with Secure Boot enabled.

Back up the LUKS header using `cryptsetup luksHeaderBackup` on the confirmed LUKS
partition, the boot passphrase/recovery material, owner age identity, SSH host
identity and signing bundle to private encrypted **off-device** storage. Test
that the owner age identity can decrypt the ciphertext. A header backup does not
contain the passphrase, and losing both the passphrase and usable recovery
material can make the disk unrecoverable. None of these private artifacts belong
in Git or the Nix store.

## 5. Publish, stage and accept

In the Yoga bootstrap, install Sober as the normal user (if Flatpak is not yet
installed, run these through a shell using Flatpak from the pinned Nixpkgs):

```bash
flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install --user flathub org.vinegarhq.Sober
flatpak info --user org.vinegarhq.Sober
```

Let Flatpak install its Mesa/runtime dependencies. Yoga never requires an NVIDIA
extension. Run `nix fmt`, `nix flake check .`,
`scripts/nixosctl check --stable` and explicit builds for desktop, ThinkPad and
the now captured Yoga. Before hardware capture, `yoga-software` is a fixture
build, not that third physical host. Track all required source files and repeat
verification from a clean checkout. Publish only the checked revision using
`scripts/nixosctl publish`.

On the Yoga alone:

```bash
scripts/nixosctl stage --host yoga
```

This checks the published revision, real filesystems, LUKS mapping, credentials,
firmware trust and user Flatpak app before installing signed boot entries.
It protects the working bootstrap with a GC root and separate signed recovery
UKI. Reboot **manually** when ready; never use `switch` for this rollout.

## Physical acceptance checklist (all pending)

- Passphrase unlock, signed boot, ordinary login and sudo; failed units absent.
- Wi-Fi and reconnection after reboot; audio output, microphone, camera,
  touchpad, brightness keys, battery reporting and automatic display scale.
- Undocked lid-close suspend/resume on AC and battery; docked lid stays awake;
  lock/display off after five minutes; no hibernation or disk swap.
- `lspci -nnk` reports `xe`; `vulkaninfo --summary` reports Intel Arc, not
  llvmpipe/lavapipe. Inspect `vainfo` for H.264 encode; test AV1 separately.
- Launch **Roblox (Sober)** from Fuzzel, log in and play an actual game.
- Select the **Yoga** OBS profile and Intel VA-API render device. Make and play
  back a recording with visible PipeWire screen capture and working audio;
  confirm the OBS log reports H.264 VA-API hardware encoding.
- Run `npu-smoke` as `dhilipsiva`. It must complete numeric inference explicitly
  on NPU; `/dev/accel` detection alone is insufficient. After exit, inspect the
  `intel_vpu` PCI device's `power/runtime_status` and idle power draw.
- Explicitly download a chosen small Ollama model, run inference, inspect
  `ollama ps` and service logs for Vulkan/Arc offload, then check unloading and
  that `ollama.service` stops after the idle proxy timeout. Never count CPU
  inference as Arc validation.
- Confirm the protected recovery boot entry and off-device backups are usable.

Only after all checks pass, on the Yoga, run
`scripts/nixosctl accept --host yoga --physical-checks-passed`. That explicit
acceptance permits the subscriber and GC timers. Record failures/pending checks
here; a build or runtime-library load is not physical acceptance.

## Recovery

Select **NixOS (protected pre-migration recovery)** for the signed bootstrap, or
the preceding signed generation. Keep Secure Boot and existing trust intact.
If needed, boot the verified USB using the attended firmware procedure, unlock
the confirmed Yoga LUKS device with its passphrase, and mount the installed root
and ESP. Restore signing/credential files only from the Yoga's private backup.
Review a LUKS-header restoration against the exact disk and backup identity with
the owner before writing it. Never format as a recovery step or copy another
host's UUIDs/keys. Do not enable unattended updates until physical acceptance.
