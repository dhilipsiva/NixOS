{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    # Offload microcode / GPU / SSD quirks to nixos-hardware.
    inputs.nixos-hardware.nixosModules.common-cpu-amd
    # -nonprime: single discrete RTX 5090 with the monitor wired directly to it
    # (no hybrid/PRIME offload). Plain common-gpu-nvidia assumes PRIME and would
    # demand bus IDs we don't have on this desktop.
    inputs.nixos-hardware.nixosModules.common-gpu-nvidia-nonprime
    inputs.nixos-hardware.nixosModules.common-pc-ssd
  ];

  networking.hostName = "dhilipsiva-desktop";

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

  # Break-glass: a committed PUBLIC key on root (GATE-4 clean — no hashedPassword)
  # so a sops decrypt failure can't fully lock the machine. This is a PLACEHOLDER
  # key the agent generated (private half at /home/nixos/phase4-keys/, never
  # committed); ROTATE it to your own ~/.ssh/id_ed25519.pub. NOTE: with the
  # firewall closed above, remote SSH break-glass needs the port opened or LAN
  # access; the always-available recovery for this desktop is GRUB `init=/bin/sh`.
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILqTvkDG0g7m1FYnB0k8vaU3JbFTTEcqIS4mrpyWSWcJ dhilipsiva-PLACEHOLDER-rotate-me"
  ];

  # --- BOOTLOADER (Dual Boot Optimized) ---
  # We use GRUB because it detects Windows on a separate drive better than systemd-boot
  boot.loader = {
    efi = {
      canTouchEfiVariables = true;
      efiSysMountPoint = "/boot";
    };
    grub = {
      enable = true;
      devices = [ "nodev" ];
      efiSupport = true;
      useOSProber = true; # Finds your Windows SSD automatically (read-only)
      # GRUB keeps every generation's kernel+initrd on the ESP (/boot). Bound the
      # count so the 2 GiB ESP can't fill and break a future `nixos-rebuild switch`.
      configurationLimit = 10;
    };
  };

  # --- KERNEL & CPU ---
  # 26.05's default kernel already covers Ryzen 9000 X3D scheduling; the
  # linuxPackages_latest override is dropped (it can fight the NVIDIA module ABI
  # and loses binary-cache coverage). Re-add only if the VM shows a concrete need.

  # --- GRAPHICS (RTX 5090) ---
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false; # Desktop GPUs run better without aggressive power saving
    open = true; # REQUIRED for 50-series Blackwell (proprietary module is unsupported)
    nvidiaSettings = true;

    # Current production branch on 26.05 (confirm exact version via nix eval, not a
    # hardcoded number). NOT .beta (a pre-580 workaround) and NOT .legacy_580.
    package = config.boot.kernelPackages.nvidiaPackages.production;
  };

  # --- FIRMWARE ---
  # Rely on redistributable firmware + nixos-hardware (26.05's linux-firmware
  # already carries the MSI X870E Qualcomm Wi-Fi firmware). The old hand-rolled
  # fetchgit override with a placeholder sha256-AAAA… hash is removed — it could
  # never build. If a specific firmware is later proven missing on real hardware,
  # add a narrowly-scoped override with a real hash then (Phase 5/7).
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

  # First-install anchor for this never-installed host (NOT a bump on an existing
  # machine). Per-host on purpose: a revived ThinkPad keeps its own value.
  system.stateVersion = "26.05";
}
