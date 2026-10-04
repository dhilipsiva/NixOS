# Rootless containers and non-Nix dynamic binaries.
{ config, lib, ... }:

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

  # Android debugging needs no custom udev rule: systemd's built-in uaccess
  # rules grant the logged-in user access; adb comes from the user's packages.
}
