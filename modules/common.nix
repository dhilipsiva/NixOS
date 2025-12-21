{ config, pkgs, ... }:

{
  # --- NIX SETTINGS ---
  nix.settings.experimental-features = [ "nix-command" "flakes" ]; [cite: 2]
  nix.gc = {
    automatic = true;
    dates = "daily";
    options = "--delete-older-than 7d";
  }; [cite: 3]
  nixpkgs.config = {
    allowUnfree = true;
    android_sdk.accept_license = true;
  }; [cite: 5]

  # --- LOCALE & TIME ---
  time.timeZone = "Asia/Kolkata"; [cite: 26]
  i18n.defaultLocale = "en_IN";
  console.keyMap = "us";

  # --- USER & SECURITY ---
  users.mutableUsers = false;
  users.users.dhilipsiva = {
    isNormalUser = true;
    createHome = true;
    extraGroups = [ "adbusers" "docker" "input" "kvm" "networkmanager" "dialout" "plugdev" "wheel" ]; [cite: 11]
    hashedPassword = "$6$3TFqdE8hE9Hr9RS.$vd5EFAbzbHXn9qdQRRYtuwHyauBv/m1j.qe7LMo5tmz7KKhRZ1Fao8rS3BNPcS6f0yE4cOFHvf8ofcjzzkT671"; [cite: 12]
    shell = pkgs.fish;
  };

  security.polkit.enable = true; [cite: 8]
  services.gnome.gnome-keyring.enable = true; [cite: 32]

  # --- NETWORKING & BLOCKLISTS ---
  networking.networkmanager.enable = true;
  networking.firewall.allowedTCPPorts = [ 8080 ]; [cite: 42]
  networking.hosts = {
    "127.0.0.1" = [ "reddit.com" "www.reddit.com" ]; # Keeping your Focus Mode [cite: 43]
  };

  # --- AUDIO & HARDWARE ---
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
    jack.enable = false;
  }; [cite: 35]
  services.pulseaudio.enable = false; [cite: 29]
  
  hardware.opentabletdriver = { enable = true; daemon.enable = true; }; [cite: 41]
  programs.adb.enable = true; [cite: 20]
  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ATTR{idVendor}=="18d1", ATTR{idProduct}=="4ee7", MODE="0660", GROUP="plugdev"
  ''; [cite: 37]

  # --- CUSTOM SERVICES (Ported from your config) ---
  systemd.timers."backup-nix-config" = {
    wantedBy = [ "timers.target" ];
    timerConfig = { OnCalendar = "*-*-* *:00:00"; Persistent = true; };
  }; [cite: 21]
  systemd.services."backup-nix-config" = {
    serviceConfig.ExecStart = "${pkgs.coreutils}/bin/cp -r /etc/nixos/configuration.nix /home/dhilipsiva/dotfiles/configuration_backup.nix";
  }; [cite: 22]

  systemd.timers."show-time-notification" = {
    wantedBy = [ "timers.target" ];
    timerConfig = { OnCalendar = "-*-* *:00,15,30,45:00"; Persistent = true; };
  }; [cite: 24]
  systemd.services."show-time-notification" = {
    serviceConfig.ExecStart = "/home/dhilipsiva/.files/scripts/show_time_notification.sh"; # Ensure this path exists!
  }; [cite: 26]

  # --- PROGRAMS ---
  programs.hyprland.enable = true;
  programs.nix-ld.enable = true; # Critical for running random binaries (VSCode server, etc) [cite: 19]
  programs.dconf.enable = true;
  programs.fish.enable = true;
  virtualisation.docker = { enable = true; enableOnBoot = false; }; [cite: 51]

  # --- PACKAGES (Your complete legacy list) ---
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
    docker bruno discord openconnect openssh
    arduino-ide copilot-cli code-cursor codex
    ssm-session-manager-plugin wasm-pack watchman
    typescript-language-server difftastic
    
    # Desktop / GUI
    rofi waybar dunst mako grim slurp wl-clipboard flameshot
    firefox
    
    # Wine / Gaming
    lutris wineWowPackages.stable winetricks vulkan-tools
  ]; [cite: 45, 46, 47, 48]

  # --- ENVIRONMENT VARIABLES ---
  environment.variables = {
    EDITOR = "hx";
    VISUAL = "hx";
    XDG_CONFIG_HOME = "/home/dhilipsiva/.files/.config";
    # Removed DRI_PRIME=1 because on Desktop your monitor is directly connected to the GPU
  }; [cite: 49]
  
  system.stateVersion = "24.11"; [cite: 6]
}
