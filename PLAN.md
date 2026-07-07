# Can Claude Code Safely Drive the Modular / home-manager / STABLE Migration of This NixOS Config from Windows (WSL2 + VM) Before Real Hardware? A 2026 Capability & Trust Assessment

## Objective & Scope

The artifact under test is a **specific migration of THIS repo**, not a generic NixOS workflow:

- **From** a legacy monolithic ThinkPad config (`configuration.nix`, Intel + NVIDIA PRIME offload, hostname `dhilipsiva-thinkpad`) that is being **retired** — reference-only, slated for removal, **never** to be wired into the flake.
- **To** a **modern, modular, home-manager-first** config where:
  1. system config is split by concern into `modules/nixos/*` and per-host `hosts/<host>/*`;
  2. as much as feasible is expressed declaratively as **Nix** (home-manager options), not raw files;
  3. the `.config/` tree served via `XDG_CONFIG_HOME=/home/dhilipsiva/.files/.config` (alacritty, atuin, cheat, fish, git, helix, hypr, sway, waybar, zellij, nvim) is **converted into home-manager Nix** and that XDG override is deleted — raw `xdg.configFile.*.source` is a *bridge of last resort*, not the end state;
  4. the flake tracks **latest-STABLE NixOS** (nixos-26.05 "Yarara", kernel 6.18 LTS, as of this writing) — **not** nixos-unstable;
  5. every step is **doable and testable from Windows through virtualization** (WSL2 + a VM) before any of it touches the real **RTX 5090 / Ryzen 9000 X3D desktop**.

This document answers: **Can Claude Code, from Windows via WSL2 + a VM, safely drive and verify that migration — and where must a human stay in the loop — before real hardware?** It is the **strategy / trust / capability / guardrails** layer. It establishes *why* the Windows→virtualization path is trustworthy and *where* the human-in-the-loop gaps are, with this migration as the thing under test. It deliberately does **not** enumerate the ordered, concrete steps.

## Relationship to TODO.md

Read these two documents together:

- **PLAN.md (this file)** = the *why / whether / how-safely*: objective, capability layers, escalation-of-trust gates, guardrails (settings.json + PreToolUse hook + CLAUDE.md invariants), failure modes, and go/no-go conditions for advancing and for eventually touching real hardware.
- **[TODO.md](./TODO.md)** = the *what / in-what-order*: the concrete, ordered, checkable next-actions that implement the migration (e.g. "retarget flake input to nixos-26.05", "convert `.config/helix` to `programs.helix`", "build an SSH-enabled image with `nixos-rebuild build-image`", "run `nixos-anywhere --vm-test`").

**PLAN.md must NOT duplicate TODO.md's checklist.** Rule of thumb: if it is an ordered action a human/agent checks off, it belongs in TODO.md; if it is a rationale, boundary, gate, or risk, it belongs here.

### Two numbering schemes — do not conflate them

The two documents decompose the work along **different axes**, so their numbers are **not** interchangeable:

- **TODO.md "Phases 0–7"** are *work-order* steps (set up the VM loop → stable → modular → dotfiles → secrets → disk → VM rehearsal → hardware).
- **PLAN.md "Capability Layers L0–L4"** (below) are *trust/autonomy* layers — how autonomously each **testing capability** can be driven, from WSL2 eval up to real hardware.

They map many-to-many:

| PLAN capability layer | Maps to TODO phase(s) |
|---|---|
| **L0** WSL2 refactor + eval/build | 0 (VM loop), 1 (stable retarget), 2 (modular), 3 (dotfiles → Nix) |
| **L1** Headless VM + sops | 0 (build-image), 4 (sops), 6 (SSH-driven install) |
| **L2** Graphical Hyprland validation + parity | 3 (parity gate), 6 (graphical checks) |
| **L3** nixos-anywhere + disko rehearsal | 5 (disko), 6 (`--vm-test`) |
| **L4** Real hardware + CI | 7 (real-hardware cutover) |

When PLAN.md says "Layer L2" it means the capability; when it points you at concrete actions it links to a **TODO Phase**.

## TL;DR
- **Yes, partially — Claude Code (not Cowork) can drive the authoring/refactor (Layer L0), the headless-VM install (Layer L1), and the nixos-anywhere/disko rehearsal (Layer L3) to a high degree of autonomy, and author the CI (Layer L4) outright — but two hard human-in-the-loop gaps remain: the first-boot console gap (a stock NixOS installer ISO does not start sshd and has no password, so it is unreachable until someone acts) and the graphical-Hyprland visual-validation loop (Layer L2).** Cowork is the wrong tool for this job — it is a desktop knowledge-work agent, not a hypervisor/SSH orchestrator; use Claude Code in WSL2.
- **Layer L0 is now the heart of the migration, not a warm-up:** authoring the modular flake refactor, converting `.config` dotfiles into home-manager Nix, retargeting the flake input from nixos-unstable to latest-STABLE, and greening `nix flake check` on the stable toolchain. This is squarely in Claude Code's wheelhouse — especially with **mcp-nixos** to stop it hallucinating option names across a large home-manager surface.
- **The first-boot console gap is closable by engineering, not by the agent watching a screen:** bake the agent's SSH public key + sshd into a custom image (via `nixos-rebuild build-image`, the successor to the now-archived nixos-generators) so the VM boots straight to SSH-reachable. The visual loop is *mostly* closable because Claude Code can read PNG files with its vision model, so an agent can `grim` a screenshot inside the guest over SSH and then read it — but this verifies "something rendered," not "it looks right," so keep a human sign-off for true visual QA.
- **The single biggest trust risk is destructive commands (`nixos-anywhere`/`disko` wipe the target disk; a bad `nixos-rebuild switch` can sever the agent's own SSH control channel).** These are well-documented Claude Code failure classes. Mitigate with hooks-based deny rules (not just the flaky permission allowlist), snapshot-before-change discipline, `--target-host` pinning, and never letting the agent hold the GPG/age private key or run unattended against real hardware.
- **A migration-specific risk to validate in the VM:** the flake's inline claim that "unstable is mandatory for RTX 5090 / Ryzen 9000" is **obsolete** on stable 26.05, but the VM rehearsal must *prove* stable's Blackwell/X3D support before trusting it on real hardware; hold a **scoped unstable overlay** (kernel/mesa/nvidia only) in reserve rather than reverting the whole system to unstable.

## Key Findings

### Verdict by tool
The "job" being verdicted on is now **the migration**: refactor the legacy monolith into a modular, home-manager-first, `.config`-free config on latest-STABLE NixOS, and validate it in a VM before the real desktop.
- **Claude Code**: The right tool. It is an agentic CLI that runs the full read/plan/execute loop in the terminal, with a headless mode (`claude -p`), a permissions system, a hooks system, subagents, MCP client support, background tasks, and vision (image reading). It runs inside WSL2 and can invoke Windows executables (`vmrun.exe`, `powershell.exe`) via WSL interop, and drive the NixOS guest over SSH. **Authoring the modular flake and porting `.config` dotfiles into home-manager Nix is precisely the kind of read-refactor-verify loop it excels at** — with mcp-nixos grounding option names, this strengthens the "right tool" verdict rather than complicating it.
- **Claude Cowork**: Wrong tool. Anthropic positions it explicitly as a desktop app for *non-coding knowledge work* (documents, files, research synthesis) that "runs code and shell commands in an isolated virtual machine (VM) on your computer." It is not designed for arbitrary host-CLI execution, hypervisor control, or SSH orchestration, and its sandboxed execution model actively works against driving an *external* hypervisor. Claude in Chrome is irrelevant here (no browser step in the workflow).
- **The crux limitations**: (1) the first-boot SSH gap (Layer L1); (2) visual truth (Layer L2). Both are named and addressable below.

### The tooling the plan leans on is alive (as of mid-2026)
- **VMware Workstation Pro / vmrun**: Alive and current. Broadcom currently ships **Workstation Pro 26H1** (Build 25388281, which adds a 64-bit Windows app and remote ARM-ESX connections) and **Workstation Pro 25H2u1** (which resolves CVE-2026-22715/22716/22717/22722 per VMSA-2026-0002). Workstation Pro has been **free for all users including commercial** since Broadcom's change of Nov 11, 2024 ("Starting November 11, 2024, these powerful desktop hypervisor products will be available for free to everyone—commercial, educational, and personal users alike… The paid versions… are no longer available for purchase"); no license key is required. `vmrun` (VIX API) is documented and current, with `start`, `stop`, `snapshot`, `listSnapshots`, `revertToSnapshot`, `deleteSnapshot`, `captureScreen`, and guest-ops commands.
- **nixos-anywhere**: Alive, maintained (nix-community, maintainers @Mic92 @Lassulus @phaer @Enzime @a-kenji). SSH-native. Has `--target-host` pinning, `--vm-test` (build + test disk config in a VM without installing), `--stop-after-disko`, `--no-reboot`, and phase control (`--phases kexec,disko,install,reboot`). **This is the linchpin for the Windows rehearsal:** `nixos-anywhere --flake .#desktop --vm-test` runs disko against a virtual disk exactly as specified, installs the closure, and boots it — a true install rehearsal of the migrated config, sops decryption included, without touching hardware.
- **disko**: Alive, used by nixos-anywhere for declarative partitioning; supports mode selection (disko/mount/format) and a VM install-test path. The migration adds a `hosts/desktop/disko.nix` (GPT: ESP + root; optionally LUKS2 → btrfs subvolumes), **scoped to the Linux target disk only** so it never touches the existing Windows drive on the dual-boot desktop. The VM tests disko itself; a plain `nixos-rebuild` VM (`.config.system.build.vm`) supplies its own disk and bypasses disko, so `--vm-test` is the path that validates partitioning.
- **NixOS-WSL**: Alive, maintained (@nzbr), tracking current NixOS releases; installs as a `.wsl` file on WSL ≥ 2.4.4.
- **nixos-generators**: **DEPRECATED and ARCHIVED (read-only) since Jan 30, 2026** (confirmed by the GitHub repo banner: "This repository was archived by the owner on Jan 30, 2026. It is now read-only"). Its README states most of it was upstreamed into nixpkgs starting NixOS 25.05, and "The main, user-visible difference is the new `nixos-rebuild build-image` command, which replaces the venerable `nixos-generate`." The image formats (iso, vmware/VMDK, vm, kexec, etc.) still exist via `config.system.build.images.<format>`. This matters: any plan step that says "use nixos-generators" should now say "use `nixos-rebuild build-image`."
- **sops-nix**: Alive, maintained (@Mic92). Uses age (derivable from the host's ed25519 SSH key via `ssh-to-age`) or GPG. **Chosen over agenix for this migration specifically because the config sets `users.mutableUsers = false`:** only sops-nix cleanly supports a declarative `hashedPasswordFile` in that mode via `secret.neededForUsers = true`, which decrypts the secret to `/run/secrets-for-users` *before* NixOS creates users; agenix forces `initialHashedPassword` workarounds that don't re-apply on rebuild. For the VM test, generate a VM-only age key in-guest — the agent should never hold the operator's real GPG/age private key. Caveat: rotating the host's ed25519 key invalidates boot-time decryption until secrets are re-encrypted to the new recipient. **With `mutableUsers = false` there is NO password fallback if decryption fails — a wrong host key can lock you out — so validate decryption in the VM first and consider a break-glass root hash during bring-up.**

### Claude Code state (2026) relevant to the workflow
- **Headless mode**: `claude -p` runs the agent non-interactively; `--output-format json` returns `total_cost_usd`, `session_id`, `num_turns`, etc.; `--resume <id>` continues a session; `--max-turns`, `--max-budget-usd`, and `--permission-mode` bound the run. Anthropic's own docs recommend wrapping headless runs in an OS-level `timeout` and setting budget guards — "no timeouts" is a documented footgun (a stuck agent runs until killed).
- **Permissions**: allow/deny/ask lists in `settings.json`, evaluated deny → ask → allow (deny always wins and cannot be overridden). Modes: default, acceptEdits, plan, dontAsk, bypassPermissions (a.k.a. `--dangerously-skip-permissions`/yolo).
- **The permission matcher is known-buggy**: wildcards don't match compound commands (`Bash(git:*)` misses `git add && git commit`), "Always Allow" saves dead exact-string rules, and there are 30+ open matching issues. Community consensus (and practitioner writeups) is to move real enforcement into **hooks** (PreToolUse), which receive the command as JSON on stdin and block on exit code 2. Note that even the allowlist model has been attacked: GMO Flatt Security's "Pwning Claude Code in 8 Different Ways" (researcher RyotaK) yielded **CVE-2025-66032** (GitHub Advisory GHSA-xq4m-mc3c-vvg3, CVSS 8.7, published Dec 3, 2025) — bypasses "due to errors in parsing shell commands related to `$IFS` and short CLI flags," fixed in Claude Code v1.0.93, after which Anthropic switched from a blocklist to an allowlist approach. Trail of Bits separately demonstrated argument-injection through allowed commands (GTFOBins class).
- **Hooks**: `command`, `http`, `mcp_tool`, `prompt`, and `agent` handler types; lifecycle events include PreToolUse, and subagent-specific SubagentStart/SubagentStop.
- **Subagents**: `.claude/agents/*.md` (or `~/.claude/agents/`) with YAML frontmatter (name, description, tools, model, permissionMode, hooks, isolation). Enables a build-agent vs VM-ops-agent split with isolated context and per-agent tool restriction. Caveats: auto-routing is unreliable (explicit @-mention is the reliable trigger), and Opus 4.6+ tends to over-spawn subagents.
- **Background tasks**: `Ctrl+B` / `run_in_background` moves long commands off the main loop; output goes to a file the agent reads with `BashOutput`; `/tasks` monitors. Key limits: background tasks die when the session ends (use tmux/nohup for overnight), there's a 5GB output cap, and orphaned tasks can get stuck "running." So the agent does NOT burn context polling a long `nix build` — it backgrounds it and reads incremental output.
- **Vision / image reading**: Claude Code uses the same multimodal vision as the model family (Opus 4.8 lineage); it reads PNG/JPEG/GIF/WebP by file path (`Read`/drag/paste), with 5MB and ~8000×8000px limits, and an image-preview feature added in v2.0.73. This is what makes the Layer L2 screenshot loop conceivable. (Nuance: there have been feature requests for the agent to invoke its own vision on arbitrary files, but reading an image by path in the prompt/working directory works today.)
- **Long-horizon reliability**: Anthropic's marketing/benchmark claims for the recent Opus line (4.5 → 4.8) emphasize long-horizon autonomous coding, self-verification, and computer-use gains. Per OfficeChai's report on METR's benchmark, **METR's latest measurements put Claude Opus 4.6 at a 50%-time horizon of approximately 14.5 hours — with a very wide confidence interval of 6 to 98 hours because METR's task suite is near-saturated** (for baseline, METR put Opus 4.5 at a 50%-time horizon of ~4 hr 49 min, 95% CI 1 hr 49 min to 20 hr 25 min). Treat these as vendor/benchmark claims, not guarantees for *this* infrastructure workflow — long-horizon reliability on messy ops tasks (SWE-EVO-style) is materially lower than clean benchmark numbers.

### WSL2 realities (from GitHub issues and practitioner writeups, 2025–2026)
- Claude Code in WSL2 is widely used and effectively supported, but has real operational hazards: a **memory leak / OOM-kill class of bug** (issues #32892 ~92GB/hr, #22042, #33415 tied to Windows update KB5079473) that can SIGKILL the session and corrupt the session index so `--resume` fails. Mitigate with `.wslconfig` memory caps + `autoMemoryReclaim=dropcache`, frequent git commits, and a CLAUDE.md that records work state.
- **WSL interop can call Windows executables** (`vmrun.exe`, `powershell.exe`) directly from Linux as long as `/mnt/c/Windows/System32` is on `$PATH` and interop isn't disabled. Path translation is the gotcha: `vmrun.exe` needs Windows paths (`C:\...`) for the `.vmx`, so the agent must convert `/mnt/c/...` ↔ `C:\...` (use `wslpath -w`), and quote paths with spaces. Networking to reach the guest may need mirrored networking mode in `.wslconfig`.
- The stock NixOS/Ubuntu-on-WSL2 can run the nix daemon + flakes; NixOS-WSL is the cleaner option. The critical `rm -rf` home-directory incident (#10077) happened on Ubuntu/WSL2 — WSL2 does not add safety here.

### MCP servers that exist and are relevant
- **mcp-nixos** (utensils, MIT): queries real NixOS package/option data (search.nixos.org, Home Manager, nix-darwin, flake inputs) to stop the agent hallucinating option names; ~2 tools, ~1,030 tokens. Actively updated through 2026. **This becomes MORE central in this migration, not less** — authoring a large modular flake and translating a dozen `.config` files into `programs.*` / `wayland.windowManager.*` / `xdg.configFile` options is exactly where invented option names would otherwise proliferate; mcp-nixos grounds every home-manager option against real data. (A lighter DanielRamosAcosta/nixos-mcp also exists for option search.)
- **SSH MCP servers** exist (e.g., tufantunc/ssh-mcp via `claude mcp add`, rorymcmahon/ssh-mcp-server) exposing remote command execution, sudo, timeouts. Usable, but for this workflow the agent can just as well run `ssh` in Bash; an MCP adds a permissionable, structured surface if you want tighter control.
- **No mature, widely-adopted MCP for VMware/Hyper-V/libvirt control** surfaced; `vmrun` over Bash/interop is the pragmatic path. For GUI console interaction (clicking the VMware console when SSH is down), there is no reliable headless-agent path from WSL2 — that is a genuine human-in-the-loop point.

## Details: capability-layer table

Each layer's artifact is the **migrated modular / home-manager / stable config**; the success gate is that *this migration* builds, boots, and behaves in the VM. The "Layer" column is the PLAN capability/trust axis (L0–L4); see the mapping table above for the corresponding TODO phases.

| Capability layer | Step | Autonomy | Enabling mechanism / blocking gap |
|---|---|---|---|
| **L0 · WSL2 refactor + eval/build** | Refactor monolith → `modules/nixos/*` + `home/<user>/*` (TODO Phase 2) | **Autonomous** | Pure Nix editing in WSL2; mcp-nixos grounds option names. (The AI-generated `[cite: N]` markers that once blocked evaluation have already been stripped from `modules/common.nix` and `home/default.nix` — verify none reappear.) |
| L0 | Convert `.config` dotfiles → home-manager Nix (`programs.git/helix/alacritty/fish/atuin`, `programs.waybar`, `wayland.windowManager.hyprland`; `xdg.configFile.source` only as a bridge) — TODO Phase 3 | **Autonomous** | 1:1 option translation for Tier-1 tools; `xdg.configFile.source` fallback for zellij/nvim/cheat. Set `git` identity in Nix: `userName = "dhilipsiva"`, `userEmail = "dhilipsiva@pm.me"` (both already corrected in `home/default.nix`). Do NOT port machine-generated `fish_variables`. |
| L0 | Retarget flake input nixos-unstable → **latest-STABLE** (nixos-26.05); home-manager `release-26.05` with `follows` — TODO Phase 1 | **Autonomous** | One-line input change (**applied** in `flake.nix`) + `flake.lock`; the "unstable is mandatory" comment is removed. Stay pure-stable — no unstable input unless the VM later proves a specific package is missing. |
| L0 | `nix flake check` + build toplevels on the STABLE toolchain | **Autonomous** | Runs under nix daemon + flakes; long builds backgrounded (`run_in_background`), read incrementally. Manage disk space for large closures. |
| L0 | git ops on flake repo | **Autonomous** | Native git in Bash; allowlist `git status/diff/log`, ask on `push`. |
| **L1 · Headless VM + sops** | Drive VMware (`vmrun start/snapshot/revertToSnapshot`) | **Autonomous** | `vmrun.exe` via WSL interop; path translation (`wslpath -w`) required. |
| L1 | First boot → SSH reachable | **HUMAN-ONLY (stock ISO) → Autonomous (custom image)** | **Crux gap:** stock NixOS installer ISO does NOT start sshd and the `nixos` user has an empty password → unreachable without console action (NixOS manual: "activate the SSH daemon via `systemctl start sshd`… you then must set a password"). **Fix:** pre-build a custom image with `nixos-rebuild build-image` embedding `services.openssh.enable` + the agent's `authorizedKeys.keys`; then boot is SSH-reachable with zero console interaction. |
| L1 | Unattended/SSH-driven install of the **migrated** config (TODO Phase 6) | **Autonomous** (once SSH exists) | nixos-anywhere is SSH-native; drives the modular flake + `disko.nix`. |
| L1 | sops decryption of `hashedPasswordFile` + UPS password in-guest (TODO Phase 4) | **Autonomous** | Generate a VM-only age key over SSH; agent never holds operator's real key. `mutableUsers=false` means this is the *only* path to a login — validate it here. |
| **L2 · Graphical Hyprland validation** | Capture screenshot | **Assisted → Autonomous** | Two paths: `vmrun captureScreen <vmx> out.png` (host-side, PNG) OR `grim` inside guest over SSH with `WAYLAND_DISPLAY` set (Wayland-native). Both produce PNGs. |
| L2 | Read/interpret screenshot | **Autonomous (mechanical) / HUMAN-advised (true QA)** | Claude Code reads the PNG via its vision model and can confirm "Hyprland running, waybar present, alacritty window open." It CANNOT reliably certify subjective "renders correctly." Keep human sign-off for real visual QA. |
| L2 | Assert via CLI instead of pixels | **Autonomous** | Strongest loop: `hyprctl clients/monitors`, check processes (waybar, alacritty) over SSH — deterministic, no vision needed. Use this as the primary gate, screenshots as corroboration. |
| L2 | **Parity check: Nix-generated dotfiles == old `.config` behavior** (TODO Phase 3 gate) | **Autonomous (mechanical) / HUMAN-advised** | Migration-specific gate: diff the home-manager-rendered files (git config, helix settings, hyprland.conf, waybar JSON/CSS) against the old `.config` outputs; confirm no silent behavior regression before declaring the dotfile conversion "done." |
| **L3 · nixos-anywhere + disko rehearsal** | Run install of the migrated config against the VM (TODO Phases 5–6) | **Autonomous (guarded)** | SSH-native; exactly what an agent handles well. Use `--vm-test` first; pin `--target-host root@<vm-ip>`. Exercises disko + full config + sops end-to-end. |
| L3 | Prevent wrong-target wipe | **Guardrail-critical** | Hook + deny rules: require `--target-host` to match an allowlisted VM IP; block `nixos-anywhere`/`disko`/`--target-host` against anything else; snapshot before run. |
| **L4 · Real hardware + CI** | Author GitHub Actions (`nix flake check`, toplevel builds) | **Autonomous** | Well within capability; standard CI authorship. |
| L4 | Real `hardware-configuration.nix`, `linux-firmware` hash, LUKS/disko layout, UPS password on the **RTX 5090 desktop** (TODO Phase 7) | **HUMAN-ONLY** | Real-hardware bring-up: the committed generic single-ext4 scan does NOT match the target, the `linux-firmware` sha256 is a `sha256-AAAA…` placeholder, and `/etc/nixos/ups-password` is a real-machine path. VM layers use disko-generated layout and never need the real scan; these items stay human-in-the-loop. |
| L4 | `nixos-rebuild switch` / nixos-anywhere on real desktop | **HUMAN-ONLY (recommended)** | Bricking risk: a bad rebuild or networking/SSH change can sever the agent's own control channel; rollback needs console/BIOS access the agent lacks. Agent advises; human executes. |
| L4 | Physical boot / BIOS / Secure Boot / dual-boot GRUB | **HUMAN-ONLY** | Physical access; no agent path. |

### Guardrail architecture (concrete recommendation)

**1. `settings.json` permissions (coarse layer — necessary but not sufficient):**
```json
{
  "permissions": {
    "allow": [
      "Bash(nix build*)", "Bash(nix flake check*)", "Bash(nix run*)",
      "Bash(git status*)", "Bash(git diff*)", "Bash(git log*)",
      "Bash(vmrun.exe list*)", "Bash(vmrun.exe listSnapshots*)",
      "Bash(vmrun.exe snapshot*)", "Bash(vmrun.exe revertToSnapshot*)",
      "Bash(vmrun.exe start*)", "Bash(vmrun.exe stop*)",
      "Bash(vmrun.exe captureScreen*)",
      "Bash(ssh nixos-vm *)", "Bash(hyprctl*)"
    ],
    "ask": [
      "Bash(git push*)", "Bash(vmrun.exe deleteSnapshot*)"
    ],
    "deny": [
      "Bash(rm -rf*)", "Bash(nixos-rebuild switch*)",
      "Read(./secrets/**)", "Read(**/*.age)", "Read(~/.config/sops/**)",
      "Read(~/.gnupg/**)", "Read(~/.ssh/id_*)"
    ],
    "defaultMode": "default"
  }
}
```
Because the Bash matcher is unreliable against compound/quoted commands (and has documented bypasses — CVE-2025-66032), **do not rely on this as the security boundary** — it is convenience + first-line defense.

**2. PreToolUse hook (the real boundary):** a `command` hook on the Bash tool that receives the command JSON on stdin and:
- Hard-blocks (`exit 2`) any `rm -rf`, `nixos-rebuild switch`, `disko`, `git push --force`, `git reset --hard`, and any `nixos-anywhere` whose `--target-host` is not in an allowlist of VM IPs.
- Requires a fresh VMware snapshot to exist before allowing `nixos-anywhere` (snapshot-before-change enforced mechanically).
- Logs every attempted command to an audit file.
Community-maintained deny-hook kits (e.g., cc-safe-setup, the destructive-git-command hooks) are reasonable starting points; adapt patterns, don't trust blindly (deny-lists have documented bypasses).

**3. `CLAUDE.md` contents outline (encode the plan + invariants):**
- The layer/phase plan and the current step; "never advance without the gate passing."
- **Migration invariants (new direction):**
  - "The flake tracks **latest-STABLE** (nixos-26.05), NOT unstable. Do not point `nixpkgs` at nixos-unstable; use only a scoped `nixpkgs-unstable` overlay (kernel/mesa/nvidia) if the VM proves stable lacks hardware support."
  - "**Do NOT reintroduce raw `.config` served via `XDG_CONFIG_HOME`.** Prefer home-manager Nix (`programs.*` / `wayland.windowManager.*`); `xdg.configFile.*.source` is a bridge only where no HM module exists (zellij/nvim/cheat)."
  - "The legacy root `configuration.nix` is **reference-only, being retired** — never wire it into the flake."
  - "`stateVersion` is a first-install anchor, not the tracked channel — the never-installed desktop is `26.05`; do NOT bump an existing host's `stateVersion` on upgrade."
- **Operational invariants (unchanged):** "The only valid nixos-anywhere/disko target is `root@<VM_IP>`. Never run against a hostname that is not the test VM." "Never run `nixos-rebuild switch` or touch real hardware — advise only." "Never read or exfiltrate `secrets/`, age/GPG keys, or `~/.ssh/id_*`." "Always `vmrun snapshot` before any destructive VM op; revert on failure."
- Work-state log (mitigates WSL2 OOM context loss) + "commit at every stopping point."
- Note the nixos-generators → `nixos-rebuild build-image` change so the agent doesn't reach for the archived tool.

**4. Subagent split:** a `build-agent` (tools: Bash for nix/git, Read/Edit; no vmrun, no ssh) and a `vm-ops-agent` (tools: Bash for vmrun/ssh; no Edit on the flake). Pros: isolated context, tool-scoped blast radius. Cons: auto-routing is unreliable (invoke explicitly), and Opus over-spawns — so keep it to two, invoked by @-mention.

**5. Isolation & recovery:** run in NixOS-WSL or a devcontainer; git worktrees for isolation; rely on VMware snapshots as the real undo for Layers L1–L3.

### Failure-mode register

| # | Failure mode | Severity | Likelihood | Mitigation |
|---|---|---|---|---|
| 1 | `rm -rf` / destructive delete wipes home or repo (documented: #10077 WSL2, LovesWorkin Mac wipe, #49129) | Critical | Medium w/o guards | PreToolUse deny hook; run in NixOS-WSL/container; VMware snapshots; git commits. |
| 2 | nixos-anywhere/disko wipes the WRONG disk/host (esp. the dual-boot machine's Windows drive) | Critical | Low-Med | `--target-host` allowlist hook; `--vm-test` first; disko scoped to the Linux disk only; snapshot precondition; CLAUDE.md invariant. |
| 3 | Bad `nixos-rebuild switch`/network change severs agent's own SSH control channel on real HW | Critical | Medium on HW | Human-only on real hardware; keep console access; test in VM first; generation rollback needs local access. |
| 4 | sops/age key mismatch locks out secrets at boot — and with `mutableUsers=false` there is NO password fallback, so a wrong host key = full lockout | High | Medium | VM-only test key; validate decryption end-to-end in the VM; break-glass root hash during bring-up; re-encrypt on host-key change; agent never holds operator key; `nixos-rebuild test` before switch. |
| 5 | Premature "success" claim / context drift on long task | High | Medium | Prefer deterministic CLI assertions (hyprctl, exit codes) over the model's judgment; self-verify; human gate per layer; Opus 4.8 reduces but doesn't eliminate. |
| 6 | WSL2 OOM-kill kills session, corrupts `--resume` | Medium | Medium | `.wslconfig` memory cap + dropcache; frequent commits; CLAUDE.md state log. |
| 7 | Permission allowlist bypass (compound/quoted commands, argument injection, GTFOBins; CVE-2025-66032) | High | Medium | Enforce via hooks not allowlist; deny-by-default; audit log; keep Claude Code ≥ v1.0.93; don't grant broad `Bash(git*)`/`Bash(nix*)` blindly. |
| 8 | Prompt injection via a malicious flake input / README | High | Low-Med | Opus 4.5 has industry-leading single-attempt robustness (4.7% ASR per Gray Swan, vs Gemini 3 Pro 12.5% / GPT-5.1 21.9%) but this rises to 33.6% at 10 attempts, and Opus 4.6's system card shows GUI-based attacks reaching 78.6% at 200 attempts without safeguards — so pin/review flake inputs and keep least-privilege tools. |
| 9 | Layer L1 first-boot gap silently forces a manual step mid-"unattended" run | Medium | High if stock ISO | Pre-build custom SSH-enabled image; treat as a build prerequisite, not a runtime step. |
| 10 | Layer L2 visual "looks right" false confidence | Medium | Medium | Screenshot loop verifies presence, not correctness; human sign-off for real visual QA. |
| 11 | Broadcom licensing/tooling change to vmrun | Low | Low | Verified current (26H1 / 25H2u1, free for all users incl. commercial since Nov 11, 2024); monitor. |

#### Migration-specific risks (new direction)

| # | Failure mode | Severity | Likelihood | Mitigation |
|---|---|---|---|---|
| M1 | **STABLE nixpkgs lacks bleeding-edge hardware support that unstable had** — RTX 5090 Blackwell / Ryzen 9000 X3D. (Research says 26.05 already covers both: Ryzen 9000 X3D mainlined long ago, kernel 6.18 LTS handles it; RTX 5090 needs `hardware.nvidia.open = true` + `nvidiaPackages.production`, the current production branch. But this must be *proven*, not assumed.) | High | Low-Med | Validate GPU/CPU bring-up in the VM where possible; hold a **scoped `nixpkgs-unstable` overlay (kernel/mesa/nvidia only, as a coherent set)** in reserve, empty today; NEVER revert the whole system to unstable; never mix a single ABI-coupled package across nixpkgs revisions. |
| M2 | **Dotfile-to-Nix conversion silently changes app behavior** (parity regression) — HM renders subtly different git aliases, helix settings, hyprland binds, waybar modules than the raw `.config` did | Medium | Medium | Side-by-side VM diff of rendered outputs vs old `.config` (Layer L2 parity gate); convert Tier-1 tools first (full-native, low risk); keep fragile configs (zellij KDL keybinds, nvim vim-plug) as `xdg.configFile.source` initially rather than hand-translating. |
| M3 | **`stateVersion` mishandling** when moving to a newer stable release — bumping `24.11` → `26.05` on a machine that already installed at `24.11` | Medium | Low-Med | Treat `stateVersion` as a first-install anchor: the never-installed desktop = `26.05` (fix the current `24.11`); any migrated existing host KEEPS its original value even while tracking the 26.05 channel. Never auto-bump. |
| M4 | **Loss of the direct-edit `.config` ergonomics** after Nix-ifying — a quick dotfile tweak now needs a rebuild instead of an editor save | Low | Medium | Accepted trade-off of declarative config; mitigate by keeping genuinely-iterative or fragile files (nvim, zellij) as sourced files during the transition; converge to pure Nix per tool only once verified in the VM. |
| M5 | **`linux-firmware` placeholder hash / real hardware scan** committed as if valid | Medium | Low | Real-hardware Layer L4 item, human-in-the-loop; prefer `hardware.enableRedistributableFirmware` + nixos-hardware over a hand-rolled `fetchgit` override; the VM never needs the real scan. |

### Cost/time realism
- **Time is dominated by nix builds and VM installs, not agent thinking.** With background tasks, the agent backgrounds a long `nix build`/install and reads incremental output rather than polling, so it does not burn context idling — but note background tasks end with the session, so a truly overnight run needs tmux/nohup + a resumable design. (The migration's Layer L0 rebuilds can be large — a modular flake + full home-manager closure — so this matters early.)
- **On a Max plan**, usage is a shared pool across Claude chat + Claude Code + Cowork; there are 5-hour rolling limits (doubled May 6, 2026, peak throttling removed) plus weekly caps (all-models and Sonnet-only). A multi-phase, many-tool-call ops session is Opus-heavy if you let it; the cost-control pattern is plan-with-Opus/execute-with-Sonnet (`/model opusplan`) and route routine steps to Sonnet. Programmatic/headless use (`claude -p`) draws from a separate monthly credit as of June 15, 2026 ($100 on Max 5x, $200 on Max 20x), then stops or bills API rates.
- **On API**, Opus 4.8 is ~$5/$25 per MTok in/out, Sonnet ~$3/$15; a heavily agentic ops session with many tool calls and re-reads can run tens of dollars per layer iteration — the JSON `total_cost_usd` per `-p` invocation is the metric to track, and set `--max-budget-usd`.

## Recommendations

The staged structure below is an **escalation of trust**, re-pointed at executing the migration in dependency order. Each stage keeps all guardrail preconditions; **concrete ordered steps live in [TODO.md](./TODO.md)**, not here. (Stage *N* corresponds to capability Layer L*(N-1)*.)

**Stage 1 — Do now (Layer L0, fully autonomous): author the migration.** Point Claude Code (in NixOS-WSL) at the flake with the `settings.json` + PreToolUse hook + CLAUDE.md above, and add the **mcp-nixos** server. Have the agent: refactor the legacy monolith into `modules/nixos/*` + `home/<user>/*`, convert `.config` dotfiles into home-manager Nix (Tier-1 full-native first: git/atuin/alacritty/helix/fish — fixing the git `userName` to `dhilipsiva` while keeping `dhilipsiva@pm.me`), retarget the flake input from nixos-unstable to **latest-STABLE (nixos-26.05)**, and green `nix flake check` + toplevel builds on the stable toolchain, backgrounding long builds. (The `[cite: N]` evaluation blocker is already cleared.) Benchmark to advance: **the migrated modular home-manager config passes `nix flake check` on STABLE and builds its toplevels, committed.** *Concrete ordered steps: TODO Phases 0–3.*

**Stage 2 — Close the Layer L1 gap before automating it.** Have the agent (or you) build a **custom installer/VM image with `nixos-rebuild build-image`** embedding sshd + the agent's SSH pubkey. This converts "first boot" from human-only to autonomous. (A dynamic-per-VM alternative — a pre-built cloud-init + open-vm-tools image fed SSH keys via VMware `guestinfo.*` in the `.vmx` — works too, but per VMware's own June 2026 guidance it does *not* work against a stock installer ISO, only against a pre-built image that already has the tooling running.) Then let the agent drive `vmrun` (via interop, with `wslpath -w`) to snapshot/boot, and run the SSH-driven install of the migrated config + in-guest sops decryption (the `mutableUsers=false` login path). Benchmark: **the migrated config boots SSH-reachable unattended in the VM; the sops `hashedPasswordFile` and UPS secret decrypt in-guest.** *Concrete ordered steps: TODO Phases 4 and 6.*

**Stage 3 — Layer L2 with the CLI-first validation loop + parity check.** Make deterministic checks (`hyprctl clients/monitors`, process checks over SSH) the primary gate; use `grim`-over-SSH or `vmrun captureScreen` PNGs read by Claude's vision as corroboration. Add the **parity gate**: diff the home-manager-rendered dotfiles against the old `.config` behavior so the Nix-ification did not silently regress anything. Require a **human visual sign-off** before marking Layer L2 "passed." Benchmark: **Hyprland/waybar/alacritty confirmed running on the migrated config by CLI, rendered dotfiles match old `.config` behavior, and a human glances at one screenshot.** *Concrete ordered steps: TODO Phases 3 and 6.*

**Stage 4 — Layer L3 rehearsal, heavily guarded.** Only with the `--target-host` allowlist hook and snapshot-precondition hook active. Run `nixos-anywhere --flake .#desktop --vm-test` first (disko + full migrated config + sops end-to-end against a virtual disk), then the real install against the pinned VM. Benchmark: **clean install of the migrated config to the VM, reboot, SSH back in, secrets present.** If the agent ever proposes a target that isn't the VM IP, the hook must block it — that's your go/no-go signal for trusting the setup. **Explicitly validate the stable-vs-unstable hardware tension here** (RTX 5090 / Ryzen 9000): if the VM surfaces missing support, reach for the scoped unstable overlay, not a full-system unstable revert. *Concrete ordered steps: TODO Phases 5 and 6.*

**Stage 5 — Layer L4, agent as author/advisor only.** Let the agent write the GitHub Actions CI (autonomous) and *draft* the hardware deploy runbook. The real-hardware target is the **RTX 5090 desktop**, and hardware bring-up — real `hardware-configuration.nix`, the `linux-firmware` hash, the LUKS/disko layout, the UPS password, dual-boot GRUB — **stays human-in-the-loop**. **Do not** let the agent run `nixos-rebuild switch`/nixos-anywhere against the desktop unattended. Human executes hardware deploys with console access available. Threshold to revisit: only after many flawless VM rehearsals AND a tested, console-independent rollback path would limited assisted (never unattended) hardware operation be defensible. *Concrete ordered steps: TODO Phase 7.*

**Thresholds that change the recommendation:**
- If a maintained, audited VMware-control MCP with target pinning appears, Layer L1/L3 orchestration gets safer (revisit the interop path).
- If Claude Code ships OS-level command sandboxing on WSL2 that is on-by-default and robust, downgrade several Critical risks.
- If the visual loop must certify subjective correctness, it stays human-in-the-loop regardless of model improvements — vision confirms presence, not aesthetic correctness.
- If the VM rehearsal proves STABLE 26.05 fully drives the RTX 5090 / Ryzen 9000 (as the research predicts), the scoped unstable overlay can stay empty permanently — a cleaner end state than the flake's current all-unstable premise.

## Caveats
- **Vendor/benchmark claims are flagged as such.** The METR ~14.5-hour horizon for Opus 4.6 carries a 6–98 hour confidence interval and comes from a near-saturated task suite; the prompt-injection robustness figures (4.7% single-attempt, rising to 33.6% at 10 attempts and 78.6% for GUI attacks at 200 attempts) and "self-verifies before reporting" are Anthropic/Gray Swan benchmark or system-card claims, not guarantees for this specific messy ops workflow; long-horizon reliability on real ops tasks is materially lower than clean-benchmark numbers.
- **The stable-support claims for new hardware are research, to be VM-verified.** That nixos-26.05 (kernel 6.18 LTS) fully supports Ryzen 9000 X3D and that `hardware.nvidia.open = true` + `nvidiaPackages.production` drives the RTX 5090 Blackwell is well-sourced (NixOS wiki, release notes) but must be proven in the VM before it is trusted on the real desktop. Confirm the exact production driver version at execution time (via mcp-nixos / `nix eval`) rather than trusting a number quoted here. Do NOT use `nvidiaPackages.beta` (a pre-580 workaround) or `.legacy_580` (a differently-scoped legacy branch, currently broken in 26.05 per nixpkgs #503740).
- **Sources are dated and mixed in authority.** Official Anthropic docs (code.claude.com, claude.com, anthropic.com) are primary; GitHub issues (#10077, #32892, #17084, etc.) and advisories (CVE-2025-66032 / GHSA-xq4m-mc3c-vvg3) are verified primary reports; a substantial fraction of Claude Code "how-to" detail (permission-matcher bugs, background-task limits, cost patterns) comes from practitioner blogs and community kits from 2025–2026, which are consistent with each other but are not official. Where a claim rests only on community sources it is labeled inference.
- **The nixos-generators archival is a real, recent change (Jan 30, 2026)** — plans and older tutorials referencing it should switch to `nixos-rebuild build-image`. This is the kind of drift that will keep happening; re-verify tool status before each layer.
- **This assessment assumes the stated setup** (Claude Code in WSL2, vmrun over interop, SSH to guest). A materially cleaner architecture exists — run Claude Code inside a Linux VM/host with libvirt/QEMU instead of VMware-on-Windows-via-interop — which removes the WSL-interop path-translation and networking fragility entirely; if VMware Workstation is not a hard requirement, consider it.
- **Confidence labels**: tool-alive status (vmrun/26H1, nixos-anywhere, disko, NixOS-WSL, sops-nix) = fact (primary docs/repos, 2026); nixos-generators archived = fact (repo banner, Jan 30 2026); nixos-26.05 is current STABLE = fact (release announcement, 2026-05-30); stock ISO has no sshd/password = fact (NixOS manual); Claude Code features (headless, hooks, subagents, vision, background) = fact (official docs); permission-matcher bugs and cost patterns = inference (consistent community reports); STABLE fully driving the RTX 5090/Ryzen 9000 = well-sourced research pending VM verification; the exact autonomy ceiling per layer = inference/estimate.
