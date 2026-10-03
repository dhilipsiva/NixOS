# NixOS desktop and shared dotfiles

This flake configures the existing desktop installation and shares software and
Home Manager configuration with a future ThinkPad host. It preserves the desktop's
unencrypted ext4 root, 1 GiB EFI partition, and systemd-boot with Lanzaboote signing. There is no active
partitioning or reinstall configuration.

`hosts/desktop/` contains hardware, filesystems, NVIDIA, performance, power, and
Windows access settings. `modules/nixos/` contains shared system configuration;
`home/dhilipsiva/` contains shared dotfiles. Only `nixosConfigurations.desktop`
exists today. Operational procedures are in [DEPLOYMENT.md](DEPLOYMENT.md).

## Desktop hardware and tuning

Detected on 2026-10-03:

| Component | Hardware |
| --- | --- |
| CPU | AMD Ryzen 9 9950X3D |
| Motherboard | MSI MAG X870E TOMAHAWK WIFI, MS-7E59 |
| GPU | NVIDIA RTX 5090; AMD integrated GPU also present |
| Display | Samsung Odyssey G81SF, connected to the RTX 5090 over HDMI |
| Memory | About 92 GiB visible to Linux |
| Linux SSD | 4 TB XPG MARS 980 BLADE, serial `2P10291S7BAY` |
| Windows SSD | Separate 4 TB SSD, serial `2P102LAC7BA1` |

The desktop uses the latest kernel.org stable kernel (with a pinned patch-release
source bridge when Nixpkgs lags)
and NVIDIA's current production driver with open kernel modules. The driver package
comes from the separately pinned package input and is built against the host's
exact kernel. NVIDIA's proprietary userspace/CUDA and vendor firmware are allowed;
Blackwell requires the official open kernel module. Development tuning adds
AMD P-State performance policy, 25% zstd zram, periodic SSD TRIM, larger file-watcher
limits, and two concurrent Nix builds with all visible cores available to each.
The Nix daemon has reduced CPU/I/O scheduling weight to help interactive work.
These are workload choices, not measured benchmark improvements.

**Temporary HDMI compatibility setting:** generation 10 lost its display when
NVIDIA took over the framebuffer and logged an HDMI FRL link-training failure,
although blind login started Hyprland. `hosts/desktop/graphics.nix` now disables
HDMI FRL and deep colour and pins the NVIDIA HDMI-A-1 console/session to 4K60,
8-bit SDR. Both module parameters are present in the selected
[NVIDIA driver source](https://github.com/NVIDIA/open-gpu-kernel-modules/blob/595.104.02/kernel-open/nvidia-modeset/nvidia-modeset-linux.c).
This deliberately limits refresh/HDR while establishing a working display;
the retry and physical validation are still pending. Retest higher display modes
over a working HDMI or DisplayPort link before removing the workaround. It is
desktop-only and does not change the GPU's compute configuration.

**Firmware needs attention:** Linux currently sees only 8 cores / 8 threads on this
9950X3D, with SMT reported unavailable. Check BIOS settings for enabled CCDs/cores
and SMT; disable MSI X3D Gaming Mode if it is enabled. That is a likely explanation,
not a confirmed BIOS diagnosis. [MSI documents that mode's core/SMT changes](https://us.msi.com/blog/how-to-boost-amd-ryzen-9-9950x3d-gaming-performance).
No firmware settings or overclocking were changed by this configuration.

The desktop never suspends or hibernates. After five minutes of inactivity, Hypridle
locks the session and powers off the displays; keyboard/mouse activity powers them
back on. Builds and inference continue. This policy is in
`hosts/desktop/power.nix` and does not apply to the ThinkPad.

## Stable releases and updates

NixOS and Home Manager track the latest released stable series, currently
[26.05](https://nixos.org/blog/announcements/2026/nixos-2605/). The desktop's
`system.stateVersion = "25.11"` preserves the installed system's compatibility
settings; it does **not** select the OS or package versions. Home Manager starts at
`26.05` because it is new on this installation. Each host keeps its own anchors.
See the [stateVersion explanation](https://wiki.nixos.org/wiki/FAQ/When_do_I_update_stateVersion).

Requested applications/toolchains are checked against upstream stable releases.
Selected packages come from the separate `nixpkgs-apps` input, which tracks Nixpkgs
master solely for package definitions. Where packaging still trails upstream,
`pkgs/` supplies checksum-pinned stable releases. Rust uses rust-overlay's stable
channel. The OS modules and core dependencies stay on the NixOS release branch.
A stable OS does not imply every bundled dependency is the newest upstream release.

Verified versions in this lock on 2026-10-03:

| Tool | Version |
| --- | --- |
| Hyprland | 0.56.2 |
| Fuzzel | 1.15.0 |
| tuigreet | 0.11.1 |
| Alacritty | 0.17.0 |
| fish | 4.9.3 |
| Helix | 25.07.1 |
| Codex | 0.160.0 |
| Claude Code | 2.1.285, upstream **stable** channel |
| Atuin | 18.23.0 |
| Ollama | 0.35.1 |
| Zed | 1.22.0 |
| Herdr | 0.9.3 |
| zoxide / ripgrep | 0.10.0 / 15.2.0 |
| uv | 0.12.22 |
| Slack | 4.52.171, official Linux channel |
| Google Chrome / Teams web app | 154.0.8037.97 / official Teams site |
| Lanzaboote | 1.2.0 |
| Rust | 1.99.0, with Cargo, Clippy, rustfmt, rust-analyzer, and sources |
| Python | 3.14.8; Python 3.15 is still a prerelease |
| Linux kernel | 7.2.9 |
| NVIDIA production driver | 595.104.02 |

The development Python is a separate `python-latest` package, so updating it does
not replace Python underneath all system services. Use `uv` for project virtual
environments and dependencies. The Rust toolchain is declarative; legacy rustup
shims in `~/.cargo/bin` are not prepended by this repo.

Both machines use the same Git checkout path:
`/home/dhilipsiva/projects/dhilipsiva/NixOS`, tracking `origin/master`. The checkout
is owned by dhilipsiva. Each machine keeps its own private identities outside Git.

After first-boot acceptance, the desktop publishes updates around **21:00
Asia/Colombo**, with up to five minutes of jitter. The future ThinkPad subscriber
pulls/stages at about **21:30**. Persistent systemd timers catch missed runs.
The desktop starts from the published revision in an isolated worktree, refreshes
stable release metadata and every flake input, checks/builds every configured host,
commits only release/input files, and pushes normally. Only a successfully published,
verified revision is eligible for staging. Failed builds, offline services or rejected
pushes leave the previous boot generation in place. No automatic reboot/live switch.

The updater advances NixOS and Home Manager together from official released
installer evidence, retains the newest stable Lanzaboote tag, refreshes direct
binary/source hashes and Claude's stable manifest, and records official stable
channel metadata for selected applications/toolchains, kernel and NVIDIA driver. Numeric versions alone
are not considered evidence of current stable status. Every selected tool must
match that metadata. If upstream packaging or APIs lag/change, the job stops for
a repository fix; it never silently substitutes an older or prerelease package.
Core OS dependencies follow the stable NixOS branch, which does not guarantee
newest-upstream versions for every transitive library.

From either machine:

```bash
scripts/nixosctl status
scripts/nixosctl sync            # clean checkout, fast-forward only
scripts/nixosctl check --stable  # checks + builds all configured hosts
# After making and committing changes:
scripts/nixosctl publish         # checks before a normal push
scripts/nixosctl stage --host desktop  # exact published revision, next manual boot
```

Use `--host thinkpad` only after its hardware configuration has been added. Sync
never stashes, discards local changes, merges or resolves divergence automatically.
The desktop's publisher uses its enrolled repository-scoped SSH deploy key;
the completed setup is recorded in SESSION.md. Git never runs as root. The stage receipt records
the exact Git revision and store path under `/var/lib/nixos-deployment/staged.json`.

```bash
systemctl list-timers nixos-update nix-gc nix-optimise
journalctl -u nixos-update.service -n 100
sudo cat /var/lib/nixos-deployment/staged.json
```

For a manual release refresh, run `python3 scripts/update-stable-releases.py .`,
`nix flake update`, and `scripts/nixosctl check --stable`; review/commit the pin
changes and publish normally. `stateVersion` is never advanced by the updater.

After first-boot acceptance, store cleanup runs daily at **22:00**, deleting unused paths and profile
generations older than **30 days**. Store deduplication runs **Sunday at 22:30**
at idle priority. Regular boot entries remain limited to five generations plus a protected signed recovery entry for the
1 GiB ESP; 30-day profile retention does not imply 30 boot-menu entries. Journals
are bounded to 1 GiB/30 days, and systemd's normal temporary-file cleanup ages
`/tmp` at 14 days and `/var/tmp` at 30 days. Home directories, project caches,
Ollama models, Windows files, and personal documents are not cleanup targets.

## Wayland desktop and useful tools

[Hyprland](https://github.com/hyprwm/Hyprland/releases/tag/v0.56.2) provides a tiling
Wayland session with familiar Super-based shortcuts, Waybar, Mako, Hyprlock,
Alacritty, PipeWire, and the matching Hyprland screen-sharing portal. Xwayland
remains available for applications that need it. Home Manager generates the current
Lua configuration format in `hypr/hyprland.lua`; old raw dotfiles are not loaded.

Login uses the text-based **greetd + tuigreet** screen, which starts Hyprland through
UWSM for session/service lifecycle management. **Fuzzel** provides a native Wayland
application launcher on Super+D. **Alacritty** explicitly starts **fish**, with
**Atuin** integrated into its interactive history and **zoxide** available as `z` for directory jumps. These changes take effect after
a deliberate system activation/reboot, not merely by editing the repo.

Shared configuration lives in `home/dhilipsiva/wayland.nix`; NVIDIA and idle policy
are host-specific. Fish uses built-in and packaged vendor completions. The 26.05
manpage-completion generator is disabled because it expects a Python helper that
fish 4.9 removed.

| Shortcut | Action |
| --- | --- |
| Super+Enter | Terminal |
| Super+D | Fuzzel application launcher |
| Super+1…0 / Super+Shift+1…0 | Switch workspace / move window |
| Super+H/J/K/L | Focus left/down/up/right |
| Super+Ctrl+L | Lock |
| Super+F / Super+Shift+Space | Fullscreen / floating window |
| Super+V | Toggle split direction |
| Super+Shift+Q / Super+Shift+E | Close window / log out |
| Super+Shift+Z | Zed |
| Super+Shift+F | Dolphin file manager |
| Print | Select a region and copy its screenshot |

Useful included tools: `btop` for CPU/RAM/processes, `nvtop` for GPU/VRAM,
`lazygit` for terminal Git work, `uv` for Python, `rg` for fast text searches,
`z` for directory jumps, `rsync` for file copies, and
`direnv` with `nix-direnv` for project environments. Direnv requires `direnv allow`
per project. Herdr, Codex, Claude Code, Helix, Zed, Atuin, and Zellij are installed
declaratively; account authentication remains user-managed. Slack uses the official
Linux download. The Microsoft Teams launcher opens the official Teams web app in
a stable Chrome Wayland app window; sign-in and camera/microphone/screen-sharing
permissions remain interactive.

## On-demand Ollama

Clients use the normal local endpoint `http://127.0.0.1:11434`. A socket listener
starts the backend on the first connection. The backend does not start at boot,
and stops after the proxy has had no connections for five minutes.

`OLLAMA_KEEP_ALIVE=0` unloads a model after each request by default, releasing its
VRAM. Requests can explicitly override `keep_alive`; persistent client connections
can also keep the backend process alive. This favors idle GPU availability over
warm-model response latency. Hyprland/Zed still use the GPU for display rendering.
See [Ollama's keep-alive behavior](https://docs.ollama.com/faq).

The desktop uses CUDA, limits loaded models and parallel requests to one, and
reserves 2 GiB of GPU headroom. Shared service wiring is independent of the
desktop's NVIDIA settings; each host can select its backend. Models are downloaded
explicitly:

```bash
ollama pull <model-name>
ollama run <model-name>
ollama ps
systemctl status ollama-proxy.socket ollama-proxy.service ollama.service
```

## Copying files from Windows

The Windows NTFS data partition is mounted on demand, read-only, at `/mnt/windows`.
Use Super+D and search for **Windows files**, or open Dolphin with Super+Shift+F,
press Ctrl+L, and enter that path. Copy files to
your Linux home normally. For a resumable directory copy:

```bash
rsync -rt --info=progress2 /mnt/windows/Users/<windows-user>/Documents/ ~/Documents/
```

The mount uses the detected filesystem UUID, not NVMe enumeration order. It does
not mount the Windows EFI partition or alter Windows boot files. Use the firmware
boot menu to start Windows on its separate SSD. If NTFS refuses to mount after
hibernation, fully shut Windows down before retrying; do not force a write mount.

## Build and deployment

`nix-command` and `flakes` are enabled system-wide. The nixpkgs registry and legacy
Nix search path point to this flake's stable input. No repeated
`--extra-experimental-features` is needed. Before first activation, this desktop's
user Nix config already enables these features.

```bash
nix flake check .
nix build --no-link .#nixosConfigurations.desktop.config.system.build.toplevel
scripts/nixosctl check --stable
```

Flake checks cover Hyprland's native Lua parser, the Ollama lifecycle VM, stable
release decisions, encrypted-file structure/recipient isolation, and Git workflow
failures with two temporary clones. Full builds compile the NVIDIA module for the
selected kernel. These checks do not establish physical GPU, login or firmware
behavior. During editing, `path:$PWD` includes untracked files; final validation
must use a clean Git checkout with every required file tracked.

Follow [DEPLOYMENT.md](DEPLOYMENT.md) to stage the HDMI compatibility change,
reboot manually and complete physical validation before acceptance. Generation 10
failed display validation; the desktop is back on generation 2. Firmware preparation
and the boot evidence are recorded in [SESSION.md](SESSION.md).
The desktop's encrypted credentials are enrolled with the owner and
actual host identities. Staging still verifies decryption and that the preserved
password matches the installed account. Each new host needs its own enrollment.
Cleanup policy is in [CLEANUP.md](CLEANUP.md). Session resumption is in
[SESSION.md](SESSION.md).

## Adding the ThinkPad

Clone this repository into exactly the same path and own it as dhilipsiva. Capture
`nixos-generate-config --show-hardware-config`, DMI board identity, disks/mounts,
GPU/Wi-Fi, battery and existing boot/Secure Boot/encryption details on the laptop.
Add `hosts/thinkpad/` and expose it through `mkHost` in `flake.nix`. Import the
shared modules/home configuration; keep its own hardware UUIDs, boot policy,
secrets file, stateVersion anchors and laptop suspend/battery behavior.

Set `repo.maintenance.enable = true`, `host = "thinkpad"`, `role = "subscriber"`
and the observed `boardName`. Add a separate `# BEGIN thinkpad`/`# END thinkpad`
creation-rule block in `.sops.yaml` and its encrypted `secrets/thinkpad.yaml`; enroll
its own host identity and the owner identity locally. Adapt boot preparation to
its actual firmware/storage before activation. Never copy desktop UUIDs, signing
private keys, SSH host keys or the no-sleep policy onto it.

Only desktop is deployable today. There is intentionally no guessed ThinkPad host;
`stage --host thinkpad` rejects the request until its inventory/configuration exists.
The shared workflow checks/builds every host automatically once it is added.
