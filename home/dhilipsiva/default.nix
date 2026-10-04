{ pkgs, ... }:

{
  imports = [
    ./shells.nix # fish, starship, atuin, zoxide, direnv
    ./git.nix
    ./terminal.nix # alacritty + zellij
    ./helix.nix
    ./wayland.nix # native Hyprland + notifications/locking/polkit
    ./waybar.nix # shared status bar; optional laptop battery indicator
    ./services.nix # user timers (time notification)
    ./packages.nix # applications and developer tools
  ];

  home.username = "dhilipsiva";
  home.homeDirectory = "/home/dhilipsiva";
  # home.stateVersion is set by hosts/<host>/default.nix for each installation.
  news.display = "silent";

  # Declarative XDG user directories (Documents, Downloads, ...).
  xdg.userDirs = {
    enable = true;
    createDirectories = true;
  };

  # One cursor theme for Hyprland (hyprcursor), GTK and Xwayland clients.
  gtk.enable = true;
  home.pointerCursor = {
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
    size = 24;
    gtk.enable = true;
    hyprcursor.enable = true;
  };
  # Toolkits and portals follow the compositor's dark theme.
  dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";

  xdg.desktopEntries.microsoft-teams = {
    name = "Microsoft Teams";
    comment = "Official Teams web app";
    exec = "${pkgs.google-chrome}/bin/google-chrome-stable --ozone-platform=wayland --app=https://teams.microsoft.com/";
    terminal = false;
    categories = [
      "Network"
      "InstantMessaging"
    ];
    icon = "google-chrome";
  };

  # Keep cloud-agent authentication separate from the local Ollama endpoint.
  # A global OPENAI_BASE_URL/API_KEY override would redirect normal API clients.
}
