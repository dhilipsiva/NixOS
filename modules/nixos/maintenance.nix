{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.repo.maintenance;
  ctl = pkgs.callPackage ../../pkgs/nixosctl.nix { };
in
{
  options.repo.maintenance = {
    enable = lib.mkEnableOption "verified, published Git updates staged for manual reboot";
    host = lib.mkOption {
      type = lib.types.str;
      default = "";
    };
    role = lib.mkOption {
      type = lib.types.enum [
        "publisher"
        "subscriber"
      ];
      default = "subscriber";
    };
    owner = lib.mkOption {
      type = lib.types.str;
      default = "dhilipsiva";
    };
    repository = lib.mkOption {
      type = lib.types.str;
      default = "/home/dhilipsiva/projects/dhilipsiva/NixOS";
    };
    remote = lib.mkOption {
      type = lib.types.str;
      default = "https://github.com/dhilipsiva/NixOS.git";
    };
    publishRemote = lib.mkOption {
      type = lib.types.str;
      default = "git@github.com:dhilipsiva/NixOS.git";
    };
    branch = lib.mkOption {
      type = lib.types.str;
      default = "master";
    };
    boardName = lib.mkOption {
      type = lib.types.str;
      description = "Actual DMI board name; capture separately on each host.";
    };
    flatpakApps = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "User Flatpak applications required before staging and acceptance.";
    };
  };
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.host != "";
        message = "Set repo.maintenance.host to this host's flake name.";
      }
    ];
    environment.systemPackages = [ ctl ];
    environment.etc."nixos-repo-host".text = cfg.host + "\n";
    systemd.tmpfiles.settings."10-nixos-deployment"."/var/lib/nixos-deployment".d = {
      mode = "0700";
      user = "root";
      group = "root";
    };
    systemd.services.nixos-update = {
      description = "Publish or sync verified NixOS updates, then stage for manual reboot";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      unitConfig.ConditionPathExists = "/var/lib/nixos-deployment/accepted.json";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${ctl}/bin/nixosctl --repo ${cfg.repository} maintain --host ${cfg.host}";
        UMask = "0077";
        Nice = 10;
        CPUWeight = 25;
        IOWeight = 25;
        IOSchedulingClass = "idle";
        TimeoutStartSec = "6h";
      };
    };
    systemd.timers.nixos-update = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar =
          if cfg.role == "publisher" then "*-*-* 21:00:00 Asia/Colombo" else "*-*-* 21:30:00 Asia/Colombo";
        RandomizedDelaySec = "5min";
        Persistent = true;
      };
    };
    systemd.services.nix-gc = {
      unitConfig.ConditionPathExists = "/var/lib/nixos-deployment/accepted.json";
      serviceConfig.ExecStart = lib.mkForce "${ctl}/bin/nixosctl --repo ${cfg.repository} cleanup";
    };
    systemd.services.nix-optimise.unitConfig.ConditionPathExists =
      "/var/lib/nixos-deployment/accepted.json";
  };
}
