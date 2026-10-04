# Build/evaluation fixture ONLY. Never expose this through nixosConfigurations
# or lib.hosts, and never stage it. Actual UUIDs/DMI/anchors must come from Yoga.
{ lib, ... }:
{
  imports = [ ../hosts/yoga ];
  nixpkgs.hostPlatform = "x86_64-linux";
  networking.hostName = lib.mkForce "yoga-test-fixture";
  fileSystems."/" = {
    device = "/dev/disk/by-label/YOGA-TEST-ONLY";
    fsType = "ext4";
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/YOGA-TEST-ESP";
    fsType = "vfat";
  };
  boot.initrd.luks.devices.root.device = "/dev/disk/by-label/YOGA-TEST-LUKS";
  repo.maintenance.boardName = "YOGA-TEST-ONLY";
  sops.defaultSopsFile = lib.mkForce ../secrets/vm-test.yaml;
  system.stateVersion = "26.05";
  home-manager.users.dhilipsiva.home.stateVersion = "26.05";
}
