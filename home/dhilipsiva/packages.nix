# Applications and developer tools in the user profile. Programs with their own
# Home Manager module (fish, alacritty, helix, zellij, git, atuin, zoxide,
# starship, direnv, waybar, fuzzel, mako, hyprlock) are enabled in their modules.
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # Terminal tools
    bottom
    ncdu
    ripgrep
    lazygit
    difftastic # git diff.external
    wl-clipboard
    grim
    slurp
    libnotify
    gnupg
    seahorse

    # Editors and AI tooling
    zed-editor
    vscode
    code-cursor
    codex
    claude-code
    herdr

    # Toolchains and build tools
    python-latest
    nodejs_latest
    rust-toolchain
    uv
    gnumake
    gcc
    cmake
    pkg-config
    libxml2
    wasm-pack
    watchman
    android-tools
    arduino-ide
    bruno
    ssm-session-manager-plugin

    # Desktop applications
    firefox
    google-chrome
    kdePackages.dolphin
    slack
    discord

    # Wine / gaming
    lutris
    wineWow64Packages.stable
    winetricks
    vulkan-tools
  ];
}
