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
  settings, profiles/scenes and `/home/dhilipsiva/recordings`. Its existing logs
  report NVENC unavailable; hardware encoding is not assumed to work.
- On the first new boot, Home Manager runs `scripts/migrate-home.py` before
  linking managed files. It privately backs up `~/.files/.config`, imports
  unmanaged settings into `~/.config` and retains existing destination files on
  collisions. Active legacy OBS settings take precedence, with any previous
  destination saved separately. A completion marker prevents repeated imports.
- Backups and collision reports are under
  `~/.local/state/nixosctl/home-migration/`. Private application data never enters
  Git or the Nix store. The original configuration tree remains available for
  generation 291. No global `XDG_CONFIG_HOME` override is retained.

## Preparation and verification

Work at `/home/dhilipsiva/projects/dhilipsiva/NixOS` as dhilipsiva. The owner
completed these commands on 2026-10-04:

```bash
scripts/nixosctl prepare-credentials --host thinkpad
scripts/nixosctl prepare-boot --host thinkpad
```

Enrollment generated independent laptop/owner identities and verified the
encrypted password against the installed account. No laptop UPS secret is needed.
Back up `~/.config/sops/age/keys.txt` securely outside the laptop; that external
backup has not been confirmed. Never copy desktop private keys onto this host.

Boot preparation protected generation 291 and the existing home/profile roots,
backed up the ESP and recorded the firmware trust and encrypted layout. It did
not stage a generation. Staging installs a protected recovery boot entry outside
normal rotation, retaining the original kernel, initrd and encrypted-root command
line. The desktop continues to require its signed recovery UKI.

The existing Wi-Fi profile reports autoconnect enabled, unrestricted users and
password flags `0`. Its password stays in the local NetworkManager store. A real
reboot is still required to verify unattended connection.

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
suspend or recovery success. These physical checks remain pending until reboot.

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
