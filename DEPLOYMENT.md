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

## 3. Save the existing Wi-Fi password for connection before login

Open the editor for the existing desktop connection:

```bash
nm-connection-editor --edit=9fe1ee6e-79f3-4b1c-b14c-70a2837dcba4
```

Autoconnect and **All users may connect to this network** are already enabled.
In **Wi-Fi Security**, enter the Wi-Fi password and use the storage icon inside
the password field to select **Store the password for all users**, then save.
The latest check (2026-10-04 14:34) still found password flags `1 (agent-owned)`.
The password stays in NetworkManager's local, root-owned connection file, outside
Git and the Nix store. Check only non-secret metadata:

```bash
nmcli -f connection.autoconnect,connection.permissions,802-11-wireless-security.psk-flags \
  connection show uuid 9fe1ee6e-79f3-4b1c-b14c-70a2837dcba4
```

Expected: autoconnect `yes`, empty permissions, password flags `0 (none)`. Then
confirm on a later boot that Wi-Fi connects before login without typing the
password ([NetworkManager secret flags](https://networkmanager.dev/docs/api/latest/secrets-flags.html)).

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

## Tuning follow-ups

The revision after `91c81ea` raises `vm.swappiness` to 180 for the zram-only
desktop; after staging and rebooting, `cat /proc/sys/vm/swappiness` reads 180.
Spectre-class mitigations deliberately stay enabled. Two checks need the owner's
terminal; paste the output into the session for interpretation:

```bash
sudo dmidecode -t memory | grep -E 'Size|Speed|Configured|Locator|Rank|Part Number' | grep -v 'No Module'
fwupdmgr refresh && fwupdmgr get-updates
```

Expected: the configured memory speed equals the EXPO profile rather than the
4800 MT/s JEDEC default (a firmware setting, not a Nix one), and fwupd lists any
LVFS firmware for the board or SSD. Applying firmware is always a manual
`fwupdmgr update` after reviewing the Secure Boot implications.

## Recovery

Select **NixOS (protected pre-migration recovery)** in the boot menu for the
original generation; the legacy generation 1/2 entries are unusable. Earlier
Lanzaboote generations (13, 14) remain in the menu for five generations. Keep the
encrypted recovery archive, owner age identity and recovery media. HDR
remains a separate future display test.
