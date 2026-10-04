# Nix daemon settings and scheduled store/log/temp-file maintenance.
{ inputs, pkgs, ... }:

{
  nix = {
    # Newest stable Nix release; the OS itself follows the release branch.
    package = pkgs.nixVersions.latest;
    settings = {
      # Persistently enable the modern CLI/flakes; no per-command feature flags.
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      # Per-user profiles and state follow the XDG base directories instead of
      # ~/.nix-profile and ~/.nix-defexpr.
      use-xdg-base-directories = true;
      # Development shells (direnv/nix-direnv) survive garbage collection.
      keep-outputs = true;
      keep-derivations = true;
      extra-substituters = [ "https://nix-community.cachix.org" ];
      extra-trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
    };
    # Flakes only: nix-channel is removed, and both the flake registry and the
    # legacy `<nixpkgs>` search path resolve to this flake's stable input.
    channel.enable = false;
    registry.nixpkgs.flake = inputs.nixpkgs;
    nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
    gc = {
      automatic = true;
      dates = "*-*-* 22:00:00 Asia/Colombo";
      options = "--delete-older-than 30d";
      persistent = true;
    };
    optimise = {
      automatic = true;
      dates = [ "Sun *-*-* 22:30:00 Asia/Colombo" ];
      randomizedDelaySec = "5min";
      persistent = true;
    };
  };
  # command-not-found depends on the channel database that no longer exists.
  programs.command-not-found.enable = false;

  systemd.services.nix-gc.serviceConfig = {
    Nice = 19;
    CPUWeight = 10;
    IOWeight = 10;
    IOSchedulingClass = "idle";
  };
  systemd.services.nix-optimise.after = [ "nix-gc.service" ];

  # /tmp lives in memory and is discarded at every start-up (Nix builds use
  # their own directory under /nix/var). /var/tmp stays on disk and ages out.
  boot.tmp.useTmpfs = true;
  systemd.tmpfiles.settings."10-tmp-retention"."/var/tmp".q = {
    mode = "1777";
    user = "root";
    group = "root";
    age = "30d";
  };

  # Journald rotates automatically; never sweep home directories, models, or
  # project caches.
  services.journald.extraConfig = ''
    SystemMaxUse=1G
    SystemKeepFree=5G
    MaxRetentionSec=30day
  '';

  nixpkgs.config = {
    allowUnfree = true;
    android_sdk.accept_license = true;
  };
}
