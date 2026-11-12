{ pkgs, ... }:
let
  sober = "${pkgs.flatpak}/bin/flatpak run --branch=stable --arch=x86_64 --command=sober --env=__NV_PRIME_RENDER_OFFLOAD=1 --env=__VK_LAYER_NV_optimus=NVIDIA_only --env=__GLX_VENDOR_LIBRARY_NAME=nvidia --talk-name=com.feralinteractive.GameMode org.vinegarhq.Sober";
in
{
  services.flatpak.enable = true;
  programs.gamemode.enable = true;
  users.users.dhilipsiva.extraGroups = [ "gamemode" ];
  repo.maintenance.flatpakApps = [ "org.vinegarhq.Sober" ];

  home-manager.users.dhilipsiva = { lib, ... }: {
    # The same desktop ID replaces the exported launcher without a duplicate.
    # GPU selection is confined to this application; Wayland remains preferred.
    xdg.desktopEntries."org.vinegarhq.Sober" = {
      name = "Roblox (Sober)";
      genericName = "Roblox Player";
      comment = "Play Roblox on the NVIDIA GPU";
      exec = "${sober} %u";
      icon = "org.vinegarhq.Sober";
      terminal = false;
      categories = [ "Game" ];
      mimeType = [
        "x-scheme-handler/roblox"
        "x-scheme-handler/roblox-player"
      ];
      settings = {
        Keywords = "Roblox;Sober;";
        PrefersNonDefaultGPU = "true";
        X-Flatpak = "org.vinegarhq.Sober";
      };
      actions.open-settings = {
        name = "Settings";
        exec = "${sober} config";
      };
    };
    xdg.mimeApps.defaultApplications = {
      "x-scheme-handler/roblox" = [ "org.vinegarhq.Sober.desktop" ];
      "x-scheme-handler/roblox-player" = [ "org.vinegarhq.Sober.desktop" ];
    };
    # A writable first-run configuration; subsequent in-app choices are kept.
    home.activation.seedDesktopSober = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      settings="$HOME/.var/app/org.vinegarhq.Sober/config/sober/config.json"
      if [ ! -e "$settings" ]; then
        run mkdir -p "$(dirname "$settings")"
        run cp ${
          pkgs.writeText "sober-desktop-defaults.json" (
            builtins.toJSON {
              use_opengl = false;
              enable_gamemode = true;
              enable_hidpi = true;
              graphics_optimization_mode = "quality";
            }
          )
        } "$settings"
        run chmod u+w "$settings"
      fi
    '';
    # Slack starts with the session in Waybar's tray: --startup honours its own
    # "hide on startup" setting. Quitting from the tray keeps it closed.
    systemd.user.services.slack = {
      Unit = {
        Description = "Slack in the system tray";
        Requires = [ "tray.target" ];
        After = [
          "graphical-session.target"
          "tray.target"
        ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${pkgs.slack}/bin/slack --startup";
        Restart = "on-failure";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
