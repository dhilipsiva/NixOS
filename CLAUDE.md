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

The flake (`flake.nix`) tracks `nixos-unstable` (required for RTX 5090 / Ryzen 9000
hardware) and composes `nixosConfigurations.desktop` from **three** module sources:

- `hosts/desktop/default.nix` — machine-specific: GRUB dual-boot, NVIDIA (Blackwell
  beta driver), Wi-Fi 7 firmware, CyberPower UPS. Imports `hardware-configuration.nix`.
- `modules/common.nix` — the shared system config (users, packages, services, networking).
- `home/default.nix` — the home-manager user config (shells, git, Goose→Ollama agent),
  wired in via `home-manager.users.dhilipsiva`.

### Two competing configs — do not confuse them

There are **two** system configs in this repo, and only one is wired into the flake:

- **`modules/common.nix`** is the active system config used by `flake.nix`.
- **`configuration.nix` (repo root)** is the *legacy* monolithic config for the old
  ThinkPad laptop (Intel/NVIDIA PRIME offload, hostname `dhilipsiva-thinkpad`). It is
  **not imported anywhere** — the flake never reads it. Treat it as reference/history
  when editing; changes to it have no effect on `nixos-rebuild --flake`.

When adding system packages/services, edit `modules/common.nix` (or
`hosts/desktop/` for machine-specific bits), **not** the root `configuration.nix`.

### Planned migration (read before large changes)

This repo is mid-migration away from the legacy monolith toward a **modular,
home-manager-first, `.config`-free config on latest-stable NixOS (26.05)**, rehearsed
in a VM from Windows before touching the real desktop. The strategy/trust rationale is
in [PLAN.md](PLAN.md); the ordered, checkbox execution plan is in [TODO.md](TODO.md).
When you change structure, keep this file in sync — after the migration lands, the
"What this repo is" section above (built on the `XDG_CONFIG_HOME` direct-serve model)
will need a full rewrite.

### Known rough edges

`modules/common.nix` and `home/default.nix` were AI-generated; the invalid `[cite: N]`
markers that once blocked evaluation have been stripped, and the home-manager git email
is now `dhilipsiva@pm.me`. Placeholders that will still fail on a real machine:
- `hosts/desktop/default.nix`: the `linux-firmware` override has a dummy
  `sha256-AAAA...` hash (intended "let it fail, copy the real hash" flow), and the
  UPS block references `/etc/nixos/ups-password` which must exist.
- `hosts/desktop/hardware-configuration.nix` is a generic `nixos-generate-config`
  scan (single ext4 root, no LUKS) and does **not** yet reflect the described desktop
  hardware — regenerate it on the actual machine before a real install.

## Layout notes

- `.config/*` — live dotfiles served via `XDG_CONFIG_HOME` (alacritty, fish, helix,
  hypr, sway, waybar, zellij, nvim, atuin, git, cheat). These are **not** managed by
  home-manager; they are consumed directly from this repo on the running system.
- `scripts/show_time_notification.sh` — invoked by a systemd timer defined in the
  system config (quarter-hourly `notify-send`). Timer `ExecStart` paths point at
  `/home/dhilipsiva/.files/scripts/...`, so the repo must be cloned to `~/.files`.
- `clash_royale.sh`, `signature.html`, `tmp.txt` — miscellaneous personal scratch
  files, unrelated to the system build.

## Conventions

- The interactive shell is **fish**; `bash` is configured for scripts. Shell aliases
  `g`=git, `e`=hx, `q`=exit are defined in both the system and home configs — keep
  them in sync if you change one.
- Default editor is Helix (`hx`); `EDITOR`/`VISUAL` are set to `hx`.
- `users.mutableUsers = false` — the user account and password hash are declarative;
  change the password by updating `hashedPassword` and rebuilding, not `passwd`.
