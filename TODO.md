# TODO — Migration to a Modern, Modular, home-manager-first, STABLE NixOS Config

> This is the **execution checklist**. It says *what to do, in order*.
> For the *why* — the capability/trust rationale, guardrails, failure modes, and the
> go/no-go gates for advancing between phases and touching real hardware — read
> [`PLAN.md`](./PLAN.md). This file intentionally does **not** repeat that reasoning.
>
> **Two numbering schemes:** the *Phases 0–7* below are **work order**. PLAN.md's
> *Capability Layers L0–L4* are a different (trust/autonomy) axis; the mapping between
> them lives in [`PLAN.md` § Relationship to TODO.md](./PLAN.md#relationship-to-todomd).

## Goal

Take this repo from its current state (a flake pinned to `nixos-unstable`, an
AI-generated `modules/common.nix` + `home/default.nix`, live dotfiles served raw out
of `.config/` via `XDG_CONFIG_HOME`, a dead legacy `configuration.nix`, and a desktop
host that has never been installed) to the target:

**A modular, declarative, home-manager-first NixOS config on the latest *stable*
channel (`nixos-26.05` "Yarara"), with `.config/` dotfiles expressed as Nix, fully
rehearsed in a VM from Windows (WSL2 + QEMU) before anything touches the real
RTX 5090 desktop.**

## Guiding principles

- **Modular** — split by concern (`hosts/<host>/`, `modules/nixos/*`, `home/<user>/*`); no monolith.
- **Declarative / home-manager-first** — express config as Nix options; `xdg.configFile.*.source` is a *bridge*, not the default.
- **No `.config/`** — delete the raw dotfile tree and the `XDG_CONFIG_HOME` override once each tool is ported.
- **Latest STABLE, and stay there** — track `nixos-26.05`. Do **not** add an unstable input up front (the decision is: avoid breakage). Stable already supports the RTX 5090 + Ryzen 9000; only if the VM later proves a *specific* package is missing do you add a narrowly-scoped `nixpkgs-unstable` overlay for just that package.
- **Windows-testable, VM-first** — nothing runs on real hardware until it is green in a QEMU VM driven from WSL2. Real-hardware bring-up stays a **human** step.
- **Keep `CLAUDE.md` in sync** — update it every time the structure changes so the agent's always-on invariants stay true.

---

## Phase 0 — Stand up the Windows → WSL2 → VM test loop (nothing touches real hardware)

Get to the point where you can *build and boot this flake in a throwaway VM* from the
Windows box, before changing any config. This is the safety substrate for every later phase.

- [x] Confirm WSL2 is installed with a systemd-enabled distro (or install NixOS-WSL); verify `nix --version` and that flakes work: `nix flake --help`. **(Done — host is NixOS-WSL, `nix` on PATH, flakes on.)**
- [x] Enable flakes in WSL2 nix (`experimental-features = nix-command flakes` in `~/.config/nix/nix.conf`) so `nix flake check` runs there. **(Done — declaratively via the NixOS-WSL host config; flake commands work.)**
- [x] Verify KVM is available inside WSL2 (`ls -l /dev/kvm`); if absent, QEMU still works via TCG (slower) — note which you have. **(Done — `/dev/kvm` present `root:kvm 0660`, user in `kvm` group; real KVM, not TCG.)**
- [x] Clone/checkout this repo *inside* the WSL2 filesystem (not `/mnt/c`, to avoid the 9p perf/permission tax) OR confirm `wslpath -w`/`wslpath -u` round-trips the Windows checkout path cleanly. **(Done — repo consumed at `/mnt/c/.../NixOS` over 9p; the throwaway smoke-test flake lives on native ext4 at `~/nixos-vmtest`.)**
- [x] Pick the VM driver and record it in `PLAN.md`/`CLAUDE.md`: **QEMU-in-WSL2** (preferred, KVM) or **VMware Workstation via `vmrun.exe`** through interop. If VMware, confirm `vmrun.exe` is reachable from WSL2 (`vmrun.exe list`) and that VMX paths are passed as Windows paths via `wslpath -w`. **(Done — chose QEMU+KVM in WSL2 (host = NixOS-WSL); VMware not used. Recorded in `PLAN.md`/`CLAUDE.md`.)**
- [x] Smoke-test the loop so a red result later means "my change broke it," not "the loop was never working". **NOTE: run against a *throwaway* `~/nixos-vmtest` flake (nixos-26.05), NOT `.#desktop` — `.#desktop` can't build in Phase 0 (placeholder `sha256-AAAA…` firmware hash). Used `build-vm` (supplies its own disk), not `build-image`, per the corrected GATE-0 path in PLAN.md.**
  - [x] ~~`nix flake check`~~ — **skipped by design:** a bare config has no root filesystem, so `nix flake check` fails the `fileSystems` assertion. Do NOT gate on it (see PLAN.md). The `[cite: N]` markers are already stripped from the repo `.nix` files.
  - [x] Build a VM: `nixos-rebuild build-vm --flake .#vmtest` (build-image + OVMF is the Phase-6 alternative). **(Done — built cleanly; kernel 6.18.37 on NixOS 26.05.)** *Gotcha recorded:* qemu-vm options like `virtualisation.graphics` only exist inside the build-vm variant — set them under `virtualisation.vmVariant.*`, not top-level `virtualisation.*`, or eval fails.
  - [x] Boot the VM in QEMU from WSL2 and confirm it reaches a login prompt. **(Done — headless serial reached `vmtest login:` in ~6 s; SSH via hostfwd `:2222` worked, `systemctl is-system-running` = `running`.)**
- [x] Add an `.claude/settings.json` deny-list + `PreToolUse` hook per `PLAN.md`'s guardrail architecture so `disko`/`nixos-anywhere`/`rm -rf` can only ever target the VM, never a real disk. **This is a precondition for every later phase.** **(Done — `.claude/settings.json` + `.claude/hooks/guard.sh` present and firing; GATE-0 probes below all pass.)**

**GATE 0 (PASSED 2026-07-07):** From NixOS-WSL, the build→boot loop is green — `nixos-rebuild build-vm --flake .#vmtest` builds and the VM boots to a login prompt in QEMU (SSH-reachable). The destructive-command guardrail is active and demonstrably blocks real-disk targets: all 5 BLOCK probes (`rm -rf /home`, `nixos-rebuild switch --flake .#desktop`, `nixos-anywhere … --target-host root@192.168.1.50`, `disko … /dev/nvme0n1`, `dd … of=/dev/sda`) → exit 2; both ALLOW probes (`nixos-anywhere … --vm-test`, `nixos-rebuild build-image … .#vmtest`) → exit 0. **→ clears Phase 1.**

---

## Phase 1 — Flip to latest STABLE; fix stateVersion; resolve Blackwell/Ryzen driver tension

Change the *foundation* (channel + drivers) with the config still monolithic, so each
following phase builds on a stable base. Small, verifiable diffs.

- [x] In `flake.nix`, retarget the primary input to `nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";` and delete the "Unstable is mandatory" comment. **(Applied — declared only; the VM build still has to confirm it evaluates on stable.)**
- [x] Pin home-manager to the matching release: `home-manager.url = "github:nix-community/home-manager/release-26.05";` (keeps `inputs.nixpkgs.follows = "nixpkgs"`). **(Applied.)**
- [x] Add `nixos-hardware` as an input; import `common-cpu-amd`, `common-gpu-nvidia`, and `common-pc-ssd` profiles into `hosts/desktop/default.nix` to offload microcode/firmware/GPU quirks. **(Done — with `inputs.nixpkgs.follows`. Used `common-gpu-nvidia-nonprime` instead of plain `common-gpu-nvidia`: the plain profile assumes PRIME/hybrid and asserts on missing GPU bus IDs; the desktop has a single discrete RTX 5090 with the monitor wired directly to it.)**
- [x] **Stay pure-stable — no unstable input now.** *Only if* a later VM rehearsal proves stable genuinely lacks a hardware package do you add a scoped `nixpkgs-unstable` overlay for that one package (kernel/mesa/nvidia as a coherent set). Deferred, not part of the initial flake. **(Honored — no unstable input added.)**
- [x] Fix the NVIDIA block in `hosts/desktop/default.nix` for Blackwell on 26.05:
  - [x] `hardware.nvidia.open = true;` (the **open** kernel module is *required* for 50-series Blackwell; proprietary is unsupported). **(Done.)**
  - [x] `hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.production;` — the current **production** branch on 26.05. `.beta` removed; `.legacy_580` not used. **(Done.)**
- [x] Reconsider `boot.kernelPackages = pkgs.linuxPackages_latest;` — dropped the `_latest` override; 26.05's default kernel covers Ryzen 9000 X3D and keeps NVIDIA binary-cache coverage. **(Done — removed.)**
- [x] Bump `system.stateVersion` and `home.stateVersion` from `"24.11"` to **`"26.05"`** (first-install anchor for the never-installed desktop). **(Done — both files.)**
- [x] Update `CLAUDE.md`: state the flake tracks latest STABLE (not unstable), and that unstable exists only as a reserved scoped overlay. **(Done — Architecture section rewritten.)**

**Extra stable-reconciliation fixes surfaced by `nix flake check` on 26.05 (not in the original Phase 1 list, but required to green the build):**
- [x] Removed the broken `linux-firmware` `fetchgit` override with the placeholder `sha256-AAAA…` hash (it could never build) — now just `hardware.enableRedistributableFirmware` + nixos-hardware. **This resolves the Phase 5 / cross-cutting firmware blocker early** (the preferred resolution was "delete the override" anyway).
- [x] `programs.adb.enable` was removed on 26.05 (systemd 258 auto-handles uaccess) — replaced with `android-tools` in the package list; dropped the now-orphaned `adbusers` group from the user's `extraGroups`.
- [x] `copilot-cli` removed upstream (EOL) — dropped from the package list (note left to re-add a replacement).
- [x] `power.ups` moved to a structured schema — the old inline `users.upsmon.upsmonConf` MONITOR string no longer counts toward MINSUPPLIES; reworked to `power.ups.users.upsmon` + `power.ups.upsmon.monitor.cyberpower` + `settings.SHUTDOWNCMD`, and `master`→`primary` (NUT rename). `passwordFile` still plaintext `/etc/nixos/ups-password` (→ sops in Phase 4).
- [x] `wineWowPackages` → `wineWow64Packages` (deprecation) and home-manager `programs.git.userName/userEmail` → `settings.user.name/email` (rename) — cleared to keep eval warning-free (git is fully restructured in Phase 3).

**GATE 1 (2026-07-07 — 3/4 met, commit pending):** `nix flake check` is green against `nixos-26.05` in WSL2. `nixos-rebuild --flake .#desktop build` completes. A VM built from this base still boots. `flake.lock` is committed pinning all inputs.
<!-- STATUS:
  [x] `nix flake check` GREEN against nixos-26.05, zero warnings.
  [x] `nixos-rebuild build --flake .#desktop` completed (exit 0) — full toplevel, kernel 6.18.37.
  [x] VM boots: `nixos-rebuild build-vm --flake .#desktop` (headless via the vmVariant serial block)
      reached `dhilipsiva-desktop login:` + Multi-User + Graphical targets; home-manager applied.
      (UPS units FAIL in the VM — no physical CyberPower UPS / no password file; expected, not a regression.)
  [ ] flake.lock commit — LEFT TO THE USER (on default branch `master`; many unrelated pre-existing
      changes are unstaged). Phase 1 files to stage: flake.nix, flake.lock, hosts/desktop/default.nix,
      modules/common.nix, home/default.nix, CLAUDE.md, TODO.md, PLAN.md.
-->


---

## Phase 2 — Restructure into the modular layout; retire the dead legacy config

Move from monolith to `hosts / modules / home` split. Pure refactor — behavior should
be unchanged; only file organization moves.

- [ ] Create `modules/nixos/` split **by concern**, migrating the contents of `modules/common.nix`:
  - [ ] `nix.nix` (flakes, `gc`, `allowUnfree`, `android_sdk.accept_license`)
  - [ ] `locale.nix` (`time.timeZone = "Asia/Kolkata"`, `i18n.defaultLocale = "en_IN"`, `console.keyMap`)
  - [ ] `users.nix` (`dhilipsiva`, groups, `shell = pkgs.fish`, `mutableUsers = false`) — **do not** carry the plaintext `hashedPassword` forward; it moves to sops in Phase 4.
  - [ ] `audio.nix` (pipewire, `pulseaudio.enable = false`)
  - [ ] `desktop.nix` (`programs.hyprland`, `dconf`, polkit, gnome-keyring)
  - [ ] `networking.nix` (NetworkManager, firewall port 8080, the `reddit.com` hosts blocklist)
  - [ ] `virtualisation.nix` (docker, adb, `nix-ld`, the plugdev udev rule)
  - [ ] `packages.nix` (the system package list) and `hardware.nix` (opentabletdriver)
  - [ ] Port/rethink the two `systemd` timer/service units:
    - [ ] `backup-nix-config` copies `/etc/nixos/configuration.nix` → `/home/dhilipsiva/dotfiles/…`. This is **obsolete in the flake model** (source of truth is the `~/.files` repo, and the root `configuration.nix` is deleted below) — **drop this service** (or repoint it at the repo). Note: deleting `configuration.nix` without removing this unit leaves it copying a non-existent file.
    - [ ] `show-time-notification` runs `scripts/show_time_notification.sh` (the file **does** exist in the repo). To match the declarative goal, ship it as a home-manager `home.file`/packaged script and reference the store path, instead of the hardcoded `/home/dhilipsiva/.files/scripts/…` path.
- [ ] Add `modules/nixos/default.nix` aggregator that imports all of `modules/nixos/*` for one-line host inclusion.
- [ ] Move home-manager out of a single file: create `home/dhilipsiva/default.nix` (sets `home.stateVersion`, imports per-tool files) — the per-tool files themselves are filled in Phase 3.
- [ ] Update `flake.nix`: compose `desktop` from `hosts/desktop/default.nix` + `modules/nixos` (or its `default.nix`) + the HM nixos module pointing at `home/dhilipsiva`. Pass `inputs` via `specialArgs`.
- [ ] (Optional, proves the design) Scaffold `hosts/thinkpad/default.nix` from the legacy config to validate "multiple hosts sharing modules" — it keeps its **original** stateVersion.
- [ ] **Retire the legacy monolith:** delete the root `configuration.nix`. It is ThinkPad-era (Intel + NVIDIA PRIME offload, `dhilipsiva-thinkpad`), never imported by the flake, and superseded. Salvage anything still wanted (e.g. into `hosts/thinkpad/`) *before* deleting.
- [ ] **Delete `tmp.txt`** (a ~9.7 KB scratch file at repo root — not referenced by anything).
- [ ] Decide keep/delete for the other loose root files: `clash_royale.sh` (an Android `input tap` autoplay script — unrelated to the system config; drop or move to a `misc/` dir) and `signature.html` (an email signature — keep only if you still use it; not part of the NixOS build).
- [ ] Update `CLAUDE.md` to describe the new `hosts/modules/home` layout and record that root `configuration.nix` is gone (no longer "reference-only" — removed).

**GATE 2:** `nix flake check` green and `nixos-rebuild --flake .#desktop build` succeeds against the **new modular layout**. VM boot behavior matches Phase 1 (no regression from the reorg). Root `configuration.nix` and `tmp.txt` are gone; `git status` shows the moves.

---

## Phase 3 — Migrate `.config/` dotfiles into home-manager Nix

Port each tool per the mapping below, in the recommended order (easy full-native wins
first, then structured, then decide the hard/low-value ones). After each tool is ported
**and verified in the VM**, delete its `.config/<tool>/` subtree. When the tree is empty,
delete the `XDG_CONFIG_HOME` override.

### Per-tool migration table

| Tool | Source file(s) | home-manager module | Native support | Approach |
|---|---|---|---|---|
| **git** | `.config/git/config`, `.config/git/excludesfile` | `programs.git` | full | 1:1. Port aliases → `programs.git.aliases`; `[core]/[color]/[merge]/[push]/[rebase]/[apply]/[branch]/[init]/[credential]/[http]` → `programs.git.extraConfig`; excludesfile → `programs.git.ignores`; `diff.external = "difft"` (install `difftastic`). **Identity (already fixed in `home/default.nix`):** port `userName = "dhilipsiva"`, `userEmail = "dhilipsiva@pm.me"` into `programs.git`. Preserve the smart-quotes in the `it` alias and shell-fn aliases (`!f(){...};f`) verbatim. |
| **atuin** | `.config/atuin/config.toml` | `programs.atuin` | full | File is 99% commented defaults. Only `programs.atuin.settings = { enter_accept = true; sync.records = true; }`. Enable `enableFishIntegration`/`enableBashIntegration` — this **replaces** the manual `atuin init` lines (and fixes the wrong `eval $(atuin init fish)` syntax currently in `home/default.nix`). |
| **alacritty** | `.config/alacritty/alacritty.toml` | `programs.alacritty` | full | Tiny → `programs.alacritty.settings` (Fira Code family at all weights, size 16, the Shift+Return→`\r` binding kept as a literal string). Install the Fira Code / Nerd Font package or the family silently falls back. |
| **helix** | `.config/helix/config.toml`, `.config/helix/languages.toml` | `programs.helix` | full | `config.toml` → `programs.helix.settings` (theme `onedark`, cursor-shape, file-picker.hidden, whitespace/indent-guides/soft-wrap). `languages.toml` → **two** keys: `programs.helix.languages.language` (the `[[language]]` array: rust, js, ts, tsx, jsx, json with biome + ts-language-server `except-features=["format"]`) and `.language-server` (the biome table). Drop the commented python/ruff/clippy blocks. Ensure `biome`, `typescript-language-server`, `vscode-json-language-server` are installed. |
| **fish** | `.config/fish/config.fish`, `.config/fish/fish_variables` | `programs.fish` | full | `config.fish` is 3 real lines: `atuin init` becomes redundant (atuin integration handles it); cargo bin PATH → `home.sessionPath = [ "$HOME/.cargo/bin" ]`; drop the commented fnm line. Keep existing aliases (`g/e/q/gdev`) + starship. **Do NOT port `fish_variables`** — machine-generated universal-variable state (default theme); it regenerates and pinning it fights fish. *Note:* `.config/fish/config.fish` already uses the **correct** `atuin init fish \| source`; the **broken** `eval $(atuin init fish)` lives in `home/default.nix` — neither raw init line survives once `programs.atuin.enableFishIntegration` owns it. |
| **waybar** | `.config/waybar/config`, `.config/waybar/style.css` | `programs.waybar` | partial | JSON `config` → `programs.waybar.settings.mainBar` (native attrset avoids the jsonc `//` comments); `style.css` → `programs.waybar.style` as a verbatim `''…''` string. **Prune the laptop-era modules** (`battery#bat2`, `backlight`) — meaningless on the desktop. clock TZ is hardcoded `Asia/Kolkata`. Ensure Font Awesome 6 / Roboto / Fira Code fonts present. |
| **hyprland** | `.config/hypr/hyprland.conf` | `wayland.windowManager.hyprland` | partial | **De-risk first:** `wayland.windowManager.hyprland.extraConfig = builtins.readFile ./dotfiles/hypr/hyprland.conf`, verify boot in VM, *then* translate to `.settings` (mind: `$variable` defs, `bind=` as a **list**, `env=` as a list). Referenced bins: alacritty, dolphin, rofi, firefox — ensure installed. Desktop-appropriate (no laptop bits). |
| **zellij** | `.config/zellij/config.kdl`, `themes/.gitkeep` | `programs.zellij` | partial | Keep the ~294-line hand-tuned keybind block as a **sourced file** initially: `xdg.configFile."zellij/config.kdl".source = ./dotfiles/zellij/config.kdl`. The attrset→KDL translation of ordered action sequences (`bind "n" { NewPane; SwitchToMode "normal"; }`) is fragile — translate later, optionally, once verified. Empty `themes/` dir → nothing to port. `default_shell` is bash. |
| **sway** | ~~`.config/sway/config`~~ | — (dropped) | n/a | **DROPPED — hyprland only.** `.config/sway/config` has been deleted; do not port it. (sway was never enabled in the system config anyway.) |
| **nvim** | `.config/nvim/init.vim` | `programs.neovim` | none | Worst-fit file: vim-plug + ~55 plugins + stale tooling (deoplete/racer/syntastic). **Do NOT rewrite in Nix.** Since helix is primary (`e = hx`), prefer **drop**; if kept, source it: `programs.neovim.extraConfig = builtins.readFile ./dotfiles/nvim/init.vim` (or `xdg.configFile."nvim/init.vim".source`) so vim-plug keeps managing plugins imperatively. |
| **cheat** | `.config/cheat/conf.yml` | none (`xdg.configFile`) | none | No HM module. `xdg.configFile."cheat/conf.yml".source = ./dotfiles/cheat/conf.yml`. Lowest priority — safe to defer or drop. Note its `cheatpaths` reference `~/.files/cheat/{community,work,personal}` dirs **not present** in `.config/` — verify they exist on the host or the paths dangle. Editor is nvim (couples to the nvim decision). |

### Execution order and cleanup

- [ ] **Tier 1 (full-native, do first):** git → atuin → alacritty → helix → fish. Put these in `home/dhilipsiva/{git.nix,shells.nix,helix.nix,terminal.nix}`.
- [ ] Ensure the referenced **packages/fonts** are installed or ported configs silently no-op: Fira Code / Nerd Font, Font Awesome, Roboto, `difftastic`, `biome`, `typescript-language-server`, `vscode-langservers-extracted`, `rofi`, `dolphin`, `firefox`.
- [ ] **Tier 2 (structured, verify in VM):** waybar → hyprland → zellij, into `home/dhilipsiva/{wayland.nix,terminal.nix}`. Use `extraConfig`/`source` bridges where noted, translate to native `.settings` only after a green VM boot.
- [ ] **Tier 3 (decide):** **sway is dropped — hyprland only** (`.config/sway/` already deleted). Still decide **nvim** (drop vs source) and **cheat** (source vs drop).
- [ ] Remove the now-redundant `programs.bash.initExtra`/`programs.fish.interactiveShellInit` `atuin init`/`starship init` eval lines superseded by the `programs.*` integrations.
- [ ] After each tool is verified in the VM, `git rm -r .config/<tool>/`.
- [ ] Once `.config/` is empty: delete it, and **remove `environment.variables.XDG_CONFIG_HOME = "/home/dhilipsiva/.files/.config";`** from the system config.
- [ ] Update `CLAUDE.md`: add the invariants "do not reintroduce raw `.config/` served via `XDG_CONFIG_HOME` — prefer home-manager Nix" and "`xdg.configFile.*.source` is a bridge, not the default."

**GATE 3:** `.config/` and the `XDG_CONFIG_HOME` override are gone. The VM boots into a working session; **parity check** each ported tool against its old behavior (git aliases/identity `git config -l`, atuin/starship in shell, helix theme+LSPs, alacritty font, waybar renders without the pruned laptop modules, hyprland binds work via `hyprctl`, zellij starts). `nix flake check` green.

---

## Phase 4 — Declarative secrets (sops-nix) for password + UPS

Get the two committed/plaintext secrets out of the repo before any real install.
**sops-nix** (not agenix) is required here because `users.mutableUsers = false` needs
`neededForUsers = true` for a declarative `hashedPasswordFile`.

- [ ] Add `sops-nix` as a flake input and import its nixos module.
- [ ] Create `.sops.yaml` declaring recipients: your personal age key (for editing) **and** each host's SSH host key (so the machine self-decrypts at boot).
- [ ] Generate the password hash (`mkpasswd -m sha-512`) and store it encrypted in `secrets/secrets.yaml` under e.g. `dhilipsiva/hashedPassword`.
- [ ] Wire it: `sops.secrets."dhilipsiva/hashedPassword".neededForUsers = true;` then `users.users.dhilipsiva.hashedPasswordFile = config.sops.secrets."dhilipsiva/hashedPassword".path;`. **Remove** the plaintext `hashedPassword` currently in `modules/common.nix`/`users.nix`.
- [ ] Move the **UPS** password: store `ups/monitorPassword` in sops (owner root); set `power.ups.users.upsmon.passwordFile = config.sops.secrets."ups/monitorPassword".path;`. **Remove** the `passwordFile = "/etc/nixos/ups-password"` reference and the inline `secret` literal in the `MONITOR` line of `hosts/desktop/default.nix`.
- [ ] **Break-glass:** because `mutableUsers = false` has no fallback if decryption fails, set a temporary root `hashedPassword` for initial bring-up so a wrong host key can't lock you out. Validate decryption in the VM first.
- [ ] Update `CLAUDE.md`: never commit plaintext secrets; secrets go through sops.

**GATE 4:** No plaintext `hashedPassword` and no `/etc/nixos/ups-password` reference remain in the repo (`git grep` for the old hash / path returns nothing). In the VM, sops decrypts to `/run/secrets-for-users` **before** user creation, and login with the sops-managed password succeeds.

---

## Phase 5 — Declarative disk (disko) + real desktop `hardware-configuration.nix`

Make partitioning reproducible and fix the two hardware placeholders. This is what
makes the VM rehearsal a *true* install rehearsal.

- [ ] Add `disko` as a flake input.
- [ ] Author `hosts/desktop/disko.nix`: GPT with an **ESP** (FAT32, ~1 GiB, `/boot`, for the GRUB EFI dual-boot) + a root partition. Recommended root: LUKS2 → btrfs subvolumes (`@`, `@home`, `@nix`) — or ext4 for simplicity. Express the LUKS key via `keyFile`/`passwordFile` so it's reproducible.
- [ ] **Dual-boot safety:** scope disko to the **Linux target disk only** — declare *only* the NixOS disk in the spec so it never touches the existing Windows ESP/partition.
- [ ] Reduce `hosts/desktop/hardware-configuration.nix` to the minimal real scan (`hostPlatform`, kernel modules, microcode) and let **disko own `fileSystems`**. The committed generic single-ext4 scan does NOT match the target and must not drive partitioning.
- [ ] **Fix the dummy firmware hash:** the `linux-firmware.overrideAttrs` in `hosts/desktop/default.nix` has `sha256 = "sha256-AAAA…"`. Prefer **deleting the custom `fetchgit` override entirely** and relying on `hardware.enableRedistributableFirmware = true` + nixos-hardware (26.05's `linux-firmware` likely already carries the MSI X870E Qualcomm WiFi firmware). Only if a specific firmware is genuinely missing, regenerate the real hash (run once, let it fail, paste the reported hash).
- [ ] Update `CLAUDE.md`: note that the real `hardware-configuration.nix`, the firmware hash, LUKS/disko layout, and UPS wiring are **human-in-the-loop hardware items**; the VM uses the disko-generated layout instead.

**GATE 5:** `nix flake check` green with disko + sops + modular layout all wired. The disko spec references only the intended Linux disk. The firmware override is either removed or carries a real (non-`AAAA`) hash. `nixos-rebuild --flake .#desktop build` succeeds.

---

## Phase 6 — Full VM install rehearsal (nixos-anywhere `--vm-test`, pinned to the VM)

Exercise the *whole* thing — disko partitioning + full closure + sops decryption +
bootloader — in a QEMU VM, with the destructive-command guardrail (Phase 0) ensuring
the target can only ever be the VM.

- [ ] Run the install rehearsal against a **virtual** disk: `nix run github:nix-community/nixos-anywhere -- --flake .#desktop --vm-test` (partitions a QEMU virtual disk exactly per `disko.nix`, installs the closure, boots it — **no real hardware touched**).
- [ ] If driving a persistent VM instead of `--vm-test`, pin `--target-host` to the VM's IP/SSH only (the build-image path bakes `sshd` + your pubkey so the first-boot SSH console gap is closed — see `PLAN.md`). Never point `--target-host` at a real machine in this phase.
- [ ] Verify inside the booted VM: correct hostname, the sops-managed user password logs in, `hyprctl` responds (CLI-first), waybar/hyprland come up (corroborate with a screenshot), disko subvolume/mount layout is as specified, GRUB present.
- [ ] **Parity check** the Nix-generated dotfiles reproduce the old `.config` behavior side-by-side (the Phase 3 gate list) inside this full-install VM, not just a `build-image` VM.
- [ ] Capture any stable-vs-hardware gaps here (if 26.05 genuinely lacks Blackwell/X3D support the VM surfaces it) — this is where the reserved unstable overlay would be populated, as a coherent kernel/mesa/nvidia set, and re-tested.

**GATE 6:** `nixos-anywhere … --vm-test` completes and boots green end-to-end (disko + closure + sops + bootloader). Human sign-off on the graphical session (Hyprland) per `PLAN.md`'s visual-truth gate. This is the **go/no-go** for touching real hardware.

---

## Phase 7 — Real-hardware cutover (HUMAN step — not the agent)

Only after Gate 6. Per `PLAN.md`, real hardware stays human-in-the-loop. The agent may
*prepare* artifacts and *draft* commands; a human runs them against the physical desktop.

- [ ] **Human:** generate the *real* `hosts/desktop/hardware-configuration.nix` on the actual desktop (`nixos-generate-config --show-hardware-config`) and commit it, replacing the generic scan.
- [ ] **Human:** confirm the disko target disk is the correct physical device (by-id path), and that the Windows disk is untouched, **before** running disko.
- [ ] **Human:** provision the host SSH key as a sops recipient and confirm `secrets/` decrypts on the real box; keep the break-glass root password until login is confirmed.
- [ ] **Human:** run the real install (`nixos-anywhere --flake .#desktop --target-host <real>` or manual `disko` + `nixos-install`), then `nixos-rebuild --flake .#desktop switch` for subsequent updates.
- [ ] **Human:** verify GRUB dual-boots into both NixOS and Windows (`useOSProber` picked up the Windows SSD); verify the CyberPower UPS is seen (`upsc cyberpower@localhost`).
- [ ] **Human:** remove the temporary break-glass root password once the sops-managed login is confirmed on hardware.
- [ ] Replace/trim `PLAN.md`→`README.md` guidance so `README.md` documents the live build/switch/VM-rehearsal/secret-rotation workflow, and do a final `CLAUDE.md` pass so it matches the shipped structure.

**GATE 7 (done):** The RTX 5090 desktop boots the modular, home-manager-first, `nixos-26.05` config from this flake; dual-boot and UPS work; no plaintext secrets and no raw `.config/` remain in the repo; `CLAUDE.md`/`README.md` reflect reality.

---

## Cross-cutting known fixes (tracked here so none slip)

- [x] `hosts/desktop/default.nix`: dummy `sha256 = "sha256-AAAA…"` linux-firmware hash — **removed the override entirely** (Phase 1, pulled forward — it blocked every `.#desktop` build). Now `hardware.enableRedistributableFirmware` + nixos-hardware only.
- [~] `hosts/desktop/default.nix`: `/etc/nixos/ups-password` — the inline `secret`/`upsmonConf` MONITOR string is **gone** (reworked to the structured `power.ups.upsmon.monitor` schema in Phase 1); the plaintext `passwordFile` path remains → **still move to sops** (Phase 4).
- [x] `hosts/desktop/default.nix`: NVIDIA `.beta` + `open = false` — **→ `production` + `open = true`** (Phase 1). **(Done.)**
- [ ] `hosts/desktop/hardware-configuration.nix`: generic single-ext4 scan — **regenerate on real hardware / let disko own filesystems** (Phase 5/7).
- [x] `home/default.nix`: `userName` fixed to `"dhilipsiva"` (email kept `dhilipsiva@pm.me`). **(Applied.)**
- [ ] `home/default.nix`: `eval $(atuin init fish)` (wrong fish syntax) — **replaced by `programs.atuin` fish integration** (Phase 3, atuin/fish).
- [ ] `modules/common.nix`: plaintext `hashedPassword` — **→ sops `hashedPasswordFile`** (Phase 4).
- [ ] `modules/common.nix`: `systemd` unit paths (`/home/dhilipsiva/dotfiles/…`, `/home/dhilipsiva/.files/scripts/show_time_notification.sh`) — **verify/fix for the new layout** (Phase 2).
- [ ] Root `configuration.nix` (legacy ThinkPad monolith) — **delete after salvage** (Phase 2).
- [ ] `modules/common.nix`: `backup-nix-config` service copies the now-deleted `/etc/nixos/configuration.nix` — **drop or repoint** it so it doesn't break when `configuration.nix` is removed (Phase 2).
- [ ] `tmp.txt` (repo-root scratch) — **delete**; `clash_royale.sh` / `signature.html` — **keep/delete decision** (Phase 2).
- [x] `flake.nix`: `nixpkgs → nixos-26.05` + home-manager `release-26.05` + **`nixos-hardware` (added Phase 1, follows nixpkgs)**. Still to add: `sops-nix`, `disko`, then commit `flake.lock` (Phases 4/5). No unstable input unless the VM proves one is needed.
- [ ] `CLAUDE.md` — **update at every structural change**. Its whole "What this repo is" section is premised on the `XDG_CONFIG_HOME=~/.files/.config` direct-serve model, which Phase 3 **deletes** — so it needs a **full top-section rewrite**, not just appended invariants. (The `[cite: N]` warning in it is already stale — markers were stripped from the `.nix` files.)
