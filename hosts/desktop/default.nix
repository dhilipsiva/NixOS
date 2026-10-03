{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./graphics.nix
    ./performance.nix
    ./power.nix
    ./windows.nix
    ./maintenance.nix
    ./secure-boot.nix
    # Offload microcode / GPU / SSD quirks to nixos-hardware.
    inputs.nixos-hardware.nixosModules.common-cpu-amd
    # -nonprime: single discrete RTX 5090 with the monitor wired directly to it
    # (no hybrid/PRIME offload). Plain common-gpu-nvidia assumes PRIME and would
    # demand bus IDs we don't have on this desktop.
    inputs.nixos-hardware.nixosModules.common-gpu-nvidia-nonprime
    inputs.nixos-hardware.nixosModules.common-pc-ssd
  ];

  networking.hostName = "dhilipsiva-desktop";

  # Each host selects its encrypted secrets; the ThinkPad can use its own file.
  sops.defaultSopsFile = ../../secrets/desktop.yaml;

  # --- VM-TEST-ONLY OVERRIDES (build-vm variant; ZERO effect on real hardware) ---
  # Everything under virtualisation.vmVariant applies only when building
  # `nixos-rebuild build-vm --flake .#desktop`, never to the installed system.
  # This makes the desktop config bootable headless for the VM-first workflow
  # (GATE 1 boot check and every later phase's VM rehearsal).
  virtualisation.vmVariant = {
    virtualisation.graphics = false;
    boot.kernelParams = [ "console=ttyS0,115200n8" "console=tty1" ];
    systemd.services."serial-getty@ttyS0".enable = true;
    virtualisation.forwardPorts = [ { from = "host"; host.port = 2222; guest.port = 22; } ];

    # VM-only SSH + a throwaway ROOT PASSWORD (not a hashedPassword -> GATE-4 clean).
    # This is the break-glass: if sops fails to decrypt, dhilipsiva locks but root
    # still gets a shell to inspect /run/secrets-for-users. dhilipsiva itself now
    # logs in ONLY via the sops path (no password override here) so the VM
    # exercises the real mechanism.
    services.openssh.enable = true;
    services.openssh.settings.PermitRootLogin = "yes";
    # Base closes the firewall (real HW); the VM needs port 22 reachable through
    # the QEMU hostfwd, so re-open it here (VM-only).
    services.openssh.openFirewall = lib.mkForce true;
    users.users.root.password = "test";

    # Decrypt the FAKE secrets in the VM (never the owner's real secrets.yaml).
    sops.defaultSopsFile = lib.mkForce ../../secrets/vm-test.yaml;

    # Load qemu_fw_cfg in the INITRD so its sysfs is guaranteed populated before
    # stage-2 activation (at first boot the module was not yet loaded, so the key
    # was absent when sops ran — the exact bug this fixes).
    boot.initrd.kernelModules = [ "qemu_fw_cfg" ];

    # Inject a throwaway ed25519 host key (passed at RUN time via QEMU -fw_cfg,
    # never committed / never in the store) into /etc/ssh so sops self-decrypts via
    # sops.age.sshKeyPaths — the SAME code path as real hardware. Ordered strictly
    # before sops' setupSecretsForUsers; hardened so a missing key can't abort
    # activation (that is exactly the negative/break-glass test).
    system.activationScripts.injectVmHostKey.text = ''
      mkdir -p /etc/ssh
      if [ -e /sys/firmware/qemu_fw_cfg/by_name/opt/vmhostkey/raw ]; then
        cat /sys/firmware/qemu_fw_cfg/by_name/opt/vmhostkey/raw > /etc/ssh/ssh_host_ed25519_key 2>/dev/null || true
        chmod 600 /etc/ssh/ssh_host_ed25519_key 2>/dev/null || true
        ${pkgs.openssh}/bin/ssh-keygen -y -f /etc/ssh/ssh_host_ed25519_key > /etc/ssh/ssh_host_ed25519_key.pub 2>/dev/null || true
      fi
    '';
    system.activationScripts.setupSecretsForUsers.deps = [ "injectVmHostKey" ];
  };

  # --- SSH / SECRETS KEY SOURCE + BREAK-GLASS (real hardware) ---
  # Enable sshd so the ed25519 host key exists and sops self-decrypts from it
  # (sops.age.sshKeyPaths). Port 22 is NOT opened to the LAN.
  services.openssh.enable = true;
  services.openssh.openFirewall = false;

  # Owner's public recovery key; the private key stays outside this repository.
  users.users.root.openssh.authorizedKeys.keyFiles = [ ../../secrets/owner.pub ];

  # Preserve the bootloader of the existing installation. Windows keeps its own
  # ESP on the other SSD and remains selectable from the firmware boot menu.
  boot.loader = {
    efi = {
      canTouchEfiVariables = true;
      efiSysMountPoint = "/boot";
    };
    systemd-boot = {
      # Signing is provided by Lanzaboote in secure-boot.nix.
      # Bound the number of kernels/initrds retained on the existing 1 GiB ESP.
      configurationLimit = 5;
    };
  };

  # --- FIRMWARE ---
  # Rely on redistributable firmware + nixos-hardware (26.05's linux-firmware
  # already carries the MSI X870E Qualcomm Wi-Fi firmware). The old hand-rolled
  # fetchgit override with a placeholder sha256-AAAA… hash is removed — it could
  # never build. If a specific firmware is later proven missing on real hardware,
  # add a narrowly-scoped override with a real hash then.
  hardware.enableRedistributableFirmware = true;

  # --- UPS MONITORING (CyberPower) ---
  # 26.05's power.ups uses a structured schema: an upsd account under
  # `users.<name>` plus a `upsmon.monitor.<name>` entry. The monitor password now
  # comes from sops (decrypted to /run/secrets/ups/monitorPassword), replacing the
  # old plaintext file path. restartUnits so the NUT services pick up the secret.
  sops.secrets."ups/monitorPassword" = {
    owner = "root";
    restartUnits = [ "upsd.service" "upsmon.service" ];
  };
  power.ups = {
    enable = true;
    mode = "standalone";
    ups.cyberpower = {
      driver = "usbhid-ups";
      port = "auto";
    };
    users.upsmon = {
      passwordFile = config.sops.secrets."ups/monitorPassword".path;
      upsmon = "primary"; # NUT renamed master/slave → primary/secondary
    };
    upsmon = {
      monitor.cyberpower = {
        system = "cyberpower@localhost";
        user = "upsmon";
        type = "primary";
        # powerValue defaults to 1; passwordFile defaults to users.upsmon.passwordFile
      };
      settings.SHUTDOWNCMD = "${pkgs.systemd}/bin/shutdown -h +0";
    };
  };

  # Preserve the installed system's data-format defaults even as packages update.
  # Home Manager is new on this host; the ThinkPad will keep its own two anchors.
  system.stateVersion = "25.11";
  home-manager.users.dhilipsiva.home.stateVersion = "26.05";
}
