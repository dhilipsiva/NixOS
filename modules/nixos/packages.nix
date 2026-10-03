# System-wide package set.
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # Core
    git curl wget tree unzip coreutils gnumake gcc cmake pkg-config rsync
    libnotify libxml2 libinput openssl gnupg seahorse

    # Terminals & Shells
    alacritty fish starship atuin zoxide zellij bottom ncdu ripgrep

    # Editors
    helix zed-editor vscode vscode-langservers-extracted

    # Dev Tools
    python-latest nodejs_latest rust-toolchain uv lazygit
    docker bruno discord openconnect openssh android-tools
    # copilot-cli removed upstream (EOL) — dropped on 26.05; re-add a replacement
    # (e.g. the `gh` copilot extension) if wanted.
    arduino-ide code-cursor codex claude-code herdr
    ssm-session-manager-plugin wasm-pack watchman
    typescript-language-server biome difftastic

    # Desktop / GUI
    grim slurp wl-clipboard
    firefox kdePackages.dolphin slack google-chrome

    # Wine / Gaming
    lutris wineWow64Packages.stable winetricks vulkan-tools
  ];
}
