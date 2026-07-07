# sops-nix base wiring, shared by all hosts.
#
# INVARIANTS:
# - Only PUBLIC age recipients (.sops.yaml) and ENCRYPTED files (secrets/*.yaml)
#   are ever committed. No private key lives in the repo (see .gitignore).
# - defaultSopsFile MUST always point at an ENCRYPTED sops file, never a plaintext.
# - Decrypted material only ever lands under /run/secrets{,-for-users} (tmpfs, root-owned).
# - Keep the classic (perl) activation path: do NOT enable services.userborn /
#   systemd.sysusers. The break-glass "boot continues even if a secret fails to
#   decrypt" property depends on the non-`set -e` activation script. The build-vm
#   variant (hosts/desktop) overrides sopsFile to secrets/vm-test.yaml and injects
#   a throwaway host key to exercise this exact path headlessly.
{ ... }:

{
  # Real, age-encrypted secrets (owner-managed; created/edited only by the owner
  # with their operator age key — the agent never encrypts to this file).
  sops.defaultSopsFile = ../../secrets/secrets.yaml;
  sops.defaultSopsFormat = "yaml";

  # Real-hardware key source: the machine's ed25519 SSH host key is converted to
  # an age identity at boot, so the host self-decrypts (no key material committed).
  # Requires /etc/ssh/ssh_host_ed25519_key to exist on PERSISTENT storage — if
  # impermanence is ever adopted, that path must be persisted or every boot loses
  # the key and locks out. hosts/desktop enables services.openssh to generate it.
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  # Login password. neededForUsers => decrypt to /run/secrets-for-users BEFORE
  # user creation, which is MANDATORY under users.mutableUsers = false. sops-nix
  # forces this secret root:root 0400 (users don't exist yet); do not set owner.
  sops.secrets."dhilipsiva/hashedPassword".neededForUsers = true;
}
