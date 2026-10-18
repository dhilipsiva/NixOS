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
  };
  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];
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
