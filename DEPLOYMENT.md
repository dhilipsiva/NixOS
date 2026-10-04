# Remaining desktop deployment

Run commands from `/home/dhilipsiva/projects/dhilipsiva/NixOS` as dhilipsiva.
Generation **14** is running (published `2652a41`, booted 2026-10-04 14:16
Asia/Colombo) with the redesigned Waybar, all 16 cores / 32 threads, the recovered
Wi-Fi adapter, Secure Boot and empty failed-unit lists. Acceptance and the first
cleanup are complete; do not repeat enrollment, CPU troubleshooting or
first-deployment cleanup.

## 1. Stage the modernised configuration

The published revision after `2652a41` modernises the whole configuration while
keeping hardware, filesystems, secrets and the no-sleep policy unchanged:

- systemd initrd; boot menu editor off; readable 4K boot menu
- userborn-managed accounts with sops-nix systemd activation; `sudo-rs`
- Nix 2.35 (`nixVersions.latest`), XDG base directories, kept outputs,
  nix-community cache, `nix-channel` removed, `command-not-found` off
- systemd-resolved, nftables firewall, port 8080 no longer open
- rootless Docker (user service limited to dhilipsiva, `DOCKER_HOST` set);
  docker/input/plugdev groups removed
- Bluetooth + Blueman, fwupd, systemd-oomd for user slices, tmpfs `/tmp`
- compositor scale 1.5 on the 4K panel, Terminus 32px console font, Bibata
  cursor, dark colour-scheme preference, `xdg-open` through the portal
- hyprpolkitagent, Zellij through its Home Manager module (upstream keybindings,
  fish), applications moved to the Home Manager profile, Helix with wrapped
  language servers, Alacritty 12pt (scaled), Waybar 12px/30px (scaled)
- nixfmt formatting, deadnix and ruff enforced by the `formatting` check

It builds as
`/nix/store/31fc551hn6bfmb1p5b4gps3b9ww81v43-nixos-system-dhilipsiva-desktop-26.05.20261002.774debe`
and passes `nix flake check` and `scripts/nixosctl check --stable`. A headless
QEMU rehearsal of this configuration (without the VM secrets key) booted through
the systemd initrd in 3.5 s, ran userborn successfully, kept start-up going while
the two sops units failed as designed, and showed sudo-rs, Nix 2.35.2, nftables,
systemd-resolved, tmpfs `/tmp`, the console font and the rootless Docker user
unit in place; root reached a shell over SSH. The UPS units fail in the VM because
the hardware and its secret are absent. The 52 dbus-broker "Ignoring duplicate
name" journal warnings already occur on generation 14 and are unrelated. Staging
needs the owner's sudo password in their own terminal:

```bash
scripts/nixosctl stage --host desktop && systemctl reboot
```

The helper re-verifies the published revision, credentials and firmware trust,
installs the signed entries and leaves the running system untouched until the
reboot.

## 2. Verify after the reboot

```bash
hyprctl monitors | grep -E 'scale|3840'          # scale 1.5; Firefox at 100 % zoom should now be readable
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

## Recovery

Select **NixOS (protected pre-migration recovery)** in the boot menu for the
original generation; the legacy generation 1/2 entries are unusable. Earlier
Lanzaboote generations (13, 14) remain in the menu for five generations. Keep the
encrypted recovery archive, owner age identity and recovery media. Higher
refresh/HDR remains a separate future display test; retain the HDMI workaround
until then.
