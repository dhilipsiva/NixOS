# Shared Hyprland session. Host modules own GPU and idle/power policy.
{ lib, pkgs, ... }:

let
  lua = lib.generators.mkLuaInline;
  bind = key: action: { _args = [ key (lua action) ]; };
  exec = command: "hl.dsp.exec_cmd(${builtins.toJSON command})";
  app = command: exec "${pkgs.uwsm}/bin/uwsm app -- ${command}";
  lock = "${pkgs.procps}/bin/pidof hyprlock || ${pkgs.hyprlock}/bin/hyprlock";
  directions = [
    { key = "H"; direction = "left"; }
    { key = "J"; direction = "down"; }
    { key = "K"; direction = "up"; }
    { key = "L"; direction = "right"; }
  ];
in
{
  wayland.windowManager.hyprland = {
    enable = true;
    # NixOS installs the compositor and its matching portal. UWSM owns systemd
    # session startup/shutdown, so do not run a second HM session manager.
    package = null;
    portalPackage = null;
    systemd.enable = false;
    configType = "lua";
    settings = {
      monitor = [ { output = ""; mode = "preferred"; position = "auto"; scale = "auto"; } ];
      config = {
        general = {
          layout = "dwindle";
          gaps_in = 4;
          gaps_out = 4;
          border_size = 2;
          col = {
            active_border = { colors = [ "rgb(61afef)" ]; angle = 0; };
            inactive_border = "rgb(3b4048)";
          };
        };
        dwindle.preserve_split = true;
        # Immediate window/workspace changes; retain the useful focus border.
        animations.enabled = false;
        decoration = {
          rounding = 0;
          blur.enabled = false;
          shadow.enabled = false;
          glow.enabled = false;
          active_opacity = 1.0;
          inactive_opacity = 1.0;
          fullscreen_opacity = 1.0;
          dim_inactive = false;
        };
        render.ctm_animation = 0;
        # Hyprland 0.56 keeps VFR under debug, not the old misc namespace.
        # Render on damage instead of continuously redrawing an idle desktop.
        debug.vfr = true;
        input = {
          kb_layout = "us";
          follow_mouse = 1;
          touchpad.natural_scroll = true;
        };
        misc = {
          disable_hyprland_logo = true;
          disable_splash_rendering = true;
          background_color = "rgb(1e222a)";
          mouse_move_enables_dpms = true;
          key_press_enables_dpms = true;
        };
      };
      bind = [
        (bind "SUPER + RETURN" (app "${pkgs.alacritty}/bin/alacritty"))
        (bind "SUPER + D" (app "${pkgs.fuzzel}/bin/fuzzel"))
        (bind "SUPER + SHIFT + Z" (app "${pkgs.zed-editor}/bin/zeditor"))
        (bind "SUPER + SHIFT + F" (app "${pkgs.kdePackages.dolphin}/bin/dolphin"))
        (bind "SUPER + CTRL + L" (exec lock))
        (bind "SUPER + SHIFT + Q" "hl.dsp.window.close()")
        (bind "SUPER + F" ''hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" })'')
        (bind "SUPER + SHIFT + SPACE" ''hl.dsp.window.float({ action = "toggle" })'')
        (bind "SUPER + V" ''hl.dsp.layout("togglesplit")'')
        (bind "SUPER + SHIFT + E" (exec "${pkgs.uwsm}/bin/uwsm stop"))
        (bind "Print" (exec "${pkgs.grim}/bin/grim -g \"$(${pkgs.slurp}/bin/slurp)\" - | ${pkgs.wl-clipboard}/bin/wl-copy"))
        (bind "XF86AudioRaiseVolume" (exec "${pkgs.wireplumber}/bin/wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"))
        (bind "XF86AudioLowerVolume" (exec "${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"))
        (bind "XF86AudioMute" (exec "${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))
        { _args = [ "SUPER + mouse:272" (lua "hl.dsp.window.drag()") { mouse = true; } ]; }
        { _args = [ "SUPER + mouse:273" (lua "hl.dsp.window.resize()") { mouse = true; } ]; }
      ] ++ lib.concatMap (d: [
        (bind "SUPER + ${d.key}" ''hl.dsp.focus({ direction = "${d.direction}" })'')
        (bind "SUPER + SHIFT + ${d.key}" ''hl.dsp.window.move({ direction = "${d.direction}" })'')
      ]) directions ++ lib.concatMap (workspace:
        let key = if workspace == 10 then "0" else toString workspace;
        in [
          (bind "SUPER + ${key}" "hl.dsp.focus({ workspace = ${toString workspace} })")
          (bind "SUPER + SHIFT + ${key}" "hl.dsp.window.move({ workspace = ${toString workspace}, follow = false })")
        ]
      ) (lib.range 1 10);
    };
  };

  programs.fuzzel = {
    enable = true;
    settings.main = {
      terminal = "${pkgs.alacritty}/bin/alacritty -e";
      launch-prefix = "${pkgs.uwsm}/bin/uwsm app --";
      layer = "overlay";
      font = "Fira Code:size=12";
    };
  };

  services.mako = {
    enable = true;
    settings = { default-timeout = 5000; font = "Fira Code 11"; };
  };

  programs.hyprlock = {
    enable = true;
    settings = {
      general = { hide_cursor = true; ignore_empty_input = true; };
      animations.enabled = false;
      background = [ { monitor = ""; color = "rgba(1e222aff)"; blur_passes = 0; } ];
      input-field = [ {
        monitor = "";
        size = "300, 50";
        position = "0, -80";
        font_family = "Fira Code";
        rounding = 0;
        shadow_passes = 0;
        fade_on_empty = false;
        inner_color = "rgba(282c34ff)";
        outer_color = "rgba(61afefff)";
        font_color = "rgba(abb2bfff)";
      } ];
    };
  };
  services.hypridle = {
    enable = true;
    systemdTarget = "graphical-session.target";
    settings.general = {
      lock_cmd = lock;
      before_sleep_cmd = "${pkgs.systemd}/bin/loginctl lock-session";
      after_sleep_cmd = "${pkgs.hyprland}/bin/hyprctl dispatch 'hl.dsp.dpms({ action = \"enable\" })'";
    };
    # hosts/<host>/power.nix supplies idle listeners for its workload/battery policy.
  };

  systemd.user.services.polkit-agent = {
    Unit = {
      Description = "Graphical authentication agent";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
