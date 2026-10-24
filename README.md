# NixOS desktop and shared dotfiles

This flake configures the existing desktop installation and shares software and
Home Manager configuration with the ThinkPad host. It preserves the desktop's
unencrypted ext4 root, 1 GiB EFI partition and systemd-boot with Lanzaboote
signing; there is no partitioning or reinstall configuration.

`hosts/desktop/` holds hardware, filesystems, NVIDIA, display scale, performance,
power and Windows-access settings. `modules/nixos/` is the shared system
configuration and `home/dhilipsiva/` the shared Home Manager profile. The flake
exposes `nixosConfigurations.desktop` and `nixosConfigurations.thinkpad`
(`hosts/thinkpad/`). Desktop operations are in [DEPLOYMENT.md](DEPLOYMENT.md),
the laptop rollout in [THINKPAD.md](THINKPAD.md), and the handoff for a new
session is [SESSION.md](SESSION.md).

The Yoga Slim 7 (`hosts/yoga/`) is the third host. Its owner-installed NixOS
26.05 (unencrypted ext4 root, unsigned systemd-boot, Intel Arc and NPU) was
captured on the laptop on 2026-10-04 and `nixosConfigurations.yoga` is a real
host; [YOGA.md](YOGA.md) records its inventory, the decisions that differ from
the earlier signed plan, its deployment state, the hardware audit and the
physical acceptance checklist. `yoga-policies` and `npu-runtime` pin its policy
and library loading.

## Desktop hardware

| Component | Hardware |
| --- | --- |
| CPU | AMD Ryzen 9 9950X3D, 16 cores / 32 threads |
| Motherboard | MSI MAG X870E TOMAHAWK WIFI, MS-7E59 |
| GPU | NVIDIA RTX 5090 on the open kernel module; AMD integrated GPU also present |
| Display | Samsung Odyssey G81SF over DisplayPort, 3840×2160 at 240 Hz, 10-bit, VRR in fullscreen, compositor scale 1.5 |
| Memory | About 92 GiB visible to Linux |
| Linux SSD | 4 TB XPG MARS 980 BLADE, serial `2P10291S7BAY` |
| Windows SSD | Separate 4 TB SSD, serial `2P102LAC7BA1`, mounted read-only on demand |
| Wi-Fi | Qualcomm WCN7850 (`wlp8s0`) |
| UPS | CyberPower over USB, monitored by NUT |

The kernel is the latest kernel.org stable release (with a pinned patch-release
source bridge when Nixpkgs lags) and the GPU runs NVIDIA's current production
driver, built against that exact kernel. The panel is connected over DisplayPort
(DP-1) since 2026-10-04 and runs 3840×2160 at 240 Hz with 10-bit colour and
adaptive sync in fullscreen; the earlier HDMI FRL workaround (4K60, 8-bit) went
away with the cable, and HDR remains a future test. The compositor addresses only
the NVIDIA card by PCI path. The 700 mm wide panel uses compositor scale 1.5 (2560×1440 logical
pixels), so Wayland applications render at 150 %; X11 clients under Xwayland keep
native pixels and stay sharp but smaller. The text console and the tuigreet login
screen use a 32-pixel Terminus font.

## System layer

- **Boot:** systemd-based initrd, Lanzaboote-signed unified kernel images, boot
  menu editor disabled, five retained generations plus a protected signed
  recovery image (`hosts/desktop/default.nix`, `secure-boot.nix`).
- **Accounts and privileges:** declarative users through userborn with
  `users.mutableUsers = false`; the login hash is installed by sops-nix at
  start-up; `sudo-rs` restricted to the wheel group (`modules/nixos/users.nix`).
- **Nix:** newest stable Nix, flakes only (`nix-channel` disabled, registry and
  `<nixpkgs>` pinned to the flake input), XDG base directories, kept outputs for
  direnv shells, the nix-community binary cache, daily 30-day garbage collection
  and weekly store optimisation (`modules/nixos/nix.nix`).
- **Network:** NetworkManager with systemd-resolved and an nftables firewall with
  no open ports. Wi-Fi credentials stay in NetworkManager's local store.
- **Containers:** rootless Docker in the user session with `DOCKER_HOST` set
  automatically; there is no docker group (`modules/nixos/virtualisation.nix`).
- **Peripherals:** PipeWire audio, Bluetooth with Blueman, OpenTabletDriver and
  LVFS firmware updates through fwupd (listing is automatic, applying is manual).
- **Memory and temp files:** 25 % zstd zram swap with swappiness 180 (zram is
  the only swap), systemd-oomd guarding user slices, in-memory `/tmp`, 30-day
  `/var/tmp` retention, bounded journals. CPU side-channel mitigations stay on.
- **Local AI:** socket-activated Ollama with CUDA that unloads models after each
  request (`modules/nixos/ollama.nix`, host backend in `performance.nix`).
- **ThinkPad differences:** the laptop keeps its LUKS root with the scripted
  initrd, systemd-boot without Secure Boot, suspend on lid close, Intel/NVIDIA
  PRIME offload, Flatpak for Sober (Roblox) and native OBS (`hosts/thinkpad/`).
- **Yoga differences:** the Yoga Slim 7 keeps its owner-installed unencrypted
  ext4 root (the installer's swap partition stays unused via `systemd.swap=0`)
  and unsigned systemd-boot with Secure Boot off, suspends on lid close, runs
  Intel Arc (Lunar Lake) on `xe` with the release-branch media and compute
  runtimes, the Intel NPU stack and Ollama's Vulkan runner on the integrated
  GPU, drives its 2880×1800 panel at 120 Hz with automatic scale 2 and
  fullscreen-only adaptive sync, uses a 24-pixel console font and enables bolt
  for Thunderbolt docks (`hosts/yoga/`).
- **Deferred on purpose:** `system.etc.overlay` (immutable `/etc`). Enabling it
  hides the on-disk `/etc` that holds the SSH host key, machine id and saved
  connections, so it needs an attended migration, not a remote staging.

## Stable releases and updates

NixOS and Home Manager track the latest released stable series, currently
[26.05](https://nixos.org/blog/announcements/2026/nixos-2605/). The desktop's
`system.stateVersion = "25.11"` preserves the installed system's compatibility
settings; it does **not** select software versions. Home Manager starts at
`26.05` because it is new on this installation. Each host keeps its own anchors
([stateVersion explanation](https://wiki.nixos.org/wiki/FAQ/When_do_I_update_stateVersion)).

Selected applications come from a separate `nixpkgs-apps` input that tracks
Nixpkgs master for package definitions only, instantiated once and exposed as
`pkgs.nixpkgs-apps`. Where packaging trails upstream, `pkgs/` supplies
checksum-pinned stable releases. Rust uses rust-overlay's stable channel. The OS
modules and core dependencies stay on the NixOS release branch; a stable OS does
not imply every bundled dependency is the newest upstream release.

The versions in this lock are what `nix eval --json .#lib.stableVersions` prints: the nightly
moves them, so no table here can stay true. The `stable-releases` check refuses any that is a
prerelease or differs from its recorded stable channel.
| Python | 3.14.8 as the separate `python-latest` package |
| Linux kernel | 7.2.9 |
| NVIDIA production driver | 595.104.02 |
| Nix | 2.35.2 (`nixVersions.latest`) |

All machines use the same Git checkout path,
`/home/dhilipsiva/projects/dhilipsiva/NixOS`, tracking `origin/master`, owned by
dhilipsiva. The desktop publishes updates around **21:00 Asia/Colombo** (plus up
to five minutes of jitter): it refreshes release metadata and every flake input in
an isolated worktree, checks and builds every configured host, commits only
release/input files, pushes with its repository-scoped deploy key and stages the
result for the next manual reboot. The ThinkPad (accepted on 2026-10-04, THINKPAD.md) pulls and
stages at about **21:30**. Failed builds, offline services or rejected pushes leave the
previous boot generation in place. Nothing switches live or reboots automatically.
The updater never advances `stateVersion` and refuses prereleases, downgrades and
packages that disagree with the recorded official stable channel.

```bash
scripts/nixosctl status
scripts/nixosctl sync            # clean checkout, fast-forward only
scripts/nixosctl check --stable  # checks + builds all configured hosts
scripts/nixosctl publish         # checks before a normal push
scripts/nixosctl stage --host desktop  # exact published revision, next manual boot
scripts/nixosctl stage --host thinkpad # on the laptop only
```

Store cleanup runs daily at **22:00** (unused paths and generations older than
**30 days**) and deduplication **Sunday at 22:30** at idle priority, both gated on
the accepted first signed boot. Boot entries stay limited to five generations plus
the protected recovery entry. Home directories, project caches, Ollama models,
Windows files and personal documents are never cleanup targets
([CLEANUP.md](CLEANUP.md)).

## Wayland desktop

[Hyprland](https://github.com/hyprwm/Hyprland/releases/tag/v0.56.2) runs under
UWSM, started from the text greeter **greetd + tuigreet**. Home Manager generates
its native Lua configuration (`home/dhilipsiva/wayland.nix`). Waybar, Mako,
Hyprlock, Hypridle (lock and screens off after five minutes, no suspend on the
desktop), Fuzzel, Hyprland's own polkit agent, the Hyprland and GTK portals with
`xdg-open` routed through the portal, a shared Bibata cursor theme and the dark
colour-scheme preference for toolkits complete the session. Animations, shadows,
blur, glow and rounding are disabled; `debug.vfr` stops idle redraws. Xwayland
remains available for X11 applications. NetworkManager's applet supplies the
Wi-Fi password agent and a tray menu.

| Shortcut | Action |
| --- | --- |
| Super+Enter | Terminal |
| Super+D | Fuzzel application launcher |
| Super+1…0 / Super+Shift+1…0 | Switch workspace / move window |
| Super+H/J/K/L | Focus left/down/up/right |
| Super+Ctrl+L | Lock |
| Super+Alt+L | Ask Lucy (desktop, ThinkPad and Yoga; opening does not start inference) |
| Super+F / Super+Shift+Space | Fullscreen / floating window |
| Super+V | Toggle split direction |
| Super+Shift+Q / Super+Shift+E | Close window / log out |
| Super+Shift+Z | Zed |
| Super+Shift+F | Dolphin file manager |
| Print | Select a region and copy its screenshot |

The bottom bar (`home/dhilipsiva/waybar.nix`) shows five persistent workspaces,
the window title, a clock with calendar, CPU/RAM/SSD, network, audio, a failed
service warning, the tray and a lock button. The ThinkPad host enables the laptop battery module
with `home-manager.users.dhilipsiva.repo.waybar.battery.enable`.

| Bar control | Action |
| --- | --- |
| Apps | Open Fuzzel |
| Workspace number | Switch workspace |
| CPU / RAM | Open btop in Alacritty |
| SSD | Open Dolphin; hover for available root-filesystem space |
| Network | Open saved connections; hover for SSID, address and signal |
| Volume | Open audio settings; right-click to mute; scroll to adjust |
| Clock | Hover for calendar; scroll through months |
| Service warning | Open failed system/user service details |
| Lock | Lock the screen |

Alacritty starts **fish** with the starship prompt, **Atuin** history, **zoxide**
(`z`), **direnv** with nix-direnv, and nix-index: an unknown command names the
package that provides it and `, <command>` runs one without installing it. **Zellij** uses upstream keybindings, opens
fish in new panes and does not auto-start. **Helix** carries its JS/TS/JSON
language servers. Applications and toolchains (Zed, VS Code, Cursor, Codex,
Claude Code, Herdr, Python, Node, Rust, uv, Slack, Chrome, Firefox, Dolphin,
Discord, Lutris/Wine, build tools) live in the user's Home Manager profile
(`home/dhilipsiva/packages.nix`); the system profile holds shared essentials
only. The Microsoft Teams launcher opens the official web app in a Chrome
Wayland app window. Account authentication for every tool remains user-managed.

## On-demand Ollama

Clients use the normal local endpoint `http://127.0.0.1:11434`. A socket listener
starts the backend on the first connection; the backend does not start at boot
and stops after the proxy has had no connections for five minutes.
`OLLAMA_KEEP_ALIVE=0` unloads a model after each request, releasing its VRAM
(requests may override `keep_alive`). The desktop uses CUDA, one loaded model and
one parallel request, and reserves 2 GiB of GPU headroom. Models are downloaded
explicitly with `ollama pull`; inspect with `ollama ps` and
`systemctl status ollama-proxy.socket ollama-proxy.service ollama.service`.

## Lucy on demand (desktop, ThinkPad and Yoga)

`lucy ui`, **Ask Lucy** in Fuzzel, and **Super+Alt+L** open a native GTK chat.
Sending in that named chat or `lucy chat` invokes Lucy. Other apps require a
leading address such as `Lucy, …`, `Hey Lucy`, `@lucy`, `/lucy`, or their named
Lucy action. Ordinary prompts, quoted text and subject mentions such as
“Lucy said” do not activate her. Activation belongs to one conversation;
`Lucy, sleep`, closing it, signing out or restarting the service ends it.
**Stop** cancels the current task and pending approvals.

The reusable implementation is a revision-pinned Nibli input. The package builds
the Rust service, CLI and GTK4 window with Nibli's `desktop-ui` feature, including
their runtime libraries and GTK resources. The user service stores complete invoked
messages privately under `~/.local/share/lucy` and uses a rebuildable text index
for bounded recall. Private conversation data never belongs in this checkout or
the Nix store. Existing public peer commands remain explicit. Invoked cloud apps
receive relevant private excerpts, as selected; their models and permission
controls remain theirs.

Local chat uses a pinned Ollama model with its manifest digest and 16K context.
The desktop keeps Nibli's pin, Qwen3.6 35B-A3B Q4_K_M, which peaks near 25 GiB
on the RTX 5090. The Yoga's integrated Arc 140V shares a 23 GiB Vulkan heap with
32 GiB of RAM, so `hosts/yoga/default.nix` pins Qwen3.5 9B Q4_K_M (about 6 GiB,
the same qwen3.5 tool-call format) through `repo.lucy.model`. The ThinkPad's RTX
3070 Laptop GPU has 8 GiB with 2 GiB reserved as overhead, so
`hosts/thinkpad/default.nix` takes the same pin and digest; the weights and the
16K context exceed the remaining 6 GiB, so its CUDA runner may keep part of the
layers in RAM. The package wrapper sets the Rust runtime's `LUCY_CHAT_MODEL`,
`LUCY_CHAT_DIGEST` and `LUCY_CHAT_CONTEXT` for each host. The `lucy-yoga-model`
and `lucy-thinkpad-model` checks exercise those settings against an isolated HTTP
fixture, including refusal of a mismatched manifest. `lucy setup-model`
explicitly downloads and verifies the host's model. Inference does not download
missing weights or fall back to a cloud model. Ollama on all three hosts has cloud
features disabled, one model/request at a time and unloading after requests; the
desktop and the ThinkPad keep 2 GiB of GPU headroom. Build success does not
establish physical GPU fit.

The native executor records predictions and outcomes in the shared private store;
`lucy self-model status` and `lucy self-model audit` inspect that history and its
evidence checks. The package checks execute a native file read, audit the recorded
outcome and verify persistence across a service restart. External agents use
explicit reported observations; they do not inherit the native executor's loop.
Updating this feature requires advancing the Nibli source pin and rebuilding the
package. Pulling a sibling checkout does not change the installed service.

At the first graphical login after staging, `lucy-adapters.service` enrolls
adapters with additive settings merges and backups. Conflicting existing files
are left for a manual merge. It does not approve app trust or change credentials.
`lucy integrations install` retries enrollment; `lucy integrations status` prints
the inventory generated from all user/system packages and desktop entries,
including each adapter's recording limitations. All three hosts enable this
service and its input helper.

| Interface | Invocation and recording |
| --- | --- |
| Claude Code / Codex | Prompt hooks supply memory; response hooks save final messages. Commentary requires explicit recording. Codex must trust the hooks in its own UI. |
| Cursor | Prompt/response hooks; manually invoke `/lucy` to retrieve context because its submission hook cannot inject it. |
| VS Code | Sticky `@lucy` participant uses the selected model; automatic participant detection is absent. |
| Zed | Manual `/lucy` skill with autonomous invocation disabled. Responses and sleep require explicit commands because a reliable close/response hook is unavailable. |
| Chrome / Firefox | Explicit selected-text/page handoff and memory-context preparation. Load the browser extension from the installed package's `share/lucy/browser-extension`; persistent Firefox installation requires signing. Web-chat transcripts require explicit import. |
| Dolphin | “Ask Lucy about these files” service menu. |
| Alacritty / Zellij / Helix | `lucy chat`, `lucy ui --files FILE…`, or explicit JSON handoff on stdin. |
| Slack / Discord / Teams / Bruno / Arduino / Lutris / other utilities | Desktop shortcut and explicit task context; no background scraping or input monitoring. |

`lucy memory recall --source APP --session ID --text TOPIC` and session-bound
`lucy mcp --source APP --session ID` require an activated conversation. Complete
messages can be imported explicitly with `lucy archive import < messages.json`;
`lucy archive reindex` rebuilds search. See the packaged Nibli runtime README for
the record schema and adapter contracts. Sources without stable event IDs cannot
reliably distinguish duplicate deliveries from intentionally repeated prompts.

File tools operate in the chosen workspace. Edits show a diff; commands run in an
offline workspace sandbox after approval. App launches, window changes,
screenshots and GUI input also show pending actions. Privileged diagnostics and
the short-lived input helper additionally authenticate through polkit. GUI work
stops when cancellation or a locked session is detected; coordinate scaling and
physical mouse/keyboard behavior require attended acceptance after staging.

## Copying files from Windows

The Windows NTFS data partition is mounted on demand, read-only, at
`/mnt/windows` (Super+D, **Windows files**, or Dolphin with Ctrl+L). For a
resumable directory copy:

```bash
rsync -rt --info=progress2 /mnt/windows/Users/<windows-user>/Documents/ ~/Documents/
```

The mount uses the filesystem UUID, never touches the Windows EFI partition or
boot files. To start Windows, run `reboot-to-windows` or pick **Reboot to
Windows** in Fuzzel: it sets the firmware's one-shot BootNext to the Windows
Boot Manager entry (polkit prompt) and reboots; the permanent boot order stays on
NixOS, so the next restart from Windows returns here. If NTFS refuses to
mount after hibernation, fully shut Windows down first; never force a write mount.

On the desktop login screen, **F11 Reboot to Windows** opens the power menu
with **Reboot to Windows** selected. Press **Enter** to reboot, or **Esc** to
cancel. The same action is available under **F12 Power** alongside normal reboot
and shutdown. It works before login without a password; permission is limited to
the active local greeter running this fixed helper. The laptop greeters are
unchanged. `reboot-to-windows --help` displays command usage without rebooting.

## Build and deployment

```bash
nix fmt                          # nixfmt over the whole tree (treefmt wrapper)
nix flake check .                # formatting + ruff, Hyprland Lua, Zellij KDL, Ollama VM,
                                 # stable releases, encrypted-file structure, Git workflow
nix build --no-link .#nixosConfigurations.desktop.config.system.build.toplevel
scripts/nixosctl check --stable
```

`nix develop` provides the script, secret and lint tooling. The `formatting`
check rejects unformatted Nix, unused bindings (deadnix) and ruff findings in the
Python helpers. The `desktop-login` check boots the real desktop configuration in
QEMU with build-time fixture secrets, logs in on a console through sops-nix and
userborn, and starts the Hyprland session with Waybar and the polkit agent; only
the GPU device and the UPS are overridden. Full builds compile the NVIDIA module
for the selected kernel. GitHub Actions (`.github/workflows/check.yml`) evaluates
every output and runs the light checks on each push, so a broken desktop is never
the only validator; VM tests, the Hyprland parser and `nixosctl check --stable`
stay local. Checks still do not establish physical GPU or firmware behavior.
`nixosctl stage` prints an nvd closure diff against the running system before it
installs boot entries. During editing,
`path:$PWD` includes untracked files; final validation uses a clean Git checkout
with every required file tracked.

A headless rehearsal of the desktop configuration boots in QEMU:

```bash
nix build --out-link /tmp/desktop-vm .#nixosConfigurations.desktop.config.system.build.vm
QEMU_OPTS="-m 4096 -smp 4" /tmp/desktop-vm/bin/run-dhilipsiva-desktop-vm
ssh -p 2222 root@localhost      # password: test (VM only)
```

Add `-fw_cfg name=opt/vmhostkey,file=<throwaway ed25519 key>` to `QEMU_OPTS` to
exercise the sops path with `secrets/vm-test.yaml`; without it the VM boots in
break-glass mode (root works, dhilipsiva has no password). DEPLOYMENT.md explains
how to regenerate that fixture, since the previous throwaway key is gone.

Each machine stages only its own host: `--host desktop` on the desktop,
`--host thinkpad` on the ThinkPad and `--host yoga` on the Yoga. The checks build
every host everywhere.
The manifest declares each host's required user Flatpaks, and requires NVIDIA
Flatpak runtime matching only where the host actually uses NVIDIA.

## ThinkPad migration

The ThinkPad T15g Gen 2i already has NixOS installed. Its host configuration
preserves the actual LUKS root, ext4 filesystem, 511 MiB ESP and systemd-boot with
Secure Boot disabled, and adds Intel/NVIDIA PRIME offload, a lid-suspend power
policy, Flatpak for Sober (Roblox) and native OBS. It inherits every shared
module, so the desktop's modernisation (userborn, sudo-rs, nftables with
systemd-resolved, rootless Docker, Bluetooth, fwupd, tmpfs `/tmp`, the Home
Manager application profile and Zellij module) applies there too; compositor
scale and console font remain host settings. Follow [THINKPAD.md](THINKPAD.md)
for its rollout, physical checks and recovery. Never copy desktop UUIDs, signing
private keys, SSH host keys or the no-sleep policy onto it.

## Licence

MIT OR Apache-2.0, at your option: [LICENSE-MIT](LICENSE-MIT) and
[LICENSE-APACHE](LICENSE-APACHE). The packages under `pkgs/` keep their upstream licences in
their `meta.license`.
