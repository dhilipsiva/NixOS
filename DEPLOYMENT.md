# Remaining desktop deployment

Run commands from `/home/dhilipsiva/projects/dhilipsiva/NixOS` as dhilipsiva.
Generation **13** is running, confirmed on 2026-10-04. Its system path matches
the published `7c8c77d` build:
`/nix/store/1xs9pw9qyzcq5ym0vasmgxg0j9b7raqf-nixos-system-dhilipsiva-desktop-26.05.20261002.774debe`.
The NetworkManager applet is active. All **16 CPU cores / 32 threads**
are online, with SMT and frequency boost enabled. The reduced-effects profile is
active; HDMI-A-1 remains at 3840×2160/60 Hz, 8-bit SDR. NVIDIA is working, Secure
Boot is enabled and system/user failed-unit lists are empty.

The owner completed acceptance/cleanup: the successful cleanup output reports
4,077 store paths removed and **36.4 GiB freed**, retaining the recovery roots.
The cleanup helper checks the acceptance gate before collecting. Do not repeat
initial enrollment, CPU troubleshooting or first-deployment cleanup. Detailed
history and the limits of independent physical verification are in
[SESSION.md](SESSION.md).

The Qualcomm Wi-Fi adapter is detected again after the owner's motherboard power
drain. **Automatic connection before login still needs verification:** the existing
profile has autoconnect enabled but an agent-owned password. Generation 12 logged
`No agents were available for this request`; generation 13 now supplies that agent.
The repository's redesigned status bar is the next change to activate.

## 1. Save the existing Wi-Fi password for connection before login

Open the editor for the existing desktop connection:

```bash
nm-connection-editor --edit=9fe1ee6e-79f3-4b1c-b14c-70a2837dcba4
```

Autoconnect and **All users may connect to this network** are already enabled.
The remaining step is in **Wi-Fi Security**: enter the Wi-Fi password and use the
storage icon inside the password field to select **Store the password for all
users**, then save. The latest check still found password flags `1 (agent-owned)`.

The password stays in NetworkManager's local, root-owned connection file, outside
Git and the Nix store. Do not paste it into chat or Nix configuration. Saving the
profile does not require taking down the current connection.

Check only non-secret metadata:

```bash
nmcli -f connection.autoconnect,connection.permissions,802-11-wireless-security.psk-flags \
  connection show uuid 9fe1ee6e-79f3-4b1c-b14c-70a2837dcba4
```

Expected: autoconnect `yes`, empty permissions (`--`), and password flags
`0 (none)`, meaning NetworkManager stores the password. The password must actually
be saved too; flags alone cannot prove it. See the
[NetworkManager secret flags reference](https://networkmanager.dev/docs/api/latest/secrets-flags.html).

## 2. Activate the improved status bar

After the repository checks and publication succeed:

```bash
scripts/nixosctl stage --host desktop
```

Reboot manually when ready. The new bottom bar has five workspace buttons,
a clock/calendar, CPU/RAM/storage readings, network/audio controls, service
warnings, the existing tray and a lock button. Verify after boot:

```bash
nmcli -t -f DEVICE,TYPE,STATE device status
systemctl --user status waybar.service
systemctl --failed
systemctl --user --failed
```

Confirm Wi-Fi connected without entering its password or manually activating the
connection. That startup test remains necessary even after the profile is saved.
Check the bar's launcher, workspace buttons, network/audio settings and lock
control. Layout previews and successful builds do not verify clicks on this boot.
The existing update/GC acceptance gate has passed; no repeat cleanup is needed.

For recovery, select **NixOS (protected pre-migration recovery)**. The legacy
separate generation 1/2 entries have missing files; use the protected entry.
Keep the encrypted recovery archive, owner age identity and recovery media.
Higher refresh/HDR remains a separate future display test; retain the working
HDMI workaround until then.
