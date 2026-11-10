{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.repo.lucy;
in
{
  options.repo.lucy = {
    enable = lib.mkEnableOption "explicit Lucy desktop integration";
    package = lib.mkOption { type = lib.types.package; };
    backup = {
      enable = lib.mkEnableOption "the recurring private backup of Lucy's memory";
      package = lib.mkOption { type = lib.types.package; };
      host = lib.mkOption {
        type = lib.types.str;
        description = "This host's name; its manifests and extras live under it.";
      };
      peers = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = ''
          The peers a backup may carry besides Lucy's own conversations. Each
          name admits that peer's log, its enrollment and the records indexed
          from its folder; every other peer on the host stays out.
        '';
      };
      checkout = lib.mkOption {
        type = lib.types.str;
        default = "${config.xdg.dataHome}/lucy-private-backup";
        description = "The owner's clone of the private repository, outside every source tree.";
      };
      remote = lib.mkOption {
        type = lib.types.str;
        default = "git@github.com:dhilipsiva/lucy-private.git";
      };
      branch = lib.mkOption {
        type = lib.types.str;
        default = "main";
      };
      onCalendar = lib.mkOption {
        type = lib.types.str;
        default = "hourly";
      };
    };
  };
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !cfg.backup.enable || cfg.backup.peers != [ ];
        message = "repo.lucy.backup.peers must list what the backup carries; an unlisted backup carries every peer.";
      }
    ];
    # The push uses the owner's SSH identity through the keyring agent that the
    # user manager exports. It runs ten minutes after login and then on the
    # hour; a catch-up run at login would start before the network is up.
    systemd.user.services.lucy-backup = lib.mkIf cfg.backup.enable {
      Unit.Description = "Back up Lucy's private memory into its private repository";
      Service = {
        Type = "oneshot";
        ExecStart = lib.escapeShellArgs (
          [
            "${cfg.backup.package}/bin/lucy-backup"
            "run"
            "--lucy"
            "${cfg.package}/bin/lucy"
            "--checkout"
            cfg.backup.checkout
            "--remote"
            cfg.backup.remote
            "--branch"
            cfg.backup.branch
            "--host"
            cfg.backup.host
          ]
          ++ lib.concatMap (peer: [
            "--peer"
            peer
          ]) cfg.backup.peers
        );
        UMask = "0077";
        TimeoutStartSec = "20min";
        Nice = 10;
        IOSchedulingClass = "idle";
      };
    };
    systemd.user.timers.lucy-backup = lib.mkIf cfg.backup.enable {
      Unit.Description = "Private backup of Lucy's memory, on the hour";
      Timer = {
        OnStartupSec = "10min";
        OnCalendar = cfg.backup.onCalendar;
        RandomizedDelaySec = "5min";
      };
      Install.WantedBy = [ "timers.target" ];
    };
    home.packages = [ cfg.package ] ++ lib.optional cfg.backup.enable cfg.backup.package;
    # The old manually installed desktop file shadows the managed entry below.
    # Retain only that known override outside the XDG application search path.
    home.activation.retireLegacyLucyLauncher = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run ${pkgs.python3}/bin/python3 ${../../scripts/retire-legacy-lucy-launcher.py} \
        --home-dir ${lib.escapeShellArg config.home.homeDirectory} \
        --data-dir ${lib.escapeShellArg config.xdg.dataHome} \
        --state-dir ${lib.escapeShellArg config.xdg.stateHome}
    '';
    systemd.user.services.lucy-adapters = {
      Unit = {
        Description = "Enroll Lucy adapters while preserving existing app settings";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${cfg.package}/bin/lucy integrations install";
        UMask = "0077";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
    systemd.user.services.lucy = {
      Unit = {
        Description = "Nibli Lucy private session and memory service";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${cfg.package}/bin/lucy serve";
        Restart = "on-failure";
        UMask = "0077";
        RuntimeDirectory = "lucy";
        RuntimeDirectoryMode = "0700";
        # Inference is unprivileged. polkit handles the exact privileged helpers.
        KillMode = "control-group";
        TimeoutStopSec = 5;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
    xdg.desktopEntries.lucy = {
      name = "Ask Lucy";
      comment = "Start an explicit private conversation";
      exec = "${cfg.package}/bin/lucy ui";
      icon = "system-search";
      terminal = false;
      categories = [ "Utility" ];
    };
    wayland.windowManager.hyprland.settings.bind = [
      {
        _args = [
          "SUPER + ALT + L"
          (lib.generators.mkLuaInline "hl.dsp.exec_cmd('${pkgs.uwsm}/bin/uwsm app -- ${cfg.package}/bin/lucy ui')")
        ];
      }
    ];
    xdg.dataFile."kio/servicemenus/lucy.desktop".text = ''
      [Desktop Entry]
      Type=Service
      MimeType=all/all;
      Actions=askLucy;
      X-KDE-Priority=TopLevel
      [Desktop Action askLucy]
      Name=Ask Lucy about these files
      Icon=system-search
      Exec=${cfg.package}/bin/lucy ui --files %F
    '';
  };
}
