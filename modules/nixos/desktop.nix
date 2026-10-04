# Shared Hyprland Wayland desktop. GPU-specific settings belong to each host.
{ pkgs, ... }:

{
  programs.hyprland = {
    enable = true;
    withUWSM = true;
    # Compatibility for applications that still require X11.
    xwayland.enable = true;
  };
  programs.hyprlock.enable = true; # Includes PAM authentication for unlocking.
  programs.dconf.enable = true;

  services.greetd = {
    enable = true;
    useTextGreeter = true;
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --user-menu --cmd '${pkgs.uwsm}/bin/uwsm start hyprland.desktop'";
      user = "greeter";
    };
  };

  environment.sessionVariables = {
    TERMINAL = "alacritty";
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
    QT_QPA_PLATFORM = "wayland;xcb";
    SDL_VIDEODRIVER = "wayland,x11";
  };

  xdg.portal.enable = true;
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  xdg.portal.config.Hyprland = {
    default = [ "hyprland" "gtk" ];
    "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
  };
  security.polkit.enable = true;
  security.pam.services.greetd.enableGnomeKeyring = true;
  services.gnome.gnome-keyring.enable = true;
  # Hyprland needs a NetworkManager secret agent for saved user connections.
  # The indicator uses Waybar's tray; the editor also supports system-stored
  # Wi-Fi passwords for autoconnect before login. Credentials stay local.
  programs.nm-applet.enable = true;
  # UWSM also runs XDG autostart entries. Let the NixOS systemd user service own
  # this applet, avoiding a second instance without Waybar's indicator mode.
  environment.etc."xdg/autostart/nm-applet.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=NetworkManager Applet
    Hidden=true
  '';
  services.gvfs.enable = true;
  services.udisks2.enable = true;
}
