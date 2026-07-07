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
