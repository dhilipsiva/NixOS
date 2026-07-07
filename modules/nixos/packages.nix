# System-wide package set.
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # Core
    git curl wget tree unzip coreutils gnumake gcc cmake pkg-config
    libnotify libxml2 libinput openssl gnupg seahorse

    # Terminals & Shells
    alacritty fish starship atuin zellij bottom ncdu ripgrep

    # Editors
    helix zed-editor vscode vscode-langservers-extracted

    # Dev Tools
    python3 nodejs_24 rustup rye gcc gnumake
    docker bruno discord openconnect openssh android-tools
    # copilot-cli removed upstream (EOL) — dropped on 26.05; re-add a replacement
    # (e.g. the `gh` copilot extension) if wanted.
    arduino-ide code-cursor codex
    ssm-session-manager-plugin wasm-pack watchman
    typescript-language-server biome difftastic

    # Desktop / GUI
    rofi waybar dunst mako grim slurp wl-clipboard flameshot
    firefox

    # Wine / Gaming
    lutris wineWow64Packages.stable winetricks vulkan-tools
  ];
}
