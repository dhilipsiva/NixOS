# Per-user systemd services/timers.
{ pkgs, ... }:

let
  # The old system-level unit ran scripts/show_time_notification.sh from a
  # hardcoded /home/dhilipsiva/.files path as root (where notify-send can't reach
  # the user session). Ported to a declarative *user* service: the script is built
  # into the Nix store and referenced by store path — no hardcoded path, and it
  # runs inside the graphical session so the notification actually appears.
  showTimeNotification = pkgs.writeShellScript "show-time-notification" ''
    ${pkgs.libnotify}/bin/notify-send "Current Time" "$(${pkgs.coreutils}/bin/date +%H:%M:%S)"
  '';
in
{
  systemd.user.services.show-time-notification = {
    Unit.Description = "Show a notification with the current time";
    Service = {
      Type = "oneshot";
      ExecStart = "${showTimeNotification}";
    };
  };

  systemd.user.timers.show-time-notification = {
    Unit.Description = "Quarter-hourly current-time notification";
    Timer = {
      OnCalendar = "*:00,15,30,45:00";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
