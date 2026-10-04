{ lib, pkgs, ... }:
{
  services.power-profiles-daemon.enable = true;
  services.thermald.enable = true;
  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
  # PPD starts balanced on a new installation and preserves subsequent user choices.
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
  swapDevices = [ ];
  # The installer left an 8.8 GiB swap partition on the SSD. The systemd GPT
  # auto-generator activates every swap-typed partition on the root disk unless
  # told otherwise, so zram stays the only swap and the partition is untouched.
  boot.kernelParams = [ "systemd.swap=0" ];
  zramSwap = {
    enable = true;
    swapDevices = 1;
    algorithm = "zstd";
    memoryPercent = 25;
    priority = 100;
    writebackDevice = null;
  };
  boot.kernel.sysctl."vm.swappiness" = 180;
  home-manager.users.dhilipsiva = {
    repo.waybar.battery.enable = true;
    home.packages = [ pkgs.brightnessctl ];
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
            (lib.generators.mkLuaInline "hl.dsp.exec_cmd(${builtins.toJSON "${pkgs.brightnessctl}/bin/brightnessctl --class backlight set ${binding.amount}"})")
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
