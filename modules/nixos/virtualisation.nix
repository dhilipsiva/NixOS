# Rootless containers and non-Nix dynamic binaries.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (pkgs.claude-desktop) cowork;
in

{
  # Docker runs as the user inside user namespaces; DOCKER_HOST points clients
  # at the per-user socket. No docker group and no root-equivalent daemon.
  virtualisation.docker.rootless = {
    enable = true;
    setSocketVariable = true;
  };
  # The module starts the daemon in every non-root user session, including the
  # greeter's, which has no subordinate ID range and fails. Limit it to the owner.
  systemd.user.services.docker.unitConfig.ConditionUser =
    lib.mkForce config.users.users.dhilipsiva.name;

  # Run pre-built dynamically-linked binaries (VS Code server and similar).
  programs.nix-ld.enable = true;

  # Cowork hosts its own QEMU guest. Each host already supplies its CPU's KVM
  # module and the owner belongs to kvm; vsock also needs to survive reboots.
  boot.kernelModules = [ "vhost_vsock" ];
  # The native app probes these Debian paths, then copies the matching VARS
  # template into its private VM data. These are guest firmware, not host UEFI.
  systemd.tmpfiles.rules = [
    "L+ /usr/share/OVMF/OVMF_CODE.fd - - - - ${cowork.firmware}/FV/OVMF_CODE.fd"
    "L+ /usr/share/OVMF/OVMF_CODE_4M.fd - - - - ${cowork.firmware}/FV/OVMF_CODE.fd"
    "L+ /usr/share/OVMF/OVMF_VARS.fd - - - - ${cowork.firmware}/FV/OVMF_VARS.fd"
    "L+ /usr/share/OVMF/OVMF_VARS_4M.fd - - - - ${cowork.firmware}/FV/OVMF_VARS.fd"
    "L+ /usr/libexec/virtiofsd - - - - ${cowork.virtiofsd}/bin/virtiofsd"
  ];

  # Android debugging needs no custom udev rule: systemd's built-in uaccess
  # rules grant the logged-in user access; adb comes from the user's packages.
}
