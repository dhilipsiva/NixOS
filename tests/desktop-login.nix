# Boot the real desktop configuration in QEMU, decrypt build-time fixture
# secrets through the same sops-nix/userborn path as the hardware, log in on a
# text console with the fixture password, and let greetd start the Hyprland
# session with Waybar and the polkit agent. Nothing from the owner's secrets or
# host identities is used.
{
  pkgs,
  inputs,
  hostModules,
}:

let
  fixture =
    pkgs.runCommand "desktop-login-fixture"
      {
        nativeBuildInputs = with pkgs; [
          openssh
          ssh-to-age
          sops
          mkpasswd
        ];
      }
      ''
        mkdir -p "$out"
        ssh-keygen -q -t ed25519 -N "" -C "desktop-login fixture" -f "$out/host_key"
        recipient=$(ssh-to-age < "$out/host_key.pub")
        hash=$(mkpasswd -m yescrypt test)
        printf '{"dhilipsiva":{"hashedPassword":"%s"},"ups":{"monitorPassword":"fixture"}}' "$hash" \
          | sops --config /dev/null encrypt --input-type json --output-type yaml --age "$recipient" /dev/stdin \
          > "$out/secrets.yaml"
      '';
in
pkgs.testers.runNixOSTest {
  name = "desktop-login";
  node.specialArgs = { inherit inputs; };
  # The node evaluates its own package set so the host overlays apply.
  node.pkgsReadOnly = false;

  nodes.machine =
    { lib, pkgs, ... }:
    {
      imports = hostModules;
      virtualisation = {
        memorySize = 4096;
        cores = 4;
        # A KMS device the compositor can drive with software rendering, as the
        # nixpkgs Sway test does; the default emulated VGA has no usable DRM node.
        qemu.options = [ "-vga none -device virtio-gpu-pci" ];
      };

      # The VM has no NVIDIA card, Lanzaboote PKI, UPS or owner host key.
      boot.lanzaboote.enable = lib.mkForce false;
      environment.sessionVariables.AQ_DRM_DEVICES = lib.mkForce "/dev/dri/card0";
      power.ups.enable = lib.mkForce false;
      sops.defaultSopsFile = lib.mkForce "${fixture}/secrets.yaml";
      # Activation runs before sops-install-secrets-for-users.service reads the key.
      system.activationScripts.desktopLoginFixtureKey.text = ''
        install -D -m 600 ${fixture}/host_key /etc/ssh/ssh_host_ed25519_key
        install -D -m 644 ${fixture}/host_key.pub /etc/ssh/ssh_host_ed25519_key.pub
      '';
      # Start the Wayland session without typing: greetd, PAM, UWSM and Hyprland
      # still run exactly as on hardware. Password login is tested on tty2.
      services.greetd.settings.initial_session = {
        command = "${pkgs.uwsm}/bin/uwsm start hyprland.desktop";
        user = "dhilipsiva";
      };
    };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # userborn received the login hash that sops-nix decrypted with the host key.
    for unit in ["sops-install-secrets-for-users.service", "userborn.service"]:
        machine.succeed(f"systemctl show -p Result --value {unit} | grep -qx success")
    machine.succeed("getent shadow dhilipsiva | cut -d: -f2 | grep -q '^\\$'")

    # greetd's session on tty1: Hyprland under UWSM with the shared user services.
    # It must own the seat before anything switches consoles, or libseat times out.
    # UWSM starts these units a moment after greetd opens the session, so poll
    # instead of wait_for_unit, which fails on a unit that is still inactive.
    def user_unit_active(unit):
        machine.wait_until_succeeds(
            f"su dhilipsiva -c 'XDG_RUNTIME_DIR=/run/user/1000 systemctl --user is-active {unit}'",
            timeout=300,
        )

    try:
        user_unit_active("graphical-session.target")
    except Exception:
        print(machine.execute("ls /dev/dri; tail -n 70 /home/dhilipsiva/.cache/hyprland/*.txt 2>/dev/null")[1])
        raise
    user_unit_active("waybar.service")
    user_unit_active("hyprpolkitagent.service")
    machine.wait_until_succeeds("ls /run/user/1000/hypr/*/.socket.sock")
    machine.succeed(
        "su dhilipsiva -c 'XDG_RUNTIME_DIR=/run/user/1000 "
        "HYPRLAND_INSTANCE_SIGNATURE=$(ls /run/user/1000/hypr) hyprctl -j monitors' | grep -q '\"name\"'"
    )
    machine.screenshot("desktop")
    failed = machine.succeed(
        "su dhilipsiva -c 'XDG_RUNTIME_DIR=/run/user/1000 systemctl --user --failed --no-legend --plain'"
    )
    assert failed.strip() == "", f"failed user units: {failed}"

    # Password login on a text console proves the hash is usable for PAM. With a
    # compositor holding the seat, VT switching needs the Ctrl modifier.
    machine.send_key("ctrl-alt-f2")
    machine.wait_until_tty_matches("2", "login: ")
    machine.send_chars("dhilipsiva\n")
    machine.wait_until_tty_matches("2", "Password: ")
    machine.send_chars("test\n")
    machine.send_chars("touch /tmp/login-ok\n")
    machine.wait_for_file("/tmp/login-ok")
  '';
}
