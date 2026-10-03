# Always-on desktop: display power saving must not stop development or inference.
# The ThinkPad should define its own battery/lid/suspend policy.
{ lib, pkgs, ... }:

{
  systemd.sleep.settings.Sleep = {
    AllowSuspend = false;
    AllowHibernation = false;
    AllowHybridSleep = false;
    AllowSuspendThenHibernate = false;
  };
  systemd.targets = {
    sleep.enable = false;
    suspend.enable = false;
    hibernate.enable = false;
    hybrid-sleep.enable = false;
    suspend-then-hibernate.enable = false;
  };
  services.logind.settings.Login = {
    IdleAction = "ignore";
    HandleSuspendKey = "ignore";
    HandleHibernateKey = "ignore";
  };

  home-manager.users.dhilipsiva.services.hypridle.settings.listener = lib.mkForce [
    {
      timeout = 300;
      on-timeout = "${pkgs.procps}/bin/pidof hyprlock || ${pkgs.hyprlock}/bin/hyprlock";
    }
    {
      timeout = 300;
      on-timeout = "${pkgs.hyprland}/bin/hyprctl dispatch 'hl.dsp.dpms({ action = \"disable\" })'";
      on-resume = "${pkgs.hyprland}/bin/hyprctl dispatch 'hl.dsp.dpms({ action = \"enable\" })'";
    }
  ];
}
