# Declarative accounts (mutableUsers = false). userborn replaces the perl user
# activation script; sops-nix detects it and installs the login hash from a
# systemd unit ordered before userborn.service (see sops.nix).
{ config, pkgs, ... }:

{
  users.mutableUsers = false;
  services.userborn.enable = true;

  users.users.dhilipsiva = {
    isNormalUser = true;
    # kvm: virtual machines; networkmanager: connection editing; dialout:
    # serial boards; wheel: sudo. Containers are rootless, so no docker group.
    extraGroups = [
      "kvm"
      "networkmanager"
      "dialout"
      "wheel"
    ];
    # Password hash from sops (/run/secrets-for-users); no hash in the repo.
    hashedPasswordFile = config.sops.secrets."dhilipsiva/hashedPassword".path;
    shell = pkgs.fish;
  };

  # The login shell is fish, so it must be enabled system-wide. The 26.05
  # manpage-completion generator expects a Python helper that fish 4.9 removed.
  programs.fish.enable = true;
  programs.fish.generateCompletions = false;

  # Memory-safe sudo. Only wheel members can run it, with their own password.
  security.sudo-rs = {
    enable = true;
    execWheelOnly = true;
  };
}
