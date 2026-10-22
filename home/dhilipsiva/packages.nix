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
    # The portfolio's workstation toolchain: only what no repository's own `nix develop`
    # supplies (checked 2026-10-22; cargo-component, mdbook, trunk, sops and age come from
    # those shells). just, gh and git-lfs also serve repositories without a flake.
    just
    gh
    git-lfs
    cargo-nextest
    cargo-audit
    cargo-llvm-cov
    cargo-mutants
    cargo-fuzz
    wac-cli
    wasm-tools
    wasmtime
    tree-sitter
    pandoc
    poppler-utils

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
