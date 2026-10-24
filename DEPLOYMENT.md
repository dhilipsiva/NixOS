# Desktop deployment and acceptance

Run commands from `/home/dhilipsiva/projects/dhilipsiva/NixOS` as dhilipsiva.
Generation **24** was confirmed running on 2026-10-19 after the owner staged
and rebooted. `/run/current-system` and the system profile both resolved to
`/nix/store/fv7isyq743h3b9v07ifr47a7lv678zq2-nixos-system-dhilipsiva-desktop-26.05.20261015.26f4107`.
The post-boot checks below still distinguish observed behavior from pending
physical acceptance.

## Lucy desktop integration rollout

The Lucy integration runs on the desktop with Lucy's model pin and on the Yoga
with a smaller pinned model (YOGA.md). Publish the verified Lucy source revision,
pin it in this flake, then publish this repository through `scripts/nixosctl
publish`. Only after those checks succeed, run `scripts/nixosctl stage --host
desktop`. Staging installs the next boot generation; it does not switch the live
system. Reboot manually when ready.

After boot, inspect `systemctl --user status lucy lucy-adapters` and
`lucy integrations status`. The first service holds only session state until
invocation; the second merges the adapter settings and installs the VS Code
extension. It preserves existing models/credentials, writes backups, and refuses
conflicts. Review Codex's hooks in Codex, grant VS Code's selected-model access,
load the Chrome extension, and complete Firefox signing/trust as appropriate.
These application steps are not established by a Nix build or the login VM.

### Updating the Rust runtime and self-model

Advance the explicit Lucy revision in `flake.nix` and refresh its lock with
`nix flake update lucy`. The package builds Rust with `desktop-ui` and GTK4;
the desktop checks exercise the packaged service, self-model, GTK window and
host-specific model settings. Before publishing and staging, verify the candidate
executable itself:

```bash
nix build .#lucy
./result/bin/lucy self-model status
./result/bin/lucy self-model audit
```

An `unknown command self-model` response means the candidate is still an older
runtime. Refreshing the lock alone cannot advance a revision fixed in `flake.nix`.
After the required checks pass, commit the changes and publish the clean `master`
checkout through `scripts/nixosctl publish`, then stage through
`scripts/nixosctl stage --host desktop`.

Before the manual reboot, check for local overrides of **both** user services:

```bash
systemctl --user cat lucy.service lucy-adapters.service
nix profile list
```

An old `rust.conf` in either `~/.config/systemd/user/lucy.service.d/` or
`~/.config/systemd/user/lucy-adapters.service.d/` can override the packaged
`ExecStart` with `~/.nix-profile/bin/lucy`. If present and selecting that old
executable, rename that file to `rust.conf.disabled` in the same directory,
preserving any existing backup. Leave unrelated overrides alone. Remove the
personal `lucy-rust-local` package with `nix profile remove lucy-rust-local` if
it is still listed. This keeps private memory in `~/.local/share/lucy` intact.
Run `systemctl --user daemon-reload` after disabling an override.

After rebooting into the staged generation, verify both services and the CLI:

```bash
systemctl --user status lucy lucy-adapters
readlink -f "$(command -v lucy)"
lucy self-model status
lucy self-model audit
```

Both service commands must select the NixOS package. The service now runs in
Rust, without a `python3 -m lucy_desktop` child. An adapter failure mentioning a
missing `~/.nix-profile/bin/lucy` indicates a remaining local override; app
enrollment conflicts are a separate failure and retain their existing files.

`lucy setup-model` explicitly downloads the pinned Qwen3.6 model and checks the
manifest digest. Verify an actual local reply with `lucy chat`, use `ollama ps`
and `nvidia-smi` to check fit and unloading, and test Stop during a long reply.
Missing models, digest mismatches and GPU contention must produce visible local
errors. No cloud fallback is configured.

Physical acceptance still includes an attended screenshot/coordinate check at
scale 1.5 and mouse/keyboard actions in a disposable window, followed by lock,
cancel and close tests. Confirm the virtual input device disappears after each
action and `lucy-input.service` is inactive. Root input starts only after polkit
authentication and has a short maximum lifetime. Do not infer these results from
the headless GTK or unit tests.

Implementation validation on 2026-10-19: the pinned model downloaded and verified.
On the RTX 5090, a real chat read a disposable file through the tool and returned
its marker in 22.16 seconds. VRAM peaked at 24,723 MiB and returned to the
1,159 MiB desktop baseline; Ollama reported no loaded model afterward. A separate
cancellation during model startup returned immediately and left no loaded model.
Hyprland reported DP-1 at 3840×2160, scale 1.5; a 100×100 logical-pixel capture
produced a 150×150 image, which was then deleted. The native GTK window, private
Unix-socket service, activation/privacy tests, Lucy's Nibli checks, desktop login
VM and all-host stable builds passed. Full inference with the backend isolated
from external networking, physical mouse/keyboard behavior, app trust, and
post-boot enrollment remain separate acceptance steps. The isolated backend test
needs access to Ollama's service-owned model directory; the current user cannot
read it and has no cached sudo authorization.

Post-boot validation on 2026-10-19: Hyprland reported DP-1 at 3840×2160,
239.996 Hz, scale 1.5, XBGR2101010, with hardware cursors. No system units
were failed. Lucy's user service had exited on SIGTERM; restarting it restored
the private socket. A native Wayland file-handoff window then opened and closed
successfully, issuing only `open` and `close`, without memory loading or inference.
The earlier Dolphin launch failures occurred while the socket was unavailable.

Adapter enrollment exposed a VSIX packaging bug: files copied from the Nix
store retained read-only modes, preventing VS Code from updating the extracted
manifest. The package now makes those archive entries owner-writable, and a
flake check installs the extension twice in an isolated profile. The corrected
extension installed in the real account; retrying the boot generation's old
enrollment then failed again, and VS Code requested a restart before repair
could finish. A temporary user-unit override at
`$XDG_RUNTIME_DIR/systemd/user/lucy-adapters.service.d/90-vsix-repair.conf`
selects the verified fixed package for this login. After saving work and
restarting VS Code, retry `systemctl --user restart lucy-adapters.service`.
The permanent fix follows normal publication and staging; the temporary
override disappears on reboot. App trust and physical input acceptance remain
pending.


## 1. DisplayPort display policy and recovery history

The monitor moved from HDMI to DisplayPort on 2026-10-04. The checkout now
targets `DP-1` at 3840x2160@240 with 10-bit colour, adaptive sync in fullscreen
and scale 1.5, removes the HDMI FRL kernel parameters, lets fullscreen games scan
out directly, and restricts the compositor to the NVIDIA card through the udev
alias `/dev/dri/desktop-nvidia` so hardware cursors work. The same mode, depth
and scale were applied live with `hyprctl eval` and confirmed before committing.

Generation 16, the first build of this policy, looped back to the greeter after
login: its `AQ_DRM_DEVICES` used the by-path device name, whose colons aquamarine
treats as list separators, so Hyprland found no GPU and aborted (crash reports in
`~/.cache/hyprland/`). The owner booted generation 15 from the menu. The udev
alias replaces the by-path name. Staging prints an nvd closure diff against the
running system before installing boot entries and needs the owner's sudo password
in their own terminal:

```bash
scripts/nixosctl stage --host desktop && systemctl reboot
```

## 2. Verify after the reboot

```bash
hyprctl monitors | grep -E 'scale|3840|Format|Cursors'   # 240 Hz, scale 1.5, XBGR2101010, hardware cursors
systemctl --failed; systemctl --user --failed
systemctl status userborn.service sops-install-secrets-for-users.service --no-pager
sudo -v                                           # sudo-rs prompts for your password
systemctl --user status docker.service hyprpolkitagent.service blueman-applet.service
docker info | grep -E 'Context|Root Dir|rootless'  # rootless daemon in your session
pkexec true                                       # Hyprland-styled polkit prompt
resolvectl status | head -12
sudo nft list ruleset | head -30
findmnt /tmp                                      # tmpfs
nix --version                                     # 2.35.3
bluetoothctl show | head -3
zellij --version; cat ~/.config/zellij/config.kdl
command -v nix-channel || echo "nix-channel removed as intended"
```

Expected notes: the text console and login screen use a larger font; the boot
menu is readable at 4K; activation may warn once that
`/root/.nix-defexpr/channels` or `/nix/var/nix/profiles/per-user/root/channels`
still exist (leftovers of the channel-based installation; remove them as root at
your convenience). Xwayland applications (nvidia-settings, some Wine titles)
render at native pixels and therefore smaller. If an application still looks
small, it is drawing through Xwayland or ignoring the Wayland scale.

## 3. Wi-Fi password: resolved

The desktop profile keeps its password agent-owned (flags `1`) in the owner's
keyring, which PAM unlocks at login; the applet then connects without prompting.
The owner accepted this on 2026-10-04. The only consequence is that Wi-Fi is not
up before anyone logs in, so a nightly update that runs while the machine sits at
the greeter is skipped and retried the next evening. No further action.

## 4. Restore the manual VM rehearsal fixture (owner task, optional)

The `desktop-login` flake check boots the desktop configuration with its own
build-time fixture secrets, so the sops/userborn login path is covered without
any owner key. The manual `build.vm` rehearsal still uses `secrets/vm-test.yaml`,
whose throwaway private key is no longer available, so that VM only exercises the
break-glass path. To restore it, generate a new throwaway key outside Git and
re-encrypt the fixture; the agent session cannot write secret material itself:

```bash
mkdir -p ~/.local/state/nixosctl && chmod 700 ~/.local/state/nixosctl
ssh-keygen -q -t ed25519 -N '' -C 'nixos vm-test throwaway host key' -f ~/.local/state/nixosctl/vm-test-host-key
nix develop -c bash -c '
  rec=$(ssh-to-age < ~/.local/state/nixosctl/vm-test-host-key.pub)
  printf "{\"dhilipsiva\":{\"hashedPassword\":\"%s\"},\"ups\":{\"monitorPassword\":\"%s\"}}" \
    "$(openssl passwd -6 test)" "$(python3 -c "import secrets;print(secrets.token_urlsafe(48))")" \
    | sops --config /dev/null encrypt --input-type json --output-type yaml --age "$rec" /dev/stdin > secrets/vm-test.yaml
  echo "new VM recipient: $rec"'
```

Then replace the old recipient `age10hwn77a4vpj33s9u9j8u698lwmgv0g8trd2x5hk24zt5a0fnvsss6dj8mg`
in `.sops.yaml` (its only definition; `scripts/check-secrets.py` and
`scripts/deployment.py` read it from there) with the printed one, run
`nix flake check .`, and boot the VM with
`QEMU_OPTS="-m 4096 -fw_cfg name=opt/vmhostkey,file=$HOME/.local/state/nixosctl/vm-test-host-key"`.
Log in as `dhilipsiva` with password `test` to prove userborn received the hash.

## Tuning follow-ups: resolved

Revisions `ce8a81d` and `f375707` raise `vm.swappiness` to 180 for the zram-only
desktop and add `dmidecode`; after staging and rebooting,
`cat /proc/sys/vm/swappiness` reads 180. Spectre-class mitigations deliberately
stay enabled. Verified on 2026-10-04: the Corsair CMH96GX5M2B6000Z30 kit runs its
EXPO profile (2 x 48 GiB, 6000 MT/s, 1.1 V, channels A2/B2), and fwupd reports no
pending LVFS updates with the UEFI CA and dbx current. MSI firmware and the XPG
SSDs are not on LVFS; BIOS updates are a separate manual M-Flash task.

## Recovery

Select **NixOS (protected pre-migration recovery)** in the boot menu for the
original generation; the legacy generation 1/2 entries are unusable. Earlier
Lanzaboote generations (13, 14) remain in the menu for five generations. Keep the
encrypted recovery archive, owner age identity and recovery media. HDR
remains a separate future display test.
