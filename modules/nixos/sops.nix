# sops-nix base wiring, shared by all hosts.
#
# INVARIANTS:
# - Only PUBLIC age recipients (.sops.yaml) and ENCRYPTED files (secrets/*.yaml)
#   are ever committed. No private key lives in the repo (see .gitignore).
# - defaultSopsFile MUST always point at an ENCRYPTED sops file, never a plaintext.
# - Decrypted material only ever lands under /run/secrets{,-for-users} (tmpfs,
#   root-owned).
# - Users are managed by userborn (users.nix), so sops-nix installs secrets from
#   systemd units: sops-install-secrets-for-users.service runs before
#   userborn.service and the regular secrets follow after it. A decryption
#   failure fails those units while start-up continues; the previous
#   /etc/shadow remains and the protected recovery entry is the fallback.
#   `nixosctl stage` verifies that the real host identity decrypts the secrets
#   before anything is staged.
# - The build-vm variant (hosts/desktop) overrides sopsFile to secrets/vm-test.yaml
#   and injects a throwaway host key to exercise this exact path headlessly.
{ ... }:

{
  # Each host sets defaultSopsFile to its owner-managed, age-encrypted file.
  # Never reuse the desktop's host identity or a VM test key on the ThinkPad.

  # Real-hardware key source: the machine's ed25519 SSH host key is converted to
  # an age identity at start-up, so the host self-decrypts (no key material
  # committed). Requires /etc/ssh/ssh_host_ed25519_key on PERSISTENT storage;
  # hosts/desktop enables services.openssh to generate it.
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  # Login password. neededForUsers => decrypt to /run/secrets-for-users BEFORE
  # user creation, which is MANDATORY under users.mutableUsers = false. sops-nix
  # forces this secret root:root 0400 (users don't exist yet); do not set owner.
  sops.secrets."dhilipsiva/hashedPassword".neededForUsers = true;
}
