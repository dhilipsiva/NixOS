# Nix daemon settings and scheduled store/log/temp-file maintenance.
{ inputs, ... }:

{
  # Persistently enable the modern CLI/flakes; no per-command feature flags.
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.registry.nixpkgs.flake = inputs.nixpkgs;
  nix.nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
  nix.gc = {
    automatic = true;
    dates = "*-*-* 22:00:00 Asia/Colombo";
    options = "--delete-older-than 30d";
    persistent = true;
  };
  nix.optimise = {
    automatic = true;
    dates = [ "Sun *-*-* 22:30:00 Asia/Colombo" ];
    randomizedDelaySec = "5min";
    persistent = true;
  };
  systemd.services.nix-gc.serviceConfig = {
    Nice = 19;
    CPUWeight = 10;
    IOWeight = 10;
    IOSchedulingClass = "idle";
  };
  systemd.services.nix-optimise.after = [ "nix-gc.service" ];

  # Journald rotates automatically. Systemd's existing tmpfiles timer applies
  # the age rules below; never sweep home directories, models, or project caches.
  services.journald.extraConfig = ''
    SystemMaxUse=1G
    SystemKeepFree=5G
    MaxRetentionSec=30day
  '';
  systemd.tmpfiles.rules = [
    "q /tmp 1777 root root 14d"
    "q /var/tmp 1777 root root 30d"
  ];
  nixpkgs.config = {
    allowUnfree = true;
    android_sdk.accept_license = true;
  };
}
