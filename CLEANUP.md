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

### From Phase 3 (fill in as each tool is ported)
- **[SUPERSEDED]** `.config/<tool>/` subtrees — delete **each** one as its tool is ported
  to home-manager Nix and verified in the VM. Tools to port/retire:
  `alacritty`, `atuin`, `cheat`, `fish` (incl. machine-generated `fish_variables`, NOT
  ported), `git`, `helix`, `hypr`, `nvim`, `waybar`, `zellij`. (`.config/sway` already gone.)
- **[SUPERSEDED]** the whole `.config/` directory + the `environment.variables.XDG_CONFIG_HOME`
  override in `modules/nixos/environment.nix` — remove once `.config/` is empty.

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
