# Can Claude Code (and/or Cowork) Drive a Multi-Phase NixOS-Testing Workflow on Windows? A 2026 Capability & Trust Assessment

## TL;DR
- **Yes, partially — Claude Code (not Cowork) can drive Phases 0, 1, and 3 to a high degree of autonomy, and author Phase 4's CI outright, but two hard human-in-the-loop gaps remain: the Phase 1 first-boot console gap (a stock NixOS installer ISO does not start sshd and has no password, so it is unreachable until someone acts) and the Phase 2 graphical-Hyprland visual-validation loop.** Cowork is the wrong tool for this job — it is a desktop knowledge-work agent, not a hypervisor/SSH orchestrator; use Claude Code in WSL2.
- **The Phase 1 console gap is closable by engineering, not by the agent watching a screen:** bake the agent's SSH public key + sshd into a custom image (via `nixos-rebuild build-image`, the successor to the now-archived nixos-generators) so the VM boots straight to SSH-reachable. The Phase 2 visual loop is *mostly* closable because Claude Code can read PNG files with its vision model, so an agent can `grim` a screenshot inside the guest over SSH and then read it — but this verifies "something rendered," not "it looks right," so keep a human sign-off for true visual QA.
- **The single biggest trust risk is destructive commands (`nixos-anywhere`/`disko` wipe the target disk; a bad `nixos-rebuild switch` can sever the agent's own SSH control channel).** These are well-documented Claude Code failure classes. Mitigate with hooks-based deny rules (not just the flaky permission allowlist), snapshot-before-change discipline, `--target-host` pinning, and never letting the agent hold the GPG/age private key or run unattended against real hardware.

## Key Findings

### Verdict by tool
- **Claude Code**: The right tool. It is an agentic CLI that runs the full read/plan/execute loop in the terminal, with a headless mode (`claude -p`), a permissions system, a hooks system, subagents, MCP client support, background tasks, and vision (image reading). It runs inside WSL2 and can invoke Windows executables (`vmrun.exe`, `powershell.exe`) via WSL interop, and drive the NixOS guest over SSH.
- **Claude Cowork**: Wrong tool. Anthropic positions it explicitly as a desktop app for *non-coding knowledge work* (documents, files, research synthesis) that "runs code and shell commands in an isolated virtual machine (VM) on your computer." It is not designed for arbitrary host-CLI execution, hypervisor control, or SSH orchestration, and its sandboxed execution model actively works against driving an *external* hypervisor. Claude in Chrome is irrelevant here (no browser step in the workflow).
- **The crux limitations**: (1) Phase 1 first-boot SSH gap; (2) Phase 2 visual truth. Both are named and addressable below.

### The tooling the plan leans on is alive (as of mid-2026)
- **VMware Workstation Pro / vmrun**: Alive and current. Broadcom currently ships **Workstation Pro 26H1** (Build 25388281, which adds a 64-bit Windows app and remote ARM-ESX connections) and **Workstation Pro 25H2u1** (which resolves CVE-2026-22715/22716/22717/22722 per VMSA-2026-0002). Workstation Pro has been **free for all users including commercial** since Broadcom's change of Nov 11, 2024 ("Starting November 11, 2024, these powerful desktop hypervisor products will be available for free to everyone—commercial, educational, and personal users alike… The paid versions… are no longer available for purchase"); no license key is required. `vmrun` (VIX API) is documented and current, with `start`, `stop`, `snapshot`, `listSnapshots`, `revertToSnapshot`, `deleteSnapshot`, `captureScreen`, and guest-ops commands.
- **nixos-anywhere**: Alive, maintained (nix-community, maintainers @Mic92 @Lassulus @phaer @Enzime @a-kenji). SSH-native. Has `--target-host` pinning, `--vm-test` (build + test disk config in a VM without installing), `--stop-after-disko`, `--no-reboot`, and phase control (`--phases kexec,disko,install,reboot`).
- **disko**: Alive, used by nixos-anywhere for declarative partitioning; supports mode selection (disko/mount/format) and a VM install-test path.
- **NixOS-WSL**: Alive, maintained (@nzbr), tracking current NixOS releases; installs as a `.wsl` file on WSL ≥ 2.4.4.
- **nixos-generators**: **DEPRECATED and ARCHIVED (read-only) since Jan 30, 2026** (confirmed by the GitHub repo banner: "This repository was archived by the owner on Jan 30, 2026. It is now read-only"). Its README states most of it was upstreamed into nixpkgs starting NixOS 25.05, and "The main, user-visible difference is the new `nixos-rebuild build-image` command, which replaces the venerable `nixos-generate`." The image formats (iso, vmware/VMDK, vm, kexec, etc.) still exist via `config.system.build.images.<format>`. This matters: any plan step that says "use nixos-generators" should now say "use `nixos-rebuild build-image`."
- **sops-nix**: Alive, maintained (@Mic92). Uses age (derivable from the host's ed25519 SSH key via `ssh-to-age`) or GPG. For the VM test, generate a VM-only age key in-guest — the agent should never hold the operator's real GPG/age private key. Note the sops-nix caveat: rotating the host's ed25519 key invalidates boot-time decryption until secrets are re-encrypted to the new recipient.

### Claude Code state (2026) relevant to the workflow
- **Headless mode**: `claude -p` runs the agent non-interactively; `--output-format json` returns `total_cost_usd`, `session_id`, `num_turns`, etc.; `--resume <id>` continues a session; `--max-turns`, `--max-budget-usd`, and `--permission-mode` bound the run. Anthropic's own docs recommend wrapping headless runs in an OS-level `timeout` and setting budget guards — "no timeouts" is a documented footgun (a stuck agent runs until killed).
- **Permissions**: allow/deny/ask lists in `settings.json`, evaluated deny → ask → allow (deny always wins and cannot be overridden). Modes: default, acceptEdits, plan, dontAsk, bypassPermissions (a.k.a. `--dangerously-skip-permissions`/yolo).
- **The permission matcher is known-buggy**: wildcards don't match compound commands (`Bash(git:*)` misses `git add && git commit`), "Always Allow" saves dead exact-string rules, and there are 30+ open matching issues. Community consensus (and practitioner writeups) is to move real enforcement into **hooks** (PreToolUse), which receive the command as JSON on stdin and block on exit code 2. Note that even the allowlist model has been attacked: GMO Flatt Security's "Pwning Claude Code in 8 Different Ways" (researcher RyotaK) yielded **CVE-2025-66032** (GitHub Advisory GHSA-xq4m-mc3c-vvg3, CVSS 8.7, published Dec 3, 2025) — bypasses "due to errors in parsing shell commands related to `$IFS` and short CLI flags," fixed in Claude Code v1.0.93, after which Anthropic switched from a blocklist to an allowlist approach. Trail of Bits separately demonstrated argument-injection through allowed commands (GTFOBins class).
- **Hooks**: `command`, `http`, `mcp_tool`, `prompt`, and `agent` handler types; lifecycle events include PreToolUse, and subagent-specific SubagentStart/SubagentStop.
- **Subagents**: `.claude/agents/*.md` (or `~/.claude/agents/`) with YAML frontmatter (name, description, tools, model, permissionMode, hooks, isolation). Enables a build-agent vs VM-ops-agent split with isolated context and per-agent tool restriction. Caveats: auto-routing is unreliable (explicit @-mention is the reliable trigger), and Opus 4.6+ tends to over-spawn subagents.
- **Background tasks**: `Ctrl+B` / `run_in_background` moves long commands off the main loop; output goes to a file the agent reads with `BashOutput`; `/tasks` monitors. Key limits: background tasks die when the session ends (use tmux/nohup for overnight), there's a 5GB output cap, and orphaned tasks can get stuck "running." So the agent does NOT burn context polling a long `nix build` — it backgrounds it and reads incremental output.
- **Vision / image reading**: Claude Code uses the same multimodal vision as the model family (Opus 4.8 lineage); it reads PNG/JPEG/GIF/WebP by file path (`Read`/drag/paste), with 5MB and ~8000×8000px limits, and an image-preview feature added in v2.0.73. This is what makes the Phase 2 screenshot loop conceivable. (Nuance: there have been feature requests for the agent to invoke its own vision on arbitrary files, but reading an image by path in the prompt/working directory works today.)
- **Long-horizon reliability**: Anthropic's marketing/benchmark claims for the recent Opus line (4.5 → 4.8) emphasize long-horizon autonomous coding, self-verification, and computer-use gains. Per OfficeChai's report on METR's benchmark, **METR's latest measurements put Claude Opus 4.6 at a 50%-time horizon of approximately 14.5 hours — with a very wide confidence interval of 6 to 98 hours because METR's task suite is near-saturated** (for baseline, METR put Opus 4.5 at a 50%-time horizon of ~4 hr 49 min, 95% CI 1 hr 49 min to 20 hr 25 min). Treat these as vendor/benchmark claims, not guarantees for *this* infrastructure workflow — long-horizon reliability on messy ops tasks (SWE-EVO-style) is materially lower than clean benchmark numbers.

### WSL2 realities (from GitHub issues and practitioner writeups, 2025–2026)
- Claude Code in WSL2 is widely used and effectively supported, but has real operational hazards: a **memory leak / OOM-kill class of bug** (issues #32892 ~92GB/hr, #22042, #33415 tied to Windows update KB5079473) that can SIGKILL the session and corrupt the session index so `--resume` fails. Mitigate with `.wslconfig` memory caps + `autoMemoryReclaim=dropcache`, frequent git commits, and a CLAUDE.md that records work state.
- **WSL interop can call Windows executables** (`vmrun.exe`, `powershell.exe`) directly from Linux as long as `/mnt/c/Windows/System32` is on `$PATH` and interop isn't disabled. Path translation is the gotcha: `vmrun.exe` needs Windows paths (`C:\...`) for the `.vmx`, so the agent must convert `/mnt/c/...` ↔ `C:\...` (use `wslpath -w`), and quote paths with spaces. Networking to reach the guest may need mirrored networking mode in `.wslconfig`.
- The stock NixOS/Ubuntu-on-WSL2 can run the nix daemon + flakes; NixOS-WSL is the cleaner option. The critical `rm -rf` home-directory incident (#10077) happened on Ubuntu/WSL2 — WSL2 does not add safety here.

### MCP servers that exist and are relevant
- **mcp-nixos** (utensils, MIT): queries real NixOS package/option data (search.nixos.org, Home Manager, nix-darwin, flake inputs) to stop the agent hallucinating option names; ~2 tools, ~1,030 tokens. Actively updated through 2026. Genuinely useful for authoring the flake. (A lighter DanielRamosAcosta/nixos-mcp also exists for option search.)
- **SSH MCP servers** exist (e.g., tufantunc/ssh-mcp via `claude mcp add`, rorymcmahon/ssh-mcp-server) exposing remote command execution, sudo, timeouts. Usable, but for this workflow the agent can just as well run `ssh` in Bash; an MCP adds a permissionable, structured surface if you want tighter control.
- **No mature, widely-adopted MCP for VMware/Hyper-V/libvirt control** surfaced; `vmrun` over Bash/interop is the pragmatic path. For GUI console interaction (clicking the VMware console when SSH is down), there is no reliable headless-agent path from WSL2 — that is a genuine human-in-the-loop point.

## Details: Phase-by-phase capability table

| Phase | Step | Autonomy | Enabling mechanism / blocking gap |
|---|---|---|---|
| **0. WSL2 eval/build** | `nix flake check`, build toplevels | **Autonomous** | Runs in WSL2 under nix daemon + flakes; long builds backgrounded (`run_in_background`), read incrementally. Manage disk space for large closures. |
| 0 | git ops on flake repo | **Autonomous** | Native git in Bash; allowlist `git status/diff/log`, ask on `push`. |
| 0 | sudo-less nix builds | **Autonomous** | `nix build` needs no sudo with a working daemon; permission model handles cleanly. |
| **1. Headless VM + sops** | Drive VMware (`vmrun start/snapshot/revertToSnapshot`) | **Autonomous** | `vmrun.exe` via WSL interop; path translation (`wslpath -w`) required. |
| 1 | First boot → SSH reachable | **HUMAN-ONLY (stock ISO) → Autonomous (custom image)** | **Crux gap:** stock NixOS installer ISO does NOT start sshd and the `nixos` user has an empty password → unreachable without console action (NixOS manual: "activate the SSH daemon via `systemctl start sshd`… you then must set a password"). **Fix:** pre-build a custom image with `nixos-rebuild build-image` embedding `services.openssh.enable` + the agent's `authorizedKeys.keys`; then boot is SSH-reachable with zero console interaction. |
| 1 | Unattended/SSH-driven install | **Autonomous** (once SSH exists) | nixos-anywhere is SSH-native. |
| 1 | sops test-key generation in-guest | **Autonomous** | Generate a VM-only age key over SSH; agent never holds operator's real key. |
| **2. Graphical Hyprland validation** | Capture screenshot | **Assisted → Autonomous** | Two paths: `vmrun captureScreen <vmx> out.png` (host-side, PNG) OR `grim` inside guest over SSH with `WAYLAND_DISPLAY` set (Wayland-native). Both produce PNGs. |
| 2 | Read/interpret screenshot | **Autonomous (mechanical) / HUMAN-advised (true QA)** | Claude Code reads the PNG via its vision model and can confirm "Hyprland running, waybar present, alacritty window open." It CANNOT reliably certify subjective "renders correctly." Keep human sign-off for real visual QA. |
| 2 | Assert via CLI instead of pixels | **Autonomous** | Strongest loop: `hyprctl clients/monitors`, check processes (waybar, alacritty) over SSH — deterministic, no vision needed. Use this as the primary gate, screenshots as corroboration. |
| **3. nixos-anywhere + disko rehearsal** | Run install against the VM | **Autonomous (guarded)** | SSH-native; exactly what an agent handles well. Use `--vm-test` first; pin `--target-host root@<vm-ip>`. |
| 3 | Prevent wrong-target wipe | **Guardrail-critical** | Hook + deny rules: require `--target-host` to match an allowlisted VM IP; block `nixos-anywhere`/`disko`/`--target-host` against anything else; snapshot before run. |
| **4. Real hardware + CI** | Author GitHub Actions (`nix flake check`, toplevel builds) | **Autonomous** | Well within capability; standard CI authorship. |
| 4 | `nixos-rebuild switch` / nixos-anywhere on real ThinkPad/desktop | **HUMAN-ONLY (recommended)** | Bricking risk: a bad rebuild or networking/SSH change can sever the agent's own control channel; rollback needs console/BIOS access the agent lacks. Agent advises; human executes. |
| 4 | Physical boot / BIOS / Secure Boot | **HUMAN-ONLY** | Physical access; no agent path. |

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
- The phase plan and the current phase; "never advance a phase without the gate passing."
- Invariants: "The only valid nixos-anywhere/disko target is `root@<VM_IP>`. Never run against a hostname that is not the test VM." "Never run `nixos-rebuild switch` or touch real hardware — advise only." "Never read or exfiltrate `secrets/`, age/GPG keys, or `~/.ssh/id_*`." "Always `vmrun snapshot` before any destructive VM op; revert on failure."
- Work-state log (mitigates WSL2 OOM context loss) + "commit at every stopping point."
- Note the nixos-generators → `nixos-rebuild build-image` change so the agent doesn't reach for the archived tool.

**4. Subagent split:** a `build-agent` (tools: Bash for nix/git, Read/Edit; no vmrun, no ssh) and a `vm-ops-agent` (tools: Bash for vmrun/ssh; no Edit on the flake). Pros: isolated context, tool-scoped blast radius. Cons: auto-routing is unreliable (invoke explicitly), and Opus over-spawns — so keep it to two, invoked by @-mention.

**5. Isolation & recovery:** run in NixOS-WSL or a devcontainer; git worktrees for isolation; rely on VMware snapshots as the real undo for Phases 1–3.

### Failure-mode register

| # | Failure mode | Severity | Likelihood | Mitigation |
|---|---|---|---|---|
| 1 | `rm -rf` / destructive delete wipes home or repo (documented: #10077 WSL2, LovesWorkin Mac wipe, #49129) | Critical | Medium w/o guards | PreToolUse deny hook; run in NixOS-WSL/container; VMware snapshots; git commits. |
| 2 | nixos-anywhere/disko wipes the WRONG disk/host | Critical | Low-Med | `--target-host` allowlist hook; `--vm-test` first; snapshot precondition; CLAUDE.md invariant. |
| 3 | Bad `nixos-rebuild switch`/network change severs agent's own SSH control channel on real HW | Critical | Medium on HW | Human-only on real hardware; keep console access; test in VM first; generation rollback needs local access. |
| 4 | sops/age key mismatch locks out secrets at boot (host key rotation invalidates encryption) | High | Medium | VM-only test key; re-encrypt on host-key change; agent never holds operator key; `nixos-rebuild test` before switch. |
| 5 | Premature "success" claim / context drift on long task | High | Medium | Prefer deterministic CLI assertions (hyprctl, exit codes) over the model's judgment; self-verify; human gate per phase; Opus 4.8 reduces but doesn't eliminate. |
| 6 | WSL2 OOM-kill kills session, corrupts `--resume` | Medium | Medium | `.wslconfig` memory cap + dropcache; frequent commits; CLAUDE.md state log. |
| 7 | Permission allowlist bypass (compound/quoted commands, argument injection, GTFOBins; CVE-2025-66032) | High | Medium | Enforce via hooks not allowlist; deny-by-default; audit log; keep Claude Code ≥ v1.0.93; don't grant broad `Bash(git*)`/`Bash(nix*)` blindly. |
| 8 | Prompt injection via a malicious flake input / README | High | Low-Med | Opus 4.5 has industry-leading single-attempt robustness (4.7% ASR per Gray Swan, vs Gemini 3 Pro 12.5% / GPT-5.1 21.9%) but this rises to 33.6% at 10 attempts, and Opus 4.6's system card shows GUI-based attacks reaching 78.6% at 200 attempts without safeguards — so pin/review flake inputs and keep least-privilege tools. |
| 9 | Phase 1 first-boot gap silently forces a manual step mid-"unattended" run | Medium | High if stock ISO | Pre-build custom SSH-enabled image; treat as a build prerequisite, not a runtime step. |
| 10 | Phase 2 visual "looks right" false confidence | Medium | Medium | Screenshot loop verifies presence, not correctness; human sign-off for real visual QA. |
| 11 | Broadcom licensing/tooling change to vmrun | Low | Low | Verified current (26H1 / 25H2u1, free for all users incl. commercial since Nov 11, 2024); monitor. |

### Cost/time realism
- **Time is dominated by nix builds and VM installs, not agent thinking.** With background tasks, the agent backgrounds a long `nix build`/install and reads incremental output rather than polling, so it does not burn context idling — but note background tasks end with the session, so a truly overnight run needs tmux/nohup + a resumable design.
- **On a Max plan**, usage is a shared pool across Claude chat + Claude Code + Cowork; there are 5-hour rolling limits (doubled May 6, 2026, peak throttling removed) plus weekly caps (all-models and Sonnet-only). A multi-phase, many-tool-call ops session is Opus-heavy if you let it; the cost-control pattern is plan-with-Opus/execute-with-Sonnet (`/model opusplan`) and route routine steps to Sonnet. Programmatic/headless use (`claude -p`) draws from a separate monthly credit as of June 15, 2026 ($100 on Max 5x, $200 on Max 20x), then stops or bills API rates.
- **On API**, Opus 4.8 is ~$5/$25 per MTok in/out, Sonnet ~$3/$15; a heavily agentic ops session with many tool calls and re-reads can run tens of dollars per phase iteration — the JSON `total_cost_usd` per `-p` invocation is the metric to track, and set `--max-budget-usd`.

## Recommendations

**Stage 1 — Do now (Phase 0, fully autonomous):** Point Claude Code (in NixOS-WSL) at the flake with the `settings.json` + PreToolUse hook + CLAUDE.md above. Add the **mcp-nixos** server to reduce option hallucination. Let it run `nix flake check` and build toplevels autonomously, backgrounding long builds. Benchmark to advance: green `nix flake check` + successful toplevel builds committed.

**Stage 2 — Close the Phase 1 gap before automating it:** Have the agent (or you) build a **custom installer/VM image with `nixos-rebuild build-image`** embedding sshd + the agent's SSH pubkey. This converts "first boot" from human-only to autonomous. (A dynamic-per-VM alternative — a pre-built cloud-init + open-vm-tools image fed SSH keys via VMware `guestinfo.*` in the `.vmx` — works too, but per VMware's own June 2026 guidance it does *not* work against a stock installer ISO, only against a pre-built image that already has the tooling running.) Then let the agent drive `vmrun` (via interop, with `wslpath -w`) to snapshot/boot, and run the SSH-driven install + in-guest sops test-key generation. Benchmark: VM boots SSH-reachable unattended; sops secret decrypts in-guest.

**Stage 3 — Phase 2 with the CLI-first validation loop:** Make deterministic checks (`hyprctl clients/monitors`, process checks over SSH) the primary gate; use `grim`-over-SSH or `vmrun captureScreen` PNGs read by Claude's vision as corroboration. Require a **human visual sign-off** before marking Phase 2 "passed." Benchmark: Hyprland/waybar/alacritty confirmed running by CLI + a human glance at one screenshot.

**Stage 4 — Phase 3 rehearsal, heavily guarded:** Only with the `--target-host` allowlist hook and snapshot-precondition hook active. Run `nixos-anywhere --vm-test` first, then the real install against the pinned VM. Benchmark: clean install to the VM, reboot, SSH back in, secrets present. If the agent ever proposes a target that isn't the VM IP, the hook must block it — that's your go/no-go signal for trusting the setup.

**Stage 5 — Phase 4, agent as author/advisor only:** Let the agent write the GitHub Actions CI (autonomous) and *draft* the hardware deploy runbook. **Do not** let it run `nixos-rebuild switch`/nixos-anywhere against the ThinkPad or desktop unattended. Human executes hardware deploys with console access available. Threshold to revisit: only after many flawless VM rehearsals AND a tested, console-independent rollback path would limited assisted (never unattended) hardware operation be defensible.

**Thresholds that change the recommendation:**
- If a maintained, audited VMware-control MCP with target pinning appears, Phase 1/3 orchestration gets safer (revisit the interop path).
- If Claude Code ships OS-level command sandboxing on WSL2 that is on-by-default and robust, downgrade several Critical risks.
- If the visual loop must certify subjective correctness, it stays human-in-the-loop regardless of model improvements — vision confirms presence, not aesthetic correctness.

## Caveats
- **Vendor/benchmark claims are flagged as such.** The METR ~14.5-hour horizon for Opus 4.6 carries a 6–98 hour confidence interval and comes from a near-saturated task suite; the prompt-injection robustness figures (4.7% single-attempt, rising to 33.6% at 10 attempts and 78.6% for GUI attacks at 200 attempts) and "self-verifies before reporting" are Anthropic/Gray Swan benchmark or system-card claims, not guarantees for this specific messy ops workflow; long-horizon reliability on real ops tasks is materially lower than clean-benchmark numbers.
- **Sources are dated and mixed in authority.** Official Anthropic docs (code.claude.com, claude.com, anthropic.com) are primary; GitHub issues (#10077, #32892, #17084, etc.) and advisories (CVE-2025-66032 / GHSA-xq4m-mc3c-vvg3) are verified primary reports; a substantial fraction of Claude Code "how-to" detail (permission-matcher bugs, background-task limits, cost patterns) comes from practitioner blogs and community kits from 2025–2026, which are consistent with each other but are not official. Where a claim rests only on community sources it is labeled inference.
- **The nixos-generators archival is a real, recent change (Jan 30, 2026)** — plans and older tutorials referencing it should switch to `nixos-rebuild build-image`. This is the kind of drift that will keep happening; re-verify tool status before each phase.
- **This assessment assumes the stated setup** (Claude Code in WSL2, vmrun over interop, SSH to guest). A materially cleaner architecture exists — run Claude Code inside a Linux VM/host with libvirt/QEMU instead of VMware-on-Windows-via-interop — which removes the WSL-interop path-translation and networking fragility entirely; if VMware Workstation is not a hard requirement, consider it.
- **Confidence labels**: tool-alive status (vmrun/26H1, nixos-anywhere, disko, NixOS-WSL, sops-nix) = fact (primary docs/repos, 2026); nixos-generators archived = fact (repo banner, Jan 30 2026); stock ISO has no sshd/password = fact (NixOS manual); Claude Code features (headless, hooks, subagents, vision, background) = fact (official docs); permission-matcher bugs and cost patterns = inference (consistent community reports); the exact autonomy ceiling per phase = inference/estimate.