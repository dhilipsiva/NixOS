# Repository guidance

This repository is the single source of truth at
`/home/dhilipsiva/projects/dhilipsiva/NixOS` on both machines. The installed desktop
has its own host module. The ThinkPad's actual hardware is captured separately.
It preserves its existing encrypted installation; [THINKPAD.md](THINKPAD.md)
records its migration, the child's Roblox/OBS requirements and pending acceptance.

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
  NetworkManager's applet supplies the desktop password agent. Keep Wi-Fi
  credentials in the host's local credential store, outside Git and Nix sources.
- Desktop displays lock/off after 300 seconds; no suspend/hibernate. Laptop
  power policy must be separate. Ollama is socket-started and unloads models
  after requests; physical GPU behavior still requires a runtime check.
- Share software/dotfiles under modules/ and home/. Keep hardware, boot, secrets,
  power policy and stateVersion under each host. Only Zellij retains a raw KDL file.
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

Run `nix flake check .`, `nix build --no-link
.#nixosConfigurations.desktop.config.system.build.toplevel`, and
`scripts/nixosctl check --stable`. Track every referenced source file and repeat
verification in a clean checkout before publishing. `path:$PWD` may be used during
editing to include new files; final Git-flake validation must also pass.

The desktop's 9950X3D now exposes all 16 cores/32 threads with SMT enabled,
verified after the owner's reboot on 2026-10-04 using the same generation 12.
No Nix change was needed to restore CPU availability. Build success cannot
establish physical GPU, display, login, Windows recovery or firmware behavior.
Initial acceptance/cleanup is complete. See DEPLOYMENT.md for the remaining
Wi-Fi persistence and status bar rollout checks. Shared bar configuration is in
home/dhilipsiva/waybar.nix; laptop battery display is explicitly host-enabled.
