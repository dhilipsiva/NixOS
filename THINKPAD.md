# ThinkPad session handoff

Owner instruction, 2026-10-04: the ThinkPad **already runs NixOS**. Use this
repository to migrate that existing installation, following the same checked,
published, next-reboot workflow used on the desktop. This is not a fresh install.

The repository belongs at the same path on both machines:
`/home/dhilipsiva/projects/dhilipsiva/NixOS`. Read [AGENTS.md](AGENTS.md),
[CLAUDE.md](CLAUDE.md) and [README.md](README.md) first. [SESSION.md](SESSION.md)
records the desktop work; [DEPLOYMENT.md](DEPLOYMENT.md) is desktop-specific.

## Start the laptop session here

Tell the agent: **Read THINKPAD.md and adapt this repository to this ThinkPad's
existing NixOS installation. Preserve its disks and recovery path.**

If the checkout already exists, inspect local changes before syncing:

```bash
cd /home/dhilipsiva/projects/dhilipsiva/NixOS
git status --short --branch
scripts/nixosctl sync
```

If it is absent, clone `https://github.com/dhilipsiva/NixOS.git` into that exact
path as dhilipsiva. Never overwrite a different existing checkout. Sync is
fast-forward-only; preserve local work and resolve divergence deliberately.

## Required laptop work

1. Inventory the actual machine and its existing configuration before editing:
   model/board, CPU, RAM, GPU, Wi-Fi, storage UUIDs, mounted root/ESP, encryption,
   swap/resume, bootloader, Secure Boot, battery and current login environment.
   Read the current `/etc/nixos` configuration and record the installation's
   existing NixOS/Home Manager `stateVersion` values. Use read-only commands such
   as `nixos-generate-config --show-hardware-config`, `lsblk -f`, `findmnt`,
   `lspci -nnk`, `readlink -f /run/current-system`, and `bootctl status` where
   applicable. Do not run a partitioner or an installation command.
2. Add `hosts/thinkpad/` with that machine's observed hardware, filesystems,
   boot/encryption policy, power settings and compatibility anchors. Expose it
   as `nixosConfigurations.thinkpad` through the existing `mkHost` function.
   Share the software and Home Manager modules. Choose laptop graphics and
   Ollama acceleration from its actual GPU; never import `hosts/desktop/`.
3. Preserve latest stable NixOS and application releases, Hyprland/Wayland,
   Alacritty/fish/Atuin/zoxide/ripgrep, the existing development tools and
   on-demand Ollama. Set battery, lid and suspend behavior for a laptop. The
   desktop's no-sleep policy, NVIDIA HDMI workaround and CPU performance policy
   must not be inherited as laptop hardware settings.
4. Enroll laptop-specific encrypted credentials using its own host identity and
   an owner identity available locally. Preserve its working login credential.
   Never copy the desktop's SSH host keys, firmware signing private keys, secret
   ciphertext or disk UUIDs. Keep all plaintext secrets outside Git and the
   Nix store. Configure local Wi-Fi password persistence; the shared desktop
   module supplies the NetworkManager applet, not a shared Wi-Fi password.
5. Configure maintenance as a **subscriber**, with `host = "thinkpad"`, the same
   repository path and the actual board name. The desktop publishes checked
   updates around 21:00 Asia/Colombo; the laptop pulls/stages around 21:30 with
   persistent timers. Work authored on either machine must be checked and
   published normally, with suitable per-machine Git credentials. Never copy
   the desktop's private deploy key merely to reuse it on the laptop.
6. Preserve a usable recovery generation and adapt boot preparation to the
   laptop's real bootloader, encryption and firmware. The existing Secure Boot
   helper and hardware guards must be reviewed for that layout. Do not blindly
   repeat the MSI certificate procedure or claim this machine is supported by
   an unchanged helper. Preserve firmware trust and any existing Windows setup.
7. Check/build **both configured hosts**, verify from a clean checkout and
   publish. Only then stage `--host thinkpad` through `nixosctl`. Never stage
   `--host desktop` on the laptop, live-switch or reboot automatically. After a
   manual reboot, verify login, display, network autoconnect, sound, battery,
   lid/suspend/resume and the laptop's recovery/boot behavior before acceptance
   and cleanup. A successful build is not a successful laptop deployment.

No ThinkPad hardware configuration exists yet. `stage --host thinkpad` correctly
rejects the request until that work is complete. Keep the desktop independently
deployable throughout the laptop migration.

Desktop reference state: generation 12 works with all 16 CPU cores / 32 threads,
the recovered Qualcomm Wi-Fi adapter and the 4K60 NVIDIA HDMI workaround. Initial
acceptance/cleanup completed, freeing 36.4 GiB. Wi-Fi password persistence and the
new applet rollout are tracked in DEPLOYMENT.md; do not assume those pending
physical checks passed merely because this handoff exists.
