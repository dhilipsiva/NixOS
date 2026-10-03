# Repository guidance

This repository is the single source of truth at
`/home/dhilipsiva/projects/dhilipsiva/NixOS` on both machines. The installed desktop
has its own host module. Add the ThinkPad only after capturing its actual hardware.

- Latest released stable NixOS and matching Home Manager, with stable application
  channels recorded in `pkgs/stable-channels.json`. Applications from nixpkgs-apps
  are packages only; never import its NixOS modules. No beta/RC/nightly versions.
- `stateVersion` records installation compatibility, not the software release.
  Keep each host's anchors unless a documented data migration requires a change.
- Official proprietary firmware/userspace are acceptable. RTX 5090 uses NVIDIA's
  open kernel modules and the production driver built for the selected kernel.
- Preserve the existing ext4 root and 1 GiB Linux ESP. No disko, reinstall or
  changes to the Windows disk. Windows data is mounted read-only for copying.
- Hyprland with UWSM, greetd/tuigreet, Fuzzel, Alacritty, fish, Atuin and zoxide.
  Keep native Hyprland Lua, matching portals and Xwayland compatibility.
- Desktop displays lock/off after 300 seconds; no suspend/hibernate. Laptop
  power policy must be separate. Ollama is socket-started and unloads models
  after requests; physical GPU behavior still requires a runtime check.
- Share software/dotfiles under modules/ and home/. Keep hardware, boot, secrets,
  power policy and stateVersion under each host. Only Zellij retains a raw KDL file.
- Use `scripts/nixosctl sync`, `check`, `publish`, `stage --host desktop`, `status`.
  Sync is fast-forward-only. Never stash, discard, merge or force-push automatically.
- Desktop publishes checked stable updates at about 21:00 Asia/Colombo. Future
  subscribers pull/stage at about 21:30. All Git work runs as the checkout owner.
  Never stage an unpublished or failed candidate. Never switch/reboot automatically.
- Preserve the acceptance gate, common stage/GC lock, 30-day GC policy, explicit
  recovery GC roots, signed recovery image, and unique Home Manager backups.
- Private SSH/age/firmware keys, password hashes and plaintext secrets never go
  into Git, the store, process arguments or logs. Helpers encrypt locally from
  memory. The real host must decrypt its secrets before staging. VM keys stay
  isolated from host ciphertext. Never auto-enroll Secure Boot keys or clear trust.
- Codex/cloud-agent credentials are independent of Ollama. Do not introduce a
  global OPENAI_BASE_URL/API_KEY override or point XDG_CONFIG_HOME at this repo.

Run `nix flake check .`, `nix build --no-link
.#nixosConfigurations.desktop.config.system.build.toplevel`, and
`scripts/nixosctl check --stable`. Track every referenced source file and repeat
verification in a clean checkout before publishing. `path:$PWD` may be used during
editing to include new files; final Git-flake validation must also pass.

The desktop currently exposes only 8 cores/8 threads despite identifying as a
9950X3D. Inspect BIOS CCD/core/SMT settings separately; do not claim software
restored hidden cores. Build success cannot establish physical GPU, display,
login, Windows recovery or firmware behavior. See DEPLOYMENT.md for acceptance.
