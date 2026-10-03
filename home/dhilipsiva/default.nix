{ pkgs, ... }:

{
  imports = [
    ./shells.nix # fish, bash, starship, atuin
    ./git.nix
    ./terminal.nix # alacritty + zellij
    ./helix.nix
    ./wayland.nix # native Hyprland + Waybar + notifications/locking
    ./services.nix # user timers (time notification)
  ];

  home.username = "dhilipsiva";
  home.homeDirectory = "/home/dhilipsiva";
  xdg.desktopEntries.microsoft-teams = {
    name = "Microsoft Teams";
    comment = "Official Teams web app";
    exec = "${pkgs.google-chrome}/bin/google-chrome-stable --ozone-platform=wayland --app=https://teams.microsoft.com/";
    terminal = false;
    categories = [ "Network" "InstantMessaging" ];
    icon = "google-chrome";
  };
  # home.stateVersion is set by hosts/<host>/default.nix for each installation.

  # Keep cloud-agent authentication separate from the local Ollama endpoint.
  # A global OPENAI_BASE_URL/API_KEY override would redirect normal API clients.
}
