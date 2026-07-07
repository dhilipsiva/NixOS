# TEST-ONLY overlay for the Phase 6 `--vm-test` install rehearsal.
#
# Consumed EXCLUSIVELY by hosts/desktop/disko.nix's `disko.tests.extraConfig`
# (-> config.system.build.installTest). It is NEVER imported by
# ./modules/nixos/default.nix and NEVER part of config.system.build.toplevel, so
# the REAL desktop keeps keyFile=null (interactive LUKS), canTouchEfiVariables=true,
# and defaultSopsFile=secrets/secrets.yaml. (Three post-run `nix eval`s prove this.)
#
# This whole file + keys/vmtest_host_ed25519_key are Phase-6 scaffolding — remove
# them before the real Phase 7 install (see CLEANUP.md).
{ lib, pkgs, ... }:

{
  # (1) EVAL FIX. disko's test harness forces boot.loader.grub.efiInstallAsRemovable
  # = efiSupport (= true) on the installed test system, which asserts against the
  # real canTouchEfiVariables = true. Force it off here (test system ONLY); it also
  # makes grub-install work in the nixos-enter chroot.
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

  # os-prober would try to mount the (empty) virtual disks in the sandbox — noise
  # with no Windows present. Off for the test only.
  boot.loader.grub.useOSProber = lib.mkForce false;

  # (2) SOPS FIX. Decrypt the FAKE vm-test.yaml (recipient = the throwaway &vmtest
  # key only, powerless against the operator-only secrets.yaml), never the real file.
  sops.defaultSopsFile = lib.mkForce ../../secrets/vm-test.yaml;

  # Install the FIXED throwaway host key BEFORE sops runs, so the installed test
  # system self-decrypts via the IDENTICAL real chain (sops.age.sshKeyPaths ->
  # ssh-to-age -> age10hwn… = the sole recipient of vm-test.yaml). Sourced from a
  # committed store path because --vm-test evaluates purely (no --impure / fw_cfg).
  system.activationScripts.injectVmHostKey.text = ''
    mkdir -p /etc/ssh
    install -Dm600 ${../../keys/vmtest_host_ed25519_key} /etc/ssh/ssh_host_ed25519_key
    ${pkgs.openssh}/bin/ssh-keygen -y -f /etc/ssh/ssh_host_ed25519_key > /etc/ssh/ssh_host_ed25519_key.pub
  '';
  system.activationScripts.setupSecretsForUsers.deps = [ "injectVmHostKey" ];
}
