# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Personal NixOS system configuration + dotfiles ("`.files`"), cloned to `~/.files` on
the target machine. It's a **flake**: a modular, **home-manager-first** config on
latest-stable `nixos-26.05`, built from `hosts/desktop/` + `modules/nixos/*` +
`home/dhilipsiva/*` (see Architecture below).

**Dotfiles are managed by home-manager as Nix** — the tools' configs live in
`home/dhilipsiva/*.nix` (native `programs.*` where possible; `xdg.configFile.*.source`
bridges for a few), and home-manager writes them to the standard `~/.config`. The raw
`.config/` tree in the repo is **legacy**: after Phase 3 it is no longer served via
`XDG_CONFIG_HOME` (that override is gone). Most of it is now inert and pending deletion
(see [CLEANUP.md](CLEANUP.md)); only `.config/{waybar,hypr,zellij}` are still referenced
— as `xdg.configFile.source` bridges — until they're natively translated. **Do not edit
`.config/*` expecting it to affect the running system** (except those three bridged
files); edit the home-manager Nix modules instead.

Note: this checkout is edited on **Windows**, but the flake targets `x86_64-linux`
NixOS. `nixos-rebuild`/`nix` commands below run on the **NixOS host** (in practice
NixOS-WSL — see the Phase 0 note), not on the Windows dev machine.

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
**Phase 3 complete (GATE 3 passed 2026-07-07).** All `.config/` dotfiles are migrated
into home-manager and the `XDG_CONFIG_HOME` override is removed. Tier 1 (git, atuin,
alacritty, helix, fish) ported to native `programs.*`; Tier 2 (waybar, hyprland, zellij)
kept as `xdg.configFile.source` **bridges** (glyph/keybind fragility — native translation
deferred); nvim and cheat **dropped** (tools weren't installed). Verified live in a VM:
`~/.config` is home-manager-managed, `XDG_CONFIG_HOME` unset, git/helix/alacritty/etc.
read their migrated configs. **Invariants (keep true):**
- **Do NOT reintroduce a raw `.config/` served via `XDG_CONFIG_HOME`.** Configure tools
  through home-manager Nix (`programs.*` / `wayland.windowManager.*`).
- **`xdg.configFile.*.source` is a bridge, not the default** — only where no clean native
  option exists (currently waybar/hypr/zellij). Prefer native translation.

**Phase 4 complete (GATE 4 passed 2026-07-07).** The user login password and the UPS
password are now sops-nix secrets — no plaintext hash or `/etc/nixos/ups-password` in any
`.nix`. `users.nix` uses `hashedPasswordFile` (sops `neededForUsers = true`, decrypted to
`/run/secrets-for-users` before user creation, mandatory under `mutableUsers = false`); the
UPS password comes from `sops.secrets."ups/monitorPassword"`. Verified in the VM (positive:
sops self-decrypts via the host key, dhilipsiva logs in; negative: on decrypt failure
dhilipsiva locks but the root break-glass still gets a shell — the box is not bricked).
**Secrets invariants (keep true):**
- **Never commit plaintext secrets.** Passwords/keys go through sops; only PUBLIC age
  recipients (`.sops.yaml`) and ENCRYPTED files (`secrets/*.yaml`) are committed. `.gitignore`
  blocks private-key patterns; `scripts/check-sops-recipients.sh` is the guardrail.
- **`secrets/secrets.yaml` = real (owner-managed); `secrets/vm-test.yaml` = fake (VM only).**
  The disposable `vmtest` key must NEVER be a recipient of `secrets.yaml`.
- The current `&operator` key + root's `authorizedKeys` are **PLACEHOLDERS** (agent-generated,
  private halves at `/home/nixos/phase4-keys/`, never committed) — **rotate to your own key**
  and set a real rotated password (the old hash is already burned in git history). See CLEANUP.md.

**Phase 5 complete (GATE 5 passed 2026-07-07).** Declarative partitioning via disko
(`hosts/desktop/disko.nix`): a SINGLE-disk GPT layout — 2 GiB FAT32 ESP at `/boot` +
LUKS2 → ext4 root (`/dev/mapper/cryptroot`, interactive passphrase at boot). `disko`
owns `fileSystems`, so `hardware-configuration.nix` was trimmed (its `fileSystems`/`swap`
removed). **Dual-boot safety (Windows on a SEPARATE SSD):** the spec targets ONE disk via
a guarded `/dev/disk/by-id/…` PLACEHOLDER that fails closed; assertions enforce one-disk +
by-id; the real wrong-disk check is `scripts/preflight-disk-check.sh` (human-run, refuses
Windows-signature disks). Verified: flake check green, `build .#desktop` builds, and the
VM still boots on its own disk (disko/LUKS overridden by qemu-vm). GRUB `configurationLimit
= 10` bounds generations on the ESP.

**Human-in-the-loop hardware items** (the VM uses the disko-generated layout / injected keys
instead, so none block VM testing) — all tracked in [CLEANUP.md](CLEANUP.md):
- `hosts/desktop/disko.nix`: set the real Linux SSD `/dev/disk/by-id/…` (run the preflight script first).
- `hosts/desktop/hardware-configuration.nix`: regenerate on the real machine (`nixos-generate-config`), keeping the fileSystems/swap removal.
- LUKS passphrase, sops key rotation, UPS password — owner-provided (Phases 5–7).

**Phase 6 complete (GATE 6 automated half passed 2026-07-07).** The full install
rehearsal (`nixos-anywhere --flake .#desktop --vm-test`, i.e. `nix build
.#…config.system.build.installTest`) ran green in a sandboxed KVM VM — **no real
hardware touched**. It proved end-to-end: disko partitions a virtual disk (GPT: vfat
ESP + LUKS2), LUKS2 unlocks at stage-1 boot, the full desktop closure installs, GRUB-EFI
installs, the system reboots into itself, and **sops decrypts** (root ext4 on
`/dev/mapper/cryptroot`, `cryptsetup status cryptroot` active, `/boot/EFI` + `grub.cfg`,
`/run/secrets-for-users/dhilipsiva/hashedPassword` present, dhilipsiva shadow is a `$6$`
hash — all asserted by `disko.tests.extraChecks`).
- **Test scaffolding** (remove before real Phase 7 — see CLEANUP.md): `hosts/desktop/disko.nix`'s
  `disko.tests` block, `modules/nixos/vmtest-install.nix` (a TEST-ONLY overlay via
  `disko.tests.extraConfig`, never in `system.build.toplevel`), and `keys/vmtest_host_ed25519_key`
  (a committed THROWAWAY host key that only decrypts the fake `secrets/vm-test.yaml`). Verified
  the real toplevel is unweakened (keyFile=null, canTouchEfiVariables=true, real secrets.yaml).
- **CAVEAT — GATE 6 sops-green proves the MECHANISM only** (fake file + throwaway key), NOT that
  the real host key can decrypt the operator-only `secrets.yaml`. Real login on first real boot
  requires Phase 7: enroll the real host key (`ssh-to-age` → `.sops.yaml` → `sops updatekeys`)
  and set the real password; until then rely on the root break-glass.
- **HUMAN SIGN-OFF DONE (2026-07-07):** the owner ran a graphics-enabled VM (temporary
  greetd-autologin overlay, since reverted; software GL via llvmpipe) and confirmed Hyprland
  renders — waybar with Font Awesome glyphs + the desktop came up with the home-manager dotfiles.
  (True RTX 5090 behaviour is still a Phase 7 real-hardware check.) The visual check also caught
  a **pre-existing dotfile bug**: `.config/hypr/hyprland.conf` bound the dwindle-only dispatchers
  `togglesplit`/`pseudo` while `layout = master` — those two binds are now commented out.

**GATE 6 fully passed** (automated rehearsal + human visual). **Next: Phase 7** — real-hardware
cutover (HUMAN-driven; the agent prepares/drafts, a human runs).

**Deferred cleanup:** superseded/legacy files are **not** deleted mid-migration — they're
tracked in [CLEANUP.md](CLEANUP.md) and removed (plus the README/docs rewrite) in one final
pass after all phases are green. Update `CLEANUP.md` at the end of each phase.

### Known rough edges

`modules/common.nix` and `home/default.nix` were AI-generated; the invalid `[cite: N]`
markers that once blocked evaluation have been stripped. Placeholders that will still
fail on a real machine:
- `hosts/desktop/hardware-configuration.nix` is a generic `nixos-generate-config`
  scan trimmed of `fileSystems`/`swap` (disko owns them now) — regenerate the
  hardware bits on the actual machine before a real install (keep the trim).
- `hosts/desktop/disko.nix` `targetDisk` is a `/dev/disk/by-id/REPLACE-ME…` PLACEHOLDER
  — set the real Linux SSD id and run `scripts/preflight-disk-check.sh` first. **Never run
  `disko`/`nixos-anywhere` against a real disk from here** (the guard hook blocks it; the
  VM install rehearsal is Phase 6's `--vm-test`).
- Secrets placeholders: `&operator` in `.sops.yaml` and root's break-glass
  `authorizedKeys` are throwaway agent-generated keys, and `secrets/secrets.yaml` holds a
  random unknown password + `changeme-rotate` UPS value — **rotate all of these to your own
  key + real password before real-hardware use** (Phase 7; tracked in CLEANUP.md).
  *(The UPS `/etc/nixos/ups-password` path and the dummy `sha256-AAAA…` firmware override
  are both gone — sops in Phase 4, firmware removal in Phase 1.)*

## Layout notes

- `.config/*` — **legacy** raw dotfiles, no longer served via `XDG_CONFIG_HOME`. The live
  configs are the home-manager modules in `home/dhilipsiva/*.nix` (written to `~/.config`).
  Most `.config/*` subtrees are now **inert** and pending deletion (git/helix/alacritty/
  atuin/fish, plus dropped nvim/cheat); only `.config/{waybar,hypr,zellij}` are still read,
  as `xdg.configFile.source` bridges. See [CLEANUP.md](CLEANUP.md).
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
