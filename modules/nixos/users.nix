# The dhilipsiva user account. Declarative (mutableUsers = false).
{ config, pkgs, ... }:

{
  users.mutableUsers = false;
  users.users.dhilipsiva = {
    isNormalUser = true;
    createHome = true;
    extraGroups = [ "docker" "input" "kvm" "networkmanager" "dialout" "plugdev" "wheel" ];
    # Password comes from sops (decrypted to /run/secrets-for-users BEFORE user
    # creation via neededForUsers — see modules/nixos/sops.nix). No plaintext hash
    # in the repo. The value is set by the owner in secrets/<host>.yaml.
    hashedPasswordFile = config.sops.secrets."dhilipsiva/hashedPassword".path;
    shell = pkgs.fish;
  };

  # The login shell is fish, so it must be enabled system-wide.
  programs.fish.enable = true;
  # The 26.05 generator expects a Python helper removed in current stable fish.
  # Keep fish's built-in/vendor completions without that obsolete build step.
  programs.fish.generateCompletions = false;
}
