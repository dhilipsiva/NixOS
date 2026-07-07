# CLEANUP — deferred deletions & doc updates (do at the END, after all phases)

> Running manifest of files that the migration **supersedes** or that need a final
> decision. **Do NOT delete these mid-migration** — we hold them until every phase is
> green, then delete legacy/unwanted files and rewrite the docs in one final pass.
> Update this file at the end of each phase.
>
> Legend: **[SUPERSEDED]** = replaced by new config, safe to delete once verified ·
> **[DECIDE]** = personal/keep-or-drop call for the user · **[DOC]** = update, don't delete.

## Already removed (for the record — no action needed)

- `configuration.nix` (root, legacy ThinkPad monolith) — deleted in Phase 2 (in git history).
- `modules/common.nix` — split into `modules/nixos/*` in Phase 2.
- `home/default.nix` — renamed to `home/dhilipsiva/default.nix` in Phase 2.
- `tmp.txt` — deleted in Phase 2 (unreferenced scratch).
- `clash_royale.sh` — moved to `misc/clash_royale.sh` in Phase 2.

## To delete once the migration is verified

### From Phase 2
- **[SUPERSEDED]** `scripts/show_time_notification.sh` — reimplemented as a home-manager
  user service that builds the script into the Nix store (`home/dhilipsiva/services.nix`).
  The loose copy is referenced by nothing. Delete after confirming the HM timer works on
  real hardware. *(If `scripts/` ends up empty, remove the directory too.)*

### From Phase 3 (done — XDG_CONFIG_HOME override already removed)
- **[SUPERSEDED — safe to delete now]** these `.config/` subtrees are **inert** (ported to
  native home-manager, or their tool was dropped, and nothing references them):
  `.config/alacritty`, `.config/atuin`, `.config/git`, `.config/helix`, `.config/fish`
  (incl. machine-generated `fish_variables`, intentionally NOT ported),
  `.config/nvim` (dropped — neovim not installed), `.config/cheat` (dropped — cheat not installed).
- **[STILL REFERENCED — do NOT delete yet]** `.config/waybar`, `.config/hypr`, `.config/zellij`
  are still read as `xdg.configFile.source` bridges (`home/dhilipsiva/{wayland,terminal}.nix`).
  Delete only **after** they're natively translated (`programs.waybar.settings` /
  `wayland.windowManager.hyprland.settings` / `programs.zellij.settings`) and re-verified.
  Native translation also prunes the laptop-era waybar modules (battery / battery#bat2 / backlight).
- **[DONE]** `environment.variables.XDG_CONFIG_HOME` override — already removed from
  `modules/nixos/environment.nix` in Phase 3.
- Once all `.config/*` are deleted, remove the now-empty `.config/` directory.

## Phase 4 (sops) — ROTATE before real hardware (not deletions; owner actions)

These are **placeholders** the agent generated so the mechanism is complete and green.
The private halves live OUTSIDE the repo at `/home/nixos/phase4-keys/` (never committed);
they are throwaway and MUST be rotated by the owner before any real deployment.

- **[ROTATE]** `&operator` in `.sops.yaml` — currently `ssh-to-age` of a throwaway keypair.
  Replace with `ssh-to-age < ~/.ssh/id_ed25519.pub` (your key), then
  `SOPS_AGE_SSH_PRIVATE_KEY_FILE=~/.ssh/id_ed25519 sops updatekeys secrets/secrets.yaml`.
- **[ROTATE]** `secrets/secrets.yaml` values — currently a RANDOM UNKNOWN password hash
  (machine stays safely locked → use root break-glass) + `changeme-rotate` UPS password.
  `sops secrets/secrets.yaml` and set your REAL, freshly-rotated password (the old
  `$6$3TFqdE8…` hash is already burned in git history) + the real CyberPower UPS password.
- **[ROTATE]** root break-glass key in `hosts/desktop/default.nix`
  (`users.users.root.openssh.authorizedKeys.keys`) — replace the `PLACEHOLDER` ed25519 pubkey
  with your own.
- **[PHASE 7]** enrol the real desktop host key: `ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub`
  → add under the `secrets.yaml` rule in `.sops.yaml` → `sops updatekeys`. First real boot has
  no enrolled host key yet → recover via GRUB `init=/bin/sh`.
- **[CLEAN]** after rotation, delete `/home/nixos/phase4-keys/` (throwaway operator + vmtest
  keys) once no longer needed for VM tests.
- Guardrail: `scripts/check-sops-recipients.sh` must stay green (vmtest never a recipient of
  secrets.yaml; no plaintext hash / ups-password in `.nix`).

## Phase 5 (disko) — real-hardware items (owner, Phase 6/7)

- **[SET]** `hosts/desktop/disko.nix` `targetDisk` — currently a guarded
  `/dev/disk/by-id/REPLACE-ME…` placeholder. On the real machine: `ls -l /dev/disk/by-id/`,
  cross-check with `lsblk -o NAME,SERIAL,MODEL,SIZE` that it's the **Linux** SSD (not Windows),
  run `sudo scripts/preflight-disk-check.sh <the by-id>` (refuses Windows-signature disks),
  then paste the id. The eval warning + assertions are build-hygiene only — they do NOT
  distinguish the Linux SSD from the Windows disk; that's on you + the preflight script.
- **[REGEN]** `hosts/desktop/hardware-configuration.nix` — regenerate on the real machine
  (`nixos-generate-config --show-hardware-config`), **keeping the fileSystems/swap removal**
  (disko owns them). The committed scan is generic and does not match the real hardware.
- **[LUKS]** the root passphrase: Phase 6 `--vm-test` uses disko's auto `/tmp/secret.key`;
  Phase 7 real install delivers the real passphrase on tmpfs via
  `nixos-anywhere --disk-encryption-keys /tmp/secret.key /run/luks.key`. Never commit a key;
  never set `keyFile`/`settings.keyFile` (would break the interactive boot prompt).
- **[PHASE 6]** add `disko.tests.*`/`bootCommands` wiring for `nixos-anywhere --vm-test` **only
  after** confirming the option exists on the pinned disko (it is NOT a module option today —
  it's a test-framework arg — so it was deliberately left out of Phase 5).

## Phase 6 (--vm-test rehearsal) — TEST SCAFFOLDING to remove before Phase 7

The GATE-6 install rehearsal needed test-only wiring. It is scoped to
`config.system.build.installTest` and never reaches the real toplevel (verified), but
**remove it before the real install** so no throwaway key or test override ships:

- **[REMOVE]** `hosts/desktop/disko.nix` → the `disko.tests = { … }` block (bootCommands /
  extraConfig / extraChecks). It's only read by `installTest`; delete once Phase 7 is done.
- **[REMOVE]** `modules/nixos/vmtest-install.nix` — the TEST-ONLY overlay (forces
  canTouchEfiVariables=false, useOSProber=false, sops→vm-test.yaml, injects the throwaway host key).
- **[REMOVE]** `keys/vmtest_host_ed25519_key` — a committed THROWAWAY ed25519 host key. It is a
  recipient of the FAKE `secrets/vm-test.yaml` ONLY (`&vmtest` = `age10hwn…`), so it cannot decrypt
  real secrets — but it is a private key in the repo. **Guardrail: `&vmtest` must NEVER be added to
  `secrets/secrets.yaml`'s creation_rules** (keep `scripts/check-sops-recipients.sh` green).
- **[VERIFY on real HW]** GATE 6 proved the sops MECHANISM with a fake file + throwaway key. Real
  login needs Phase 7: `ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub` → add to `secrets.yaml`'s
  rule in `.sops.yaml` → `sops updatekeys secrets/secrets.yaml` → set the real `$6$` password. First
  real boot uses the root break-glass / GRUB `init=/bin/sh` until that enrollment is confirmed.
- **[HUMAN]** visual sign-off that the Hyprland desktop renders (waybar/wallpaper/terminal) — no
  headless path can prove it.

## Docs to update in the final pass

- **[DOC]** `README.md` — rewrite to document the live build/switch/VM-rehearsal/secret-rotation
  workflow (currently pre-migration). Phase 7 item.
- **[DOC]** `CLAUDE.md` — final pass so the "What this repo is" intro (still describes the
  `XDG_CONFIG_HOME` direct-serve model) matches the shipped `.config`-free structure.
- **[DOC]** `PLAN.md` / `TODO.md` — planning docs. Decide keep-as-history vs. archive/trim
  once the migration lands.
- **[DOC]** this file (`CLEANUP.md`) — delete itself once its actions are all executed.

## Keep / decide (personal, not migration-driven)

- **[DECIDE]** `misc/clash_royale.sh` — personal Android autoplay script; keep in `misc/` or drop.
- **[DECIDE]** `signature.html` — email signature; keep only if still used.
