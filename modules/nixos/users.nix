# The dhilipsiva user account. Declarative (mutableUsers = false).
{ pkgs, ... }:

{
  users.mutableUsers = false;
  users.users.dhilipsiva = {
    isNormalUser = true;
    createHome = true;
    extraGroups = [ "docker" "input" "kvm" "networkmanager" "dialout" "plugdev" "wheel" ];
    # Plaintext hash kept here for behaviour parity during the refactor. Phase 4
    # replaces it with a sops hashedPasswordFile (mutableUsers = false requires
    # sops `neededForUsers = true` so it decrypts before user creation).
    hashedPassword = "$6$3TFqdE8hE9Hr9RS.$vd5EFAbzbHXn9qdQRRYtuwHyauBv/m1j.qe7LMo5tmz7KKhRZ1Fao8rS3BNPcS6f0yE4cOFHvf8ofcjzzkT671";
    shell = pkgs.fish;
  };

  # The login shell is fish, so it must be enabled system-wide.
  programs.fish.enable = true;
}
