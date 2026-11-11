# Session handoff

Repository: `/home/dhilipsiva/projects/dhilipsiva/NixOS` on every machine, owned
by dhilipsiva, tracking `origin/master`. Start any session by comparing the
running system with the published build before trusting state notes:

```bash
cd /home/dhilipsiva/projects/dhilipsiva/NixOS
git status --short --branch
readlink -f /run/current-system
nix build --no-link --print-out-paths .#nixosConfigurations.desktop.config.system.build.toplevel
```

The detailed migration record (firmware enrollment, dbx restoration, HDMI
failure analysis, CPU and Wi-Fi recovery, generation-by-generation evidence) is
in Git history up to commit `2652a41`; this file keeps only the facts a new
session needs.

## Desktop facts

- Hardware: MSI MAG X870E TOMAHAWK WIFI (MS-7E59), Ryzen 9 9950X3D (16 cores /
  32 threads online since the owner disabled X3D Gaming Mode), RTX 5090 on the
  NVIDIA open module, Samsung Odyssey G81SF 4K over HDMI-A-1, Qualcomm WCN7850
  Wi-Fi (`wlp8s0`, recovered after a motherboard power drain), CyberPower UPS.
- Display: DisplayPort (DP-1) since 2026-10-04 at 3840x2160@240, 10-bit, VRR
  in fullscreen, compositor scale 1.5, NVIDIA-only DRM device through the
  colon-free udev alias `/dev/dri/desktop-nvidia`. The HDMI FRL
  workaround is gone; HDR is an untested future change.
- Boot: Lanzaboote-signed UKIs with the owner's local certificate appended to
  the firmware db; all factory PK/KEK/db/dbx entries are preserved and the
  staging helper verifies that before every deployment. Recovery entry
  **NixOS (protected pre-migration recovery)** boots the original generation 2
  (Plasma/nouveau) from `/EFI/nixos-recovery/pre-migration.efi`. Legacy
  generation 1/2 loader entries are unusable. The encrypted recovery archive is
  `~/nixos-boot-recovery.*.tar.age`; the owner age identity lives in
  `~/.config/sops/age/keys.txt` and is backed up off-machine.
- Secrets: `secrets/desktop.yaml` is encrypted to the owner identity and the
  desktop's SSH host identity; staging verifies decryption and that the
  preserved login hash matches `/etc/shadow`. The VM fixture
  `secrets/vm-test.yaml` is encrypted to a throwaway identity that is no longer
  available locally; regenerate it (see DEPLOYMENT.md) before using the VM
  rehearsal's positive sops path.
- Publication: the desktop pushes with the repository-scoped deploy key in
  `~/.ssh/nixos-update` through `core.sshCommand`; the nightly timer runs at
  21:00 Asia/Colombo and stages verified updates for the next manual reboot.
  Acceptance and the first cleanup (36.4 GiB freed) are complete.
- Wi-Fi: password agent-owned in the keyring by the owner's choice; it connects
  automatically after login, not before. Memory runs its EXPO profile
  (2 x 48 GiB DDR5-6000) and fwupd shows no pending firmware.

## Current state (2026-10-04)

The owner reports the ThinkPad boots and works on its staged configuration and
accepted it; `system.etc.overlay` is an attended task for the laptop's VM session
(THINKPAD.md).

Generation 24 is running (checked 2026-10-22: `/run/current-system` and `system-24-link` are
`fv7isyq743h3b9v07ifr47a7lv678zq2-nixos-system-dhilipsiva-desktop-26.05.20261015.26f4107`, staged
2026-10-19). Earlier: generation 15 (published `44d446b`, the modernisation) ran and the owner
confirmed the 1.5 scale. The checkout adds the DisplayPort display policy
described in DEPLOYMENT.md; the previous modernisation built as
`/nix/store/vwbdamgnanaghnwwafwg27mbd8p9q6ng-nixos-system-dhilipsiva-desktop-26.05.20261002.774debe`,
passes every flake check, the `nixosctl check --stable` gate (both hosts build)
and a headless VM rehearsal of the boot path. It was rebased onto the laptop
session's ThinkPad host commit `0a3b61b`, whose checks and host policies it keeps. Staging and the reboot follow the normal `nixosctl`
workflow; nothing switches live.

## Yoga state (2026-10-04)

The owner installed NixOS 26.05 on the Yoga Slim 7 15ILL9 with the official
graphical installer (GNOME, generation 1, unencrypted ext4, unsigned
systemd-boot, Secure Boot off). The Yoga session captured that installation
into `hosts/yoga/hardware-configuration.nix` and `installation.nix`, made
`nixosConfigurations.yoga` a real host with the ThinkPad's unsigned boot policy,
kept zram as the only swap (`systemd.swap=0` leaves the installer's swap
partition unused) and installed the user Flatpak Sober 1.8.0. The owner
enrolled the credentials, published `1ee1bc2`, prepared boot, staged it and
booted it. The runtime audit on that generation (YOGA.md) led to the
hardware-tuning commit: release-branch Intel media/compute runtimes (the
master ones failed against libva 2.23 and aborted in OpenCL), the panel's
120 Hz mode with fullscreen-only VRR, Ollama on the integrated GPU, all cores
for one build and bolt. That commit is next to publish and stage on the Yoga;
physical acceptance (`nixosctl accept --host yoga`) is still pending.

## Yoga state (2026-10-20)

The running generation 5 (`2db8i034…`, staged 2026-10-18) predates the Windows
helpers and the desktop Lucy work; its pending update to the published tip was
configuration-only for the Yoga (the same kernel, initrd and parameters, no
package changes). The owner then asked for Lucy on this less powerful host
without affecting the desktop. The integration moved from `hosts/desktop/lucy.nix`
to the opt-in `modules/nixos/lucy.nix`, which each enabling host imports at its
host-module position so merged lists keep their order; `repo.lucy.model` pins a
host model, and `pkgs/lucy.nix` substitutes only Nibli's three model constants
and takes the host's Ollama build as the client. The Yoga pins Qwen3.5 9B Q4_K_M
(digest `56671c2a…`, about 6 GiB) because Nibli's Qwen3.6 35B-A3B needs about
25 GiB and Qwen3.6 has no smaller size; the NPU has no Ollama backend, so the
Arc 140V's Vulkan runner serves it. Verified: the desktop and ThinkPad toplevels
evaluate to the same store paths as before the change (`fn01gcrh…`,
`s1bydcq5…`), the Yoga closure grows by about 4 MiB, and `nix fmt`, `nix flake
check .` (including the new `lucy-yoga-model` check) and `scripts/nixosctl check
--stable` passed. Staging (`scripts/nixosctl stage --host yoga`), the reboot,
`lucy setup-model` and the YOGA.md acceptance remain the owner's steps.

## ThinkPad state (2026-10-24)

Generation 297 is running (`8b9a9sb7…`, staged by the subscriber nightly on
2026-10-23 from `961c343`; the Lucy packaging commits of 2026-10-24 did not change
the ThinkPad). The owner then asked for Lucy on the ThinkPad as well.
`hosts/thinkpad/default.nix` now imports `modules/nixos/lucy.nix` with the Yoga's
pin (qwen3.5:9b-q4_K_M, digest `56671c2a…`): the RTX 3070 Laptop GPU has 8 GiB
with 2 GiB reserved as overhead, so the weights and the 16K context may keep part
of the layers in RAM. `host-policies` asserts the enablement and the pin, and the
new `lucy-thinkpad-model` check exercises the wrapper. Verified on the ThinkPad:
`nix fmt`, `nix flake check .` and `scripts/nixosctl check --stable` passed; the
desktop and Yoga toplevels evaluate to the same store paths as before
(`alzdxla8…`, `cssqjh2m…`) and the ThinkPad's to `gpwrb34a…`. The private store
at `~/.local/share/lucy` was created before staging, with the three public peers
enrolled read-only, the owner's `lucy-private` snapshot restored (1073 records)
and this checkout's `lucy/` registered. Publication through `scripts/nixosctl
publish`, the 21:30 subscriber staging, the reboot and the THINKPAD.md acceptance
follow; nothing was switched or rebooted.

Later on 2026-10-24: the memory reconciliation commit makes `lucy/` agree with
Lucy origin `879b06c` (constitution comment, twelve direct facts, peer index,
handoff note; `lucy check` compiles 231 statements with standing). Because every
host's Lucy identity embeds `lucy/memory.nibli`, all three toplevels change
(desktop `0fnnnr3n…`, Yoga `rvri8qxg…`, ThinkPad `0bm8sk75…`); `nix flake check
.` reran all 36 checks and `scripts/nixosctl check --stable` passed. On the
ThinkPad `lucy setup-model` pulled and verified `qwen3.5:9b-q4_K_M` (6.1 GiB,
digest `56671c2a…`), and one request through Ollama's API with Lucy's request
shape loaded the whole model into VRAM (6.8 GiB peak of 8 GiB, 36 tokens/s after
a 35 s cold load) and unloaded it at once. Lucy's own chat path did not run:
`lucy agent` refused with `local context budget reached` because recall over the
synced public operation logs returned about 56 kB of excerpts against the 48 kB
cap in lucy-cli `desktop/core.rs`; that needs an upstream fix and a re-pin, and
the desktop and Yoga sync the same archive. The owner's upload actor regenerates
the `nixos-public` branch with `lucy sync` after publication. Publication through
`scripts/nixosctl publish`, the 21:30 subscriber staging and the reboot follow.

## Desktop state (2026-11-10)

Generation 35 was running when this session began (booted 09:50, equal to
`6636da4`). Three changes were made on the desktop and are published together.

`lucy/` agrees with Lucy's origin again. The constitution here ended at
Article 6 and is now byte for byte the origin's, with eleven articles;
`lucy/memory.nibli` spells `Bucchi`; `lucy.nibli` is regenerated from both
(`lucy check`: 24 and 25 statements, standing). Lucy's service uploaded the two
files to the `nixos-public` memory branch at 13:44 (head `eb9ac4a`, 39
operations). Every host's Lucy identity embeds `lucy/memory.nibli`, so all
three toplevels change.

The Lucy pin moved from `6751c97` to `0dac7e5`; `Cargo.lock` is unchanged,
so `pkgs/lucy.nix` keeps its hash. The prompt hook had been cancelled at its
ten-second limit, and what it returned was 260 to 540 kB, of which Claude Code
passes on 2,000 characters. The new revision records a prompt before anything
can refuse it, builds every context against a budget (9,000 UTF-16 units for a
hosted app, conversation ID and capture reminder first), answers within 4.5
seconds whatever memory is doing, verifies each enrolled log once per content
and ranks what it retrieves. Measured on a copy of the desktop's store, without
network or an embedding model: a hosted prompt takes 0.56 to 0.66 s where it
took 2.5 s, a 3,000-word prompt 0.57 s where it took 6.3 s, and a prompt sent
while the store was locked for 12 s is answered at 4.5 s and saved once the
lock is released. None of this has been observed on the running system yet.

The desktop backs Lucy's private memory up hourly into the private repository
`lucy-private` (`repo.lucy.backup`, `scripts/lucy-backup.py`, a user timer that
first fires ten minutes after login); the laptops do not. A run lists the peers
it carries, verifies what it wrote, pushes `main` only and never forces. The
first backup was made through the same script on 2026-11-10 (2,394 records,
8 MB); a rehearsal on a copy of the store restored such a backup into an empty
store (2,392 records).

Verified on the desktop: `nix fmt`, `nix flake check .`, the desktop toplevel
and `scripts/nixosctl check --stable`. Publication through `scripts/nixosctl
publish` and staging for the desktop's next boot follow; nothing was switched
or rebooted. After the reboot, the first prompt that addresses Lucy should show
the hook finishing with its context inline, `systemctl --user list-timers
lucy-backup.timer` should show the next run, and one manual start of
`lucy-backup.service` should push.

Later on 2026-11-10: the desktop was rebooted into generation 36 at 14:41. On
the running system the prompt hook returned its context inline (8,993
characters; about 4 s on the first prompt after boot, 1.9 s on the next), the
backup timer was active, and one manual start of `lucy-backup.service` pushed
from its unit in 20 s. Most of the 1.9 s was the embedding model: Ollama here
unloads every model after each request, so each prompt paid about 1.2 s to load
it. dhilipsiva decided that a prompt skips the embedding when the model is not
loaded. Lucy `70945b8` does that, while a search someone asks for still
loads the model, and the pin moved to it. dhilipsiva also confirmed that the
desktop keeps Lucy's own model pin, qwen3.6:35b-a3b-q4_K_M, as its default,
which `host-policies` already asserts; replacements for the laptops'
qwen3.5:9b are to be chosen later. Verified on the desktop: `nix fmt`, `nix
flake check .`, the desktop toplevel and `scripts/nixosctl check --stable`.
Publication and staging follow; the change takes effect at the next reboot.

On 2026-11-11: dhilipsiva asked for every UI to follow his site's design system,
QUINE (dhilipsiva.dev `static/assets/tokens`), as far as possible. `lib/quine.nix`
holds its tokens once: the void surfaces, warm white text, ember `#F2542D` as
the single accent, phosphor, quanta and the signal colours, IBM Plex and Space
Grotesk, the radii and a 16-colour terminal map whose bright red is ember. From
it: Hyprland (ember focus border, rounding 6), a generated wallpaper
(`pkgs/quine-wallpaper.nix`: the void, the blueprint grid and the site's mark,
drawn by swaybg; hyprpaper 0.8 crashed on the check VM's software renderer),
hyprlock, Waybar, Fuzzel, mako, Alacritty, Zellij, Helix, starship, fish, Atuin,
btop, GTK 3 and 4 (adw-gtk3-dark, Papirus-Dark in deep orange, QUINE colour
overrides), Qt and Dolphin (the KDE platform theme, colours written into
kdeglobals by kwriteconfig6), the console palette and tuigreet. On the console
red is ember too: it draws backgrounds only from its first eight colours, and the
greeter's key labels are ember. IBM Plex Mono
replaced Fira Code everywhere by his choice; Fira stays installed for app
settings kept outside this repository. Lucy moved to `de48997`, which dresses
Ask Lucy in QUINE.

The desktop-login check now also photographs the launcher, a terminal, a
notification, the lock screen and the greeter. Its VM turns rootless Docker
off: a fresh VM has no `/etc/subuid` (the hosts kept theirs from installation),
so Docker failed there three times, and the failed-units check had passed only
by running before the third failure. Nothing in this repository declares the
owner's subordinate ID range, so a fresh installation may meet the same.
Home Manager replaces the unmanaged `~/.config/btop/btop.conf`, backing it up.

Verified on the desktop: `nix fmt`, `nix flake check .`, every host through
`scripts/nixosctl check --stable`, and screenshots of each surface. Publication
follows; nothing was switched or staged, so the theme arrives with the next
staged generation and a new login.
