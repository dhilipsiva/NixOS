{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ./graphics.nix
    ./performance.nix
    ./applications.nix
    ../../modules/nixos/lucy.nix
    ./power.nix
    ./windows.nix
    ./maintenance.nix
    ./secure-boot.nix
    # nixos-hardware supplies AMD microcode, the NVIDIA video driver selection
    # (-nonprime: one discrete GPU wired to the monitor) and periodic SSD TRIM.
    inputs.nixos-hardware.nixosModules.common-cpu-amd
    inputs.nixos-hardware.nixosModules.common-gpu-nvidia-nonprime
    inputs.nixos-hardware.nixosModules.common-pc-ssd
  ];

  networking.hostName = "dhilipsiva-desktop";

  # On-demand Lucy with Nibli's own model pin; the RTX 5090 holds Qwen3.6
  # 35B-A3B with about 25 GiB of VRAM at peak. The module is imported above in
  # its original position so the desktop's merged lists keep their order.
  repo.lucy.enable = true;

  # Lucy's private memory goes to her private repository on the hour. The list
  # names the peers that belong there; any other peer on this host stays out.
  repo.lucy.backup = {
    enable = true;
    peers = [
      "book"
      "nixos"
      "personal"
    ];
  };

  # Each host selects its encrypted secrets; the ThinkPad can use its own file.
  sops.defaultSopsFile = ../../secrets/desktop.yaml;

  # --- VM-TEST-ONLY OVERRIDES (build-vm variant; ZERO effect on real hardware) ---
  # Everything under virtualisation.vmVariant applies only to the
  # .#nixosConfigurations.desktop.config.system.build.vm attribute, never to the
  # installed system. It makes the desktop configuration bootable headless for
  # rehearsals.
  virtualisation.vmVariant = {
    virtualisation.graphics = false;
    boot.kernelParams = [
      "console=ttyS0,115200n8"
      "console=tty1"
    ];
    systemd.services."serial-getty@ttyS0".enable = true;
    virtualisation.forwardPorts = [
      {
        from = "host";
        host.port = 2222;
        guest.port = 22;
      }
    ];

    # VM-only SSH with a throwaway ROOT PASSWORD as the break-glass: if sops
    # fails to decrypt, dhilipsiva has no password but root still gets a shell
    # to inspect /run/secrets-for-users. dhilipsiva logs in ONLY via the sops path.
    services.openssh.enable = true;
    services.openssh.settings.PermitRootLogin = "yes";
    services.openssh.settings.PasswordAuthentication = lib.mkForce true;
    users.users.root.password = "test";

    # Decrypt the FAKE secrets in the VM (never the owner's real secrets.yaml).
    sops.defaultSopsFile = lib.mkForce ../../secrets/vm-test.yaml;

    # Load qemu_fw_cfg in the initrd so its sysfs is populated before stage-2
    # activation runs.
    boot.initrd.kernelModules = [ "qemu_fw_cfg" ];

    # Inject a throwaway ed25519 host key (passed at RUN time via QEMU -fw_cfg,
    # never committed / never in the store) into /etc/ssh so sops self-decrypts
    # via sops.age.sshKeyPaths, the SAME code path as real hardware. Activation
    # scripts run before systemd starts sops-install-secrets-for-users.service;
    # a missing key must not abort activation (that is the break-glass case).
    system.activationScripts.injectVmHostKey.text = ''
      mkdir -p /etc/ssh
      if [ -e /sys/firmware/qemu_fw_cfg/by_name/opt/vmhostkey/raw ]; then
        cat /sys/firmware/qemu_fw_cfg/by_name/opt/vmhostkey/raw > /etc/ssh/ssh_host_ed25519_key 2>/dev/null || true
        chmod 600 /etc/ssh/ssh_host_ed25519_key 2>/dev/null || true
        ${pkgs.openssh}/bin/ssh-keygen -y -f /etc/ssh/ssh_host_ed25519_key > /etc/ssh/ssh_host_ed25519_key.pub 2>/dev/null || true
      fi
    '';
  };

  # --- SSH / SECRETS KEY SOURCE (real hardware) ---
  # sshd provides the ed25519 host key that sops self-decrypts from
  # (sops.age.sshKeyPaths) and serves the LAN on port 22 so the owner's laptops
  # can reach this machine. Only key authentication is accepted; passwords and
  # keyboard-interactive logins stay off.
  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  # Owner's public key for the daily account and for root recovery; the private
  # key stays outside this repository.
  users.users.dhilipsiva.openssh.authorizedKeys.keyFiles = [ ../../secrets/owner.pub ];
  users.users.root.openssh.authorizedKeys.keyFiles = [ ../../secrets/owner.pub ];

  # --- BOOT ---
  # Preserve the bootloader of the existing installation. Windows keeps its own
  # ESP on the other SSD and remains selectable from the firmware boot menu.
  # systemd runs the initrd (the modern NixOS stage 1); Lanzaboote signs the
  # resulting UKIs (secure-boot.nix) and applies the loader settings below.
  boot.initrd.systemd.enable = true;
  boot.loader = {
    efi = {
      canTouchEfiVariables = true;
      efiSysMountPoint = "/boot";
    };
    systemd-boot = {
      # Bound the number of kernels/initrds retained on the existing 1 GiB ESP.
      configurationLimit = 5;
      # No kernel command-line editing from the menu; readable menu on 4K.
      editor = false;
      consoleMode = "max";
    };
  };

  # --- FIRMWARE ---
  # Redistributable firmware plus nixos-hardware cover the MSI X870E's Qualcomm
  # Wi-Fi. Add a narrowly scoped override only if real hardware proves a gap.
  hardware.enableRedistributableFirmware = true;

  # --- UPS MONITORING (CyberPower) ---
  # Structured NUT schema: an upsd account under `users.<name>` plus a
  # `upsmon.monitor.<name>` entry. The monitor password comes from sops
  # (decrypted to /run/secrets/ups/monitorPassword); restartUnits lets the NUT
  # services pick up the secret.
  sops.secrets."ups/monitorPassword" = {
    owner = "root";
    restartUnits = [
      "upsd.service"
      "upsmon.service"
    ];
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
      upsmon = "primary"; # NUT renamed master/slave -> primary/secondary
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
