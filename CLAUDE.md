# Repository guidance

This repository is the single source of truth at
`/home/dhilipsiva/projects/dhilipsiva/NixOS` on every machine. The installed desktop
has its own host module. The ThinkPad's actual hardware is captured in
`hosts/thinkpad/`; it preserves its existing encrypted installation, and
[THINKPAD.md](THINKPAD.md) records its migration, the child's Roblox/OBS
requirements and pending acceptance.

The Yoga Slim 7's owner-installed NixOS 26.05 is captured in `hosts/yoga/`
(`hardware-configuration.nix` and `installation.nix` were generated and read on
the laptop on 2026-10-04); [YOGA.md](YOGA.md) records its inventory, the
remaining enrollment and staging steps and the acceptance checklist. It
preserves the unencrypted ext4 root, the 1 GiB ESP and unsigned systemd-boot
with Secure Boot disabled; the installer's swap partition stays on disk unused
(`systemd.swap=0`). Never repartition, encrypt or enable Secure Boot on it
without an attended, documented migration. No fixture is a deployable host.

- Latest released stable NixOS and matching Home Manager, with stable application
  channels recorded in `pkgs/stable-channels.json`. Applications from nixpkgs-apps
  are packages only (exposed as `pkgs.nixpkgs-apps`); never import its NixOS
  modules. No beta/RC/nightly versions.
- `stateVersion` records installation compatibility, not the software release.
  Keep each host's anchors unless a documented data migration requires a change.
- Official proprietary firmware/userspace are acceptable. RTX 5090 uses NVIDIA's
  open kernel modules and the production driver built for the selected kernel.
- Preserve the existing ext4 root and 1 GiB Linux ESP. No partitioning tool,
  reinstall or changes to the Windows disk. Windows data is mounted read-only.
- Hyprland with UWSM, greetd/tuigreet, Fuzzel, Alacritty, fish, Atuin and zoxide.
  Keep native Hyprland Lua, matching portals and Xwayland compatibility. Monitor
  scale and console font are host settings (the desktop uses 1.5 and Terminus).
  NetworkManager's applet supplies the desktop password agent. Keep Wi-Fi
  credentials in the host's local credential store, outside Git and Nix sources.
- Desktop displays lock/off after 300 seconds; no suspend/hibernate. Laptop
  power policy must be separate. Ollama is socket-started and unloads models
  after requests; physical GPU behavior still requires a runtime check.
- Share software/dotfiles under modules/ and home/. Keep hardware, boot, secrets,
  power policy and stateVersion under each host. Applications belong in
  `home/dhilipsiva/packages.nix`; the system profile holds shared essentials.
- Prefer existing NixOS/Home Manager modules and structured options over raw
  strings or hand-written units. Current choices: systemd initrd, userborn with
  sops-nix systemd activation, sudo-rs, nftables + systemd-resolved, rootless
  Docker (no docker group), `nix.channel` disabled, `nixVersions.latest`,
  hyprpolkitagent, Zellij via its module. `system.etc.overlay` is deferred: it
  needs an attended `/etc` migration (host key, machine id, connections).
- Use `scripts/nixosctl sync`, `check`, `publish`, `stage --host desktop`, `status`.
  Sync is fast-forward-only. Never stash, discard, merge or force-push automatically.
- Desktop publishes checked stable updates at about 21:00 Asia/Colombo. The
  ThinkPad subscribes at about 21:30 after acceptance. Git runs as the checkout owner.
  Never stage an unpublished or failed candidate. Never switch/reboot automatically.
- Preserve the acceptance gate, common stage/GC lock, 30-day GC policy, explicit
  recovery GC roots, signed recovery image, and unique Home Manager backups.
- Private SSH/age/firmware keys, password hashes and plaintext secrets never go
  into Git, the store, process arguments or logs. Helpers encrypt locally from
  memory. The real host must decrypt its secrets before staging. VM keys stay
  isolated from host ciphertext. Never auto-enroll Secure Boot keys or clear trust.
- Codex/cloud-agent credentials are independent of Ollama. Do not introduce a
  global OPENAI_BASE_URL/API_KEY override or point XDG_CONFIG_HOME at this repo.

Run `nix fmt`, `nix flake check .`, `nix build --no-link
.#nixosConfigurations.desktop.config.system.build.toplevel`, and
`scripts/nixosctl check --stable`. The `formatting` check enforces nixfmt,
deadnix and ruff; `desktop-login` boots the desktop configuration in QEMU through
the real sops/userborn login path; GitHub Actions repeats evaluation and the light
checks off-machine. Track every referenced source file and repeat verification in
a clean checkout before publishing. `path:$PWD` may be used during editing to
include new files; final Git-flake validation must also pass.

Build success cannot establish physical GPU, display, login, Windows recovery or
firmware behavior. Compare `/run/current-system` with the HEAD build before
trusting any state note. See DEPLOYMENT.md for the staged modernisation's
post-boot checks, the Wi-Fi persistence step and the VM fixture restoration.
