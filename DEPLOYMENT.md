# Remaining desktop deployment

Run commands from `/home/dhilipsiva/projects/dhilipsiva/NixOS` as dhilipsiva.
Generation **15** is running: the published `44d446b` modernisation (systemd
initrd, userborn, sudo-rs, Nix 2.35, nftables with systemd-resolved, rootless
Docker, compositor scale 1.5 and the rest listed in README.md). The owner
confirmed the scaling; the post-boot checks in section 2 still apply to it.

## 1. Stage the DisplayPort display policy

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
alias replaces the by-path name; staging the fixed revision needs the owner's
sudo password in their own terminal:

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
nix --version                                     # 2.35.2
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

## 4. Restore the VM rehearsal fixture (owner task)

`secrets/vm-test.yaml` is encrypted to a throwaway identity whose private key is
no longer available, so the VM can only exercise the break-glass path. To restore
the positive sops path, generate a new throwaway key outside Git and re-encrypt
the fixture; the agent session cannot write secret material itself:

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
in `.sops.yaml`, `scripts/check-secrets.py` and `scripts/deployment.py` with the
printed one, run `nix flake check .`, and boot the VM with
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
