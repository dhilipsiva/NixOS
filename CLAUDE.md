# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Personal NixOS system configuration + dotfiles ("`.files`"). On the target NixOS
machine it is cloned to `~/.files`, and `XDG_CONFIG_HOME` is set to
`/home/dhilipsiva/.files/.config` (see `configuration.nix` / `common.nix`), so the
files under `.config/` are the *live, in-use* application configs — editing them
in this repo edits the running system's config directly (no copy/symlink step).

Note: this checkout is edited on **Windows**, but the flake targets
`x86_64-linux` NixOS. `nixos-rebuild`/`nix` commands below run on the **NixOS host**,
not on the Windows dev machine. `PLAN.md` documents an (aspirational) workflow for
testing this config from Windows via WSL2 + VMware VMs — it is planning notes, not
an active part of the build.

## Build / apply commands

Run on the NixOS host, from the repo root (`~/.files`):

```bash
sudo nixos-rebuild switch --flake .#desktop   # build + activate + set as boot default
sudo nixos-rebuild test   --flake .#desktop   # activate without adding a boot entry (safer trial)
nixos-rebuild build       --flake .#desktop   # build only, no activation (no sudo needed)
nix flake check                               # evaluate/validate the flake
nix flake update                              # bump flake inputs (nixpkgs, home-manager)
```

`#desktop` is the only defined `nixosConfigurations` attribute. Garbage collection
is automatic (daily, `--delete-older-than 7d`); run `nix-collect-garbage -d` to force it.

## Architecture

The flake (`flake.nix`) tracks **latest-stable `nixos-26.05`** (the earlier
"unstable is mandatory for RTX 5090 / Ryzen 9000" premise is obsolete — stable
supports both via `hardware.nvidia.open = true` + `nvidiaPackages.production`).
**No unstable input exists**; if the VM later proves a specific hardware package is
missing on stable, add a *narrowly-scoped* `nixpkgs-unstable` overlay for just that
package (kernel/mesa/nvidia as a coherent set) — never repoint the whole system.
It composes `nixosConfigurations.desktop` from a **modular** `hosts / modules / home`
split (plus `nixos-hardware` profiles imported by the host):

- `hosts/desktop/default.nix` — machine-specific: GRUB dual-boot, NVIDIA (Blackwell,
  **open module + production driver**), CyberPower UPS, `system.stateVersion` (per-host
  anchor), and a VM-only `virtualisation.vmVariant` block. Imports `hardware-configuration.nix`
  and the `nixos-hardware` `common-cpu-amd` / `common-gpu-nvidia-nonprime` / `common-pc-ssd`
  profiles.
- `modules/nixos/` — the shared system config, **split by concern**, with a
  `default.nix` aggregator that imports them all: `nix.nix`, `locale.nix`, `users.nix`,
  `audio.nix`, `desktop.nix`, `networking.nix`, `virtualisation.nix`, `hardware.nix`,
  `packages.nix`, `environment.nix`. The flake includes the whole set via `./modules/nixos`.
- `home/dhilipsiva/` — the home-manager user config: `default.nix` (shells, git,
  Goose→Ollama agent) + `services.nix` (the quarter-hourly time-notification **user**
  timer). Wired via `home-manager.users.dhilipsiva`. (Per-tool dotfile files land in Phase 3.)

When adding system config, edit the relevant `modules/nixos/*.nix` (or `hosts/desktop/`
for machine-specific bits). The legacy root `configuration.nix` has been **deleted**
(it was ThinkPad-era, never imported; recoverable from git history if ever needed).

### Planned migration (read before large changes)

This repo is mid-migration away from the legacy monolith toward a **modular,
home-manager-first, `.config`-free config on latest-stable NixOS (26.05)**, rehearsed
in a VM from Windows before touching the real desktop. The strategy/trust rationale is
in [PLAN.md](PLAN.md); the ordered, checkbox execution plan is in [TODO.md](TODO.md).
When you change structure, keep this file in sync — after the migration lands, the
"What this repo is" section above (built on the `XDG_CONFIG_HOME` direct-serve model)
will need a full rewrite.

**Phase 0 is complete (GATE 0 passed 2026-07-07).** The VM test loop is stood up and the
safety substrate is live:
- **VM driver: QEMU + KVM inside WSL2; host = NixOS-WSL** (VMware/`vmrun` rejected — not
  installed, and this drops all interop/`wslpath` fragility). Real KVM (`/dev/kvm` present),
  not TCG.
- The build→boot loop is validated with a **throwaway `~/nixos-vmtest` flake** (pinned
  `nixos-26.05`), **not** `.#desktop` (blocked by the `sha256-AAAA…` firmware hash). The
  loop is `nixos-rebuild build-vm --flake .#vmtest` → headless serial boot → login prompt →
  SSH via hostfwd `:2222`. **Do not gate on `nix flake check`** for a bare VM config — it
  fails the `fileSystems` assertion by design.
- **The guardrail is active and applies to you:** `.claude/settings.json` + the
  `.claude/hooks/guard.sh` PreToolUse hook hard-block `rm -r`, `nixos-rebuild
  switch/boot/test`, `disko`, raw block-device writes (`dd`/`mkfs`/… to `/dev/*`),
  `git push --force`/`reset --hard`, and any `nixos-anywhere` that is not `--vm-test` or
  localhost-targeted. Phase 0–6 only ever `build`/`build-image`/`build-vm`/`--vm-test`.
- *Nix gotcha:* qemu-vm options (`virtualisation.graphics`, etc.) exist only inside the
  build-vm variant — set them under `virtualisation.vmVariant.*`, never top-level
  `virtualisation.*`, or evaluation fails.

**Phases 1–2 complete (GATES 1 & 2 passed 2026-07-07).** Phase 1 flipped the config to
stable `nixos-26.05` (NVIDIA open+production, dropped `linuxPackages_latest`, removed the
firmware override, `stateVersion → 26.05`, misc stable-package fixes). Phase 2 restructured
the monolith into the `hosts / modules/nixos / home/dhilipsiva` split described above,
deleted the legacy root `configuration.nix` + `tmp.txt`, and ported the two systemd units
(backup dropped; notification → home-manager user timer). Both gates verified with
`nix flake check` + `nixos-rebuild build .#desktop` + a headless VM boot; Phase 2 parity
was confirmed by `nix store diff-closures` (only the two intended service changes differ).
**Next: Phase 3** (migrate `.config/` dotfiles into home-manager Nix; then delete
`.config/` + the `XDG_CONFIG_HOME` override).

### Known rough edges

`modules/common.nix` and `home/default.nix` were AI-generated; the invalid `[cite: N]`
markers that once blocked evaluation have been stripped. Placeholders that will still
fail on a real machine:
- `hosts/desktop/default.nix`: the UPS block references `/etc/nixos/ups-password`
  which must exist (moves to sops in Phase 4). *(The dummy `sha256-AAAA…` firmware
  override was removed in Phase 1.)*
- `hosts/desktop/hardware-configuration.nix` is a generic `nixos-generate-config`
  scan (single ext4 root, no LUKS) and does **not** yet reflect the described desktop
  hardware — regenerate it on the actual machine before a real install.

## Layout notes

- `.config/*` — live dotfiles served via `XDG_CONFIG_HOME` (alacritty, fish, helix,
  hypr, sway, waybar, zellij, nvim, atuin, git, cheat). These are **not** managed by
  home-manager; they are consumed directly from this repo on the running system.
- `scripts/show_time_notification.sh` — the original quarter-hourly `notify-send`
  script. **No longer referenced** by the system config: Phase 2 reimplemented it as a
  home-manager **user** service+timer (`home/dhilipsiva/services.nix`) that builds the
  script into the Nix store (no hardcoded `~/.files` path). The loose `scripts/` copy
  can be removed once you're happy with the home-manager version.
- `misc/clash_royale.sh` — a personal Android autoplay script (moved out of the repo
  root in Phase 2); `signature.html` — an email signature. Neither is part of the build.

## Conventions

- The interactive shell is **fish**; `bash` is also configured. Shell aliases
  `g`=git, `e`=hx, `q`=exit (and `gdev`) are defined in home-manager
  (`home/dhilipsiva/default.nix`) for **both** bash and fish — keep the two in sync.
- Default editor is Helix (`hx`); `EDITOR`/`VISUAL` are set to `hx`.
- `users.mutableUsers = false` — the user account and password hash are declarative;
  change the password by updating `hashedPassword` and rebuilding, not `passwd`.
