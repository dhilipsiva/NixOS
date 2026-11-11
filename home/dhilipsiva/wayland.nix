# Shared Hyprland session. Host modules own GPU, display scale and idle/power policy.
# Colours and type come from QUINE, the site's design system (lib/quine.nix).
{ lib, pkgs, ... }:

let
  quine = import ../../lib/quine.nix;
  inherit (quine) palette font hex;
  rgb = c: "rgb(${c})";
  rgba = c: "rgba(${c}ff)";
  wallpaper = "${pkgs.quine-wallpaper}/quine.png";
  lua = lib.generators.mkLuaInline;
  bind = key: action: {
    _args = [
      key
      (lua action)
    ];
  };
  exec = command: "hl.dsp.exec_cmd(${builtins.toJSON command})";
  app = command: exec "${pkgs.uwsm}/bin/uwsm app -- ${command}";
  lock = "${pkgs.procps}/bin/pidof hyprlock || ${pkgs.hyprlock}/bin/hyprlock";
  directions = [
    {
      key = "H";
      direction = "left";
    }
    {
      key = "J";
      direction = "down";
    }
    {
      key = "K";
      direction = "up";
    }
    {
      key = "L";
      direction = "right";
    }
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
      monitor = [
        {
          output = "";
          mode = "preferred";
          position = "auto";
          scale = "auto";
        }
      ];
      config = {
        general = {
          layout = "dwindle";
          gaps_in = 4;
          gaps_out = 4;
          border_size = 2;
          # QUINE: focus is ember; every other edge is a void hairline.
          col = {
            active_border = {
              colors = [ (rgb palette.ember500) ];
              angle = 0;
            };
            inactive_border = rgb palette.void500;
          };
        };
        group.col = {
          border_active = rgb palette.ember500;
          border_inactive = rgb palette.void500;
        };
        dwindle.preserve_split = true;
        # Immediate window/workspace changes; retain the useful focus border.
        animations.enabled = false;
        decoration = {
          rounding = quine.radius.md;
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
        # X11 clients render at native pixels on scaled outputs (sharp, smaller)
        # instead of being upscaled blurrily by the compositor.
        xwayland.force_zero_scaling = true;
        ecosystem = {
          no_update_news = true;
          no_donation_nag = true;
        };
        input = {
          kb_layout = "us";
          follow_mouse = 1;
          touchpad.natural_scroll = true;
        };
        misc = {
          disable_hyprland_logo = true;
          disable_splash_rendering = true;
          background_color = rgb palette.void1000;
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
        (bind "Print" (
          exec "${pkgs.grim}/bin/grim -g \"$(${pkgs.slurp}/bin/slurp)\" - | ${pkgs.wl-clipboard}/bin/wl-copy"
        ))
        (bind "XF86AudioRaiseVolume" (
          exec "${pkgs.wireplumber}/bin/wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"
        ))
        (bind "XF86AudioLowerVolume" (
          exec "${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
        ))
        (bind "XF86AudioMute" (exec "${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))
        {
          _args = [
            "SUPER + mouse:272"
            (lua "hl.dsp.window.drag()")
            { mouse = true; }
          ];
        }
        {
          _args = [
            "SUPER + mouse:273"
            (lua "hl.dsp.window.resize()")
            { mouse = true; }
          ];
        }
      ]
      ++ lib.concatMap (d: [
        (bind "SUPER + ${d.key}" ''hl.dsp.focus({ direction = "${d.direction}" })'')
        (bind "SUPER + SHIFT + ${d.key}" ''hl.dsp.window.move({ direction = "${d.direction}" })'')
      ]) directions
      ++ lib.concatMap (
        workspace:
        let
          key = if workspace == 10 then "0" else toString workspace;
        in
        [
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
      font = "${font.mono}:size=12";
      prompt = ''"❯ "'';
      width = 44;
      lines = 12;
      horizontal-pad = 20;
      vertical-pad = 14;
      inner-pad = 10;
    };
    settings.colors = {
      background = "${palette.void800}ff";
      text = "${palette.paper200}ff";
      prompt = "${palette.phosphor500}ff";
      placeholder = "${palette.faint}ff";
      input = "${palette.paper100}ff";
      match = "${palette.ember500}ff";
      selection = "${palette.void600}ff";
      selection-text = "${palette.paper100}ff";
      selection-match = "${palette.ember300}ff";
      counter = "${palette.faint}ff";
      border = "${palette.void500}ff";
    };
    settings.border = {
      width = 1;
      radius = quine.radius.md;
    };
  };

  services.mako = {
    enable = true;
    settings = {
      default-timeout = 5000;
      font = "${font.mono} 11";
      background-color = hex palette.void700;
      text-color = hex palette.paper200;
      border-color = hex palette.void500;
      progress-color = "over ${hex palette.ember500}";
      border-size = 1;
      border-radius = quine.radius.md;
      padding = "12,14";
      # Bottom-left, stacked above the bottom waybar; a little larger than
      # mako's 300x100 default (logical pixels, scaled like the bar).
      anchor = "bottom-left";
      width = 400;
      height = 150;
      "urgency=low".text-color = hex palette.muted;
      "urgency=high".border-color = hex palette.crimson;
    };
  };

  # The QUINE wallpaper on every output. swaybg draws it from shared memory; hyprpaper 0.8
  # needs a GPU buffer and crashed on the software renderer of the desktop-login check.
  systemd.user.services.swaybg = {
    Unit = {
      Description = "QUINE wallpaper";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = lib.escapeShellArgs [
        "${pkgs.swaybg}/bin/swaybg"
        "--mode"
        "fill"
        "--color"
        (hex palette.void900)
        "--image"
        wallpaper
      ];
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        hide_cursor = true;
        ignore_empty_input = true;
      };
      animations.enabled = false;
      background = [
        {
          monitor = "";
          path = wallpaper;
          color = rgba palette.void900;
          blur_passes = 0;
        }
      ];
      label = [
        {
          monitor = "";
          text = "// locked";
          font_family = font.mono;
          font_size = 13;
          color = rgba palette.faint;
          position = "0, 260";
          halign = "center";
          valign = "center";
        }
        {
          monitor = "";
          text = "$TIME";
          font_family = font.display;
          font_size = 88;
          color = rgba palette.paper100;
          position = "0, 180";
          halign = "center";
          valign = "center";
        }
      ];
      input-field = [
        {
          monitor = "";
          size = "320, 48";
          position = "0, -150";
          font_family = font.mono;
          rounding = quine.radius.md;
          outline_thickness = 2;
          shadow_passes = 0;
          fade_on_empty = false;
          placeholder_text = "password";
          inner_color = rgba palette.void600;
          outer_color = rgba palette.ember500;
          font_color = rgba palette.paper100;
          check_color = rgba palette.phosphor500;
          fail_color = rgba palette.crimson;
        }
      ];
    };
  };
  services.hypridle = {
    enable = true;
    settings.general = {
      lock_cmd = lock;
      before_sleep_cmd = "${pkgs.systemd}/bin/loginctl lock-session";
      after_sleep_cmd = "${pkgs.hyprland}/bin/hyprctl dispatch 'hl.dsp.dpms({ action = \"enable\" })'";
    };
    # hosts/<host>/power.nix supplies idle listeners for its workload/battery policy.
  };

  # Hyprland's own polkit authentication agent, managed by the Home Manager
  # module and bound to the graphical session that UWSM starts.
  services.hyprpolkitagent.enable = true;
  # Its Qt style (hyprland-qt-support) reads these; colours come from the Qt palette.
  xdg.configFile."hypr/application-style.conf".text = ''
    roundness = 1
    border_width = 1
    reduce_motion = true
  '';
}
