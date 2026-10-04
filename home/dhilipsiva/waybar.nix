# Shared, quiet status bar. Host modules opt into laptop-only indicators.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  launch = command: "${pkgs.uwsm}/bin/uwsm app -- ${command}";
  monitor = launch "${pkgs.alacritty}/bin/alacritty -e ${pkgs.btop}/bin/btop";
  mixer = launch "${pkgs.pavucontrol}/bin/pavucontrol";
  lock = "${pkgs.procps}/bin/pidof hyprlock || ${pkgs.hyprlock}/bin/hyprlock";
  failedUnits = pkgs.writeShellScript "show-failed-services" ''
    ${pkgs.systemd}/bin/systemctl --failed --no-pager
    ${pkgs.systemd}/bin/systemctl --user --failed --no-pager
  '';
  # Waybar 0.15's native failed-units module can retain stale state after
  # recovery. Read current counts at a modest interval until that is fixed.
  serviceHealth = pkgs.writeShellApplication {
    name = "waybar-service-health";
    runtimeInputs = [ pkgs.systemd ];
    text = ''
      if ! system_failed=$(systemctl show -p NFailedUnits --value) ||
         ! user_failed=$(systemctl --user show -p NFailedUnits --value) ||
         [[ ! "$system_failed" =~ ^[0-9]+$ || ! "$user_failed" =~ ^[0-9]+$ ]]; then
        printf '%s\n' '{"text":"Services ?","tooltip":"Service status unavailable; click for details","class":"warning"}'
        exit 0
      fi
      total=$((system_failed + user_failed))
      if (( total == 0 )); then
        printf '%s\n' '{"text":""}'
      else
        printf '{"text":"⚠ %s","tooltip":"%s system / %s user services failed; click for details","class":"critical"}\n' \
          "$total" "$system_failed" "$user_failed"
      fi
    '';
  };
in
{
  options.repo.waybar.battery.enable = lib.mkEnableOption "the laptop battery indicator";

  config.programs.waybar = {
    enable = true;
    systemd.enable = true; # bound to the default graphical-session.target
    settings.mainBar = {
      layer = "top";
      position = "bottom";
      height = 30; # logical pixels; the compositor scale enlarges the bar
      spacing = 4;
      # Let the center yield space to controls on narrower laptop screens.
      fixed-center = false;
      modules-left = [
        "custom/launcher"
        "hyprland/workspaces"
        "hyprland/submap"
        "hyprland/window"
      ];
      modules-center = [ "clock" ];
      modules-right = [
        "custom/services"
        "cpu"
        "memory"
        "disk"
        "network"
        "pulseaudio"
      ]
      ++ lib.optional config.repo.waybar.battery.enable "battery"
      ++ [
        "tray"
        "custom/lock"
      ];

      "custom/launcher" = {
        format = "󰀻  Apps";
        tooltip-format = "Open applications · Super+D";
        on-click = launch "${pkgs.fuzzel}/bin/fuzzel";
      };
      "hyprland/workspaces" = {
        format = "{id}";
        disable-scroll = true;
        all-outputs = false;
        persistent-workspaces."*" = 5;
      };
      "hyprland/submap".tooltip = false;
      "hyprland/window" = {
        max-length = 28;
        separate-outputs = true;
      };
      clock = {
        # Full date and time in the bar centre; the tooltip adds the calendar.
        interval = 1;
        format = "{:%a %d %b %Y   %H:%M:%S}";
        tooltip-format = "<b>{:%A, %d %B %Y}</b>\n<tt>{calendar}</tt>";
        calendar = {
          mode = "month";
          on-scroll = 1;
          format.today = "<span color='#89b4fa'><b><u>{}</u></b></span>";
        };
        actions = {
          on-scroll-up = "shift_up";
          on-scroll-down = "shift_down";
        };
      };
      cpu = {
        interval = 5;
        format = "CPU {usage:2}%";
        states = {
          warning = 80;
          critical = 95;
        };
        on-click = monitor;
      };
      memory = {
        interval = 5;
        format = "RAM {percentage:2}%";
        tooltip-format = "{used:.1f} / {total:.1f} GiB used\n{avail:.1f} GiB available\nClick to open system monitor";
        states = {
          warning = 80;
          critical = 95;
        };
        on-click = monitor;
      };
      disk = {
        path = "/";
        interval = 60;
        format = "SSD {percentage_used:2}%";
        tooltip-format = "Root filesystem\n{free} available / {total} total\nClick to open files";
        states = {
          warning = 85;
          critical = 95;
        };
        on-click = launch "${pkgs.kdePackages.dolphin}/bin/dolphin";
      };
      network = {
        interval = 10;
        format-wifi = "  {signalStrength}%";
        format-ethernet = "󰈀  Wired";
        format-linked = "󰈀  No IP";
        format-disconnected = "󰤭  Offline";
        tooltip-format-wifi = "{essid}\n{ifname} · {ipaddr}\nSignal {signalStrength}% · {frequency} GHz\nClick to edit connections";
        tooltip-format-ethernet = "{ifname} · {ipaddr}\nClick to edit connections";
        tooltip-format-disconnected = "No network connection\nClick to edit connections";
        on-click = launch "${pkgs.networkmanagerapplet}/bin/nm-connection-editor";
      };
      pulseaudio = {
        format = "{icon} {volume}%";
        format-muted = "󰝟  Mute";
        format-icons.default = [
          "󰕿"
          "󰖀"
          "󰕾"
        ];
        tooltip-format = "{desc}\nClick: audio settings · Right-click: mute\nScroll: volume";
        scroll-step = 2;
        max-volume = 100;
        on-click = mixer;
        on-click-right = "${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
      };
      battery = {
        interval = 30;
        format = "{icon} {capacity}%";
        format-charging = "󰂄 {capacity}%";
        format-plugged = "󰚥 {capacity}%";
        format-icons = [
          "󰁺"
          "󰁼"
          "󰁾"
          "󰂀"
          "󰁹"
        ];
        states = {
          warning = 25;
          critical = 10;
        };
        tooltip-format = "{capacity}% · {time}\nBattery health: {health}%";
      };
      "custom/services" = {
        exec = lib.getExe serviceHealth;
        interval = 30;
        return-type = "json";
        hide-empty-text = true;
        on-click = launch "${pkgs.alacritty}/bin/alacritty --hold -e ${failedUnits}";
      };
      tray = {
        spacing = 10;
        icon-size = 18;
      };
      "custom/lock" = {
        format = "󰌾";
        tooltip-format = "Lock screen · Super+Ctrl+L";
        on-click = lock;
      };
    };
    style = ''
      * {
        font-family: "FiraCode Nerd Font", "Fira Code", sans-serif;
        font-size: 12px;
        min-height: 0;
        border: none;
        border-radius: 0;
        animation: none;
        transition: none;
        box-shadow: none;
        text-shadow: none;
      }
      window#waybar {
        background: #161b22;
        color: #d6deeb;
        border-top: 1px solid #303a49;
      }
      tooltip {
        background: #1e2632;
        border: 1px solid #45546a;
      }
      tooltip label { padding: 8px; color: #e6edf3; }
      .modules-left { margin-left: 6px; }
      .modules-right { margin-right: 6px; }
      #custom-launcher, #custom-lock, #submap, #clock, #cpu, #memory,
      #disk, #network, #pulseaudio, #battery, #custom-services, #tray {
        padding: 0 10px;
        margin: 4px 0;
      }
      #custom-launcher { color: #89b4fa; font-weight: bold; }
      #workspaces button {
        padding: 0 7px;
        margin: 4px 1px;
        min-width: 18px;
        color: #c2ccdb;
        background: #222c39;
        border-bottom: 2px solid transparent;
      }
      #workspaces button.empty { background: transparent; color: #8794a8; }
      #workspaces button.visible { border-bottom-color: #89b4fa; }
      #workspaces button.active { background: #89b4fa; color: #111821; font-weight: bold; }
      #workspaces button.urgent, #submap { background: #f9e2af; color: #111821; }
      #window { margin-left: 12px; color: #a7b4c8; }
      window#waybar.empty #window { margin: 0; }
      #clock { color: #e6edf3; font-weight: bold; }
      #cpu, #memory, #disk { background: #1e2632; }
      #network { color: #94e2d5; }
      #pulseaudio { color: #b4befe; }
      #pulseaudio.muted { color: #a7b4c8; }
      #cpu.warning, #memory.warning, #disk.warning, #battery.warning,
      #custom-services.warning { color: #f9e2af; }
      #cpu.critical, #memory.critical, #disk.critical, #battery.critical,
      #network.disconnected, #custom-services.critical { color: #f38ba8; }
      #battery.charging, #battery.plugged { color: #a6e3a1; }
      #custom-lock { color: #a7b4c8; border-left: 1px solid #303a49; }
      #workspaces button:hover, #custom-launcher:hover, #custom-lock:hover,
      #cpu:hover, #memory:hover, #disk:hover, #network:hover, #pulseaudio:hover,
      #custom-services:hover { background: #303a49; color: #ffffff; }
    '';
  };
}
