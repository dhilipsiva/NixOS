# Session handoff

Current Codex session ID: `01a100bf-09ff-7cd0-83ce-11e37fd90d03`

Repository: `/home/dhilipsiva/projects/dhilipsiva/NixOS`

```bash
cd /home/dhilipsiva/projects/dhilipsiva/NixOS
codex resume 01a100bf-09ff-7cd0-83ce-11e37fd90d03
```

Keep the session history in `~/.codex/sessions`; the ID is not a copy of the
conversation. See the [resume documentation](https://learn.chatgpt.com/docs/developer-commands?surface=cli#codex-resume).

Recorded 2026-10-03. The approved repository implementation includes Hyprland/UWSM,
tuigreet, Alacritty/fish/Atuin/zoxide, ripgrep, the requested development/AI tools,
Slack, Chrome with the official Teams web-app launcher, Lanzaboote, host-checked
Git publication/staging, acceptance-gated timers/GC, unique Home Manager backups,
and removal of obsolete reinstall material. Existing filesystems are preserved.

The GitHub write deploy key at `~/.ssh/nixos-update` has been authorized and a push
dry run succeeded. Private keys remain outside Git. Use `git status --short
--branch` and `git log -1` to inspect the current publication state.

The running installation is still the original system. This implementation has
not staged/activated a generation, changed firmware trust, or run Nix store GC.
The running/booted installation is generation 2; the system profile already
pointed to generation 9 before this work (its link is dated 2026-01-31). The
profile alone does not establish the EFI default. Inspect `sudo bootctl list`
before the first reboot and retain the working generation 2 entry.
The real encrypted login/UPS credentials still need local enrollment. Sudo requires
the owner's password in their terminal. Windows encryption/recovery status remains
unchecked (owner confirmed this during implementation).

Next local step:

```bash
scripts/nixosctl prepare-credentials --host desktop
```

Then follow [DEPLOYMENT.md](DEPLOYMENT.md): verify Windows recovery readiness,
back up/signing preparation, append only the local db certificate while preserving
Microsoft/OEM trust, commit/publish encrypted credentials, `stage --host desktop`,
manual reboot, physical acceptance, then one-time cleanup. Never clear firmware
keys, format a disk, switch the live system, or reboot automatically.

Validation so far: four flake checks pass, covering the Hyprland parser, Ollama VM,
release/channel decisions, real SOPS/age recipient isolation, repeated home-file
backups and two-clone Git failure cases. A temporary ESP rehearsal assembled and
verified a signed UKI from the actual installed kernel/initrd. The actual desktop
board/root/ESP identity checks also pass. The Linux 7.2.9 full desktop build,
including NVIDIA 595.104.02, passed. The full nightly rehearsal fetched official
stable releases, checked/built every configured host, committed only allowed pin
files, published to a temporary remote and synced a second checkout successfully.
Logs: `/tmp/nixos-kernel729-build.log` and `/tmp/nixos-nightly-rehearsal.log`.

After acceptance, desktop updates publish checked revisions around 21:00
Asia/Colombo and stage them for the next manual reboot; the future laptop consumes
them around 21:30. GC runs at 22:00 with 30-day generation retention, retaining the
original recovery closure/boot image/home roots. Store optimisation runs Sundays
at 22:30. Models, project caches, personal files and Windows data are preserved.

Only the desktop host is configured. Capture the ThinkPad's real hardware,
filesystems, boot/encryption details and power needs before adding its host.
The desktop still exposes only eight cores/eight threads; inspect BIOS CCD/SMT
settings separately after establishing a working baseline.
