{ lib, pkgs, ... }:

{
  services.power-profiles-daemon.enable = true;
  services.thermald.enable = true;
  services.logind.settings.Login = {
    IdleAction = "ignore";
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "suspend";
    HandleLidSwitchDocked = "ignore";
    HandleSuspendKey = "suspend";
    HandleHibernateKey = "ignore";
    LidSwitchIgnoreInhibited = false;
  };
  systemd.sleep.settings.Sleep = {
    AllowSuspend = true;
    AllowHibernation = false;
    AllowHybridSleep = false;
    AllowSuspendThenHibernate = false;
  };
  environment.systemPackages = [ pkgs.brightnessctl ];
  home-manager.users.dhilipsiva = {
    repo.waybar.battery.enable = true;
    services.hypridle.settings.listener = [
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
    wayland.windowManager.hyprland.settings.bind =
      map
        (binding: {
          _args = [
            binding.key
            (lib.generators.mkLuaInline "hl.dsp.exec_cmd(${builtins.toJSON "${pkgs.brightnessctl}/bin/brightnessctl -d intel_backlight set ${binding.amount}"})")
          ];
        })
        [
          {
            key = "XF86MonBrightnessUp";
            amount = "+5%";
          }
          {
            key = "XF86MonBrightnessDown";
            amount = "5%-";
          }
        ];
  };
}
