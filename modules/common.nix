{ config, pkgs, ... }:

{
  # --- NIX SETTINGS ---
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.gc = {
    automatic = true;
    dates = "daily";
    options = "--delete-older-than 7d";
  };
  nixpkgs.config = {
    allowUnfree = true;
    android_sdk.accept_license = true;
  };

  # --- LOCALE & TIME ---
  time.timeZone = "Asia/Kolkata";
  i18n.defaultLocale = "en_IN";
  console.keyMap = "us";

  # --- USER & SECURITY ---
  users.mutableUsers = false;
  users.users.dhilipsiva = {
    isNormalUser = true;
    createHome = true;
    extraGroups = [ "docker" "input" "kvm" "networkmanager" "dialout" "plugdev" "wheel" ];
    hashedPassword = "$6$3TFqdE8hE9Hr9RS.$vd5EFAbzbHXn9qdQRRYtuwHyauBv/m1j.qe7LMo5tmz7KKhRZ1Fao8rS3BNPcS6f0yE4cOFHvf8ofcjzzkT671";
    shell = pkgs.fish;
  };

  security.polkit.enable = true;
  services.gnome.gnome-keyring.enable = true;

  # --- NETWORKING & BLOCKLISTS ---
  networking.networkmanager.enable = true;
  networking.firewall.allowedTCPPorts = [ 8080 ];
  networking.hosts = {
    "127.0.0.1" = [ "reddit.com" "www.reddit.com" ]; # Keeping your Focus Mode
  };

  # --- AUDIO & HARDWARE ---
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
    jack.enable = false;
  };
  services.pulseaudio.enable = false;
  
  hardware.opentabletdriver = { enable = true; daemon.enable = true; };
  # `programs.adb.enable` was removed on 26.05 (systemd 258 handles the uaccess
  # udev rules automatically); the `adb` command comes from `android-tools` in the
  # package list below.
  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ATTR{idVendor}=="18d1", ATTR{idProduct}=="4ee7", MODE="0660", GROUP="plugdev"
  '';

  # --- CUSTOM SERVICES (Ported from your config) ---
  systemd.timers."backup-nix-config" = {
    wantedBy = [ "timers.target" ];
    timerConfig = { OnCalendar = "*-*-* *:00:00"; Persistent = true; };
  };
  systemd.services."backup-nix-config" = {
    serviceConfig.ExecStart = "${pkgs.coreutils}/bin/cp -r /etc/nixos/configuration.nix /home/dhilipsiva/dotfiles/configuration_backup.nix";
  };

  systemd.timers."show-time-notification" = {
    wantedBy = [ "timers.target" ];
    timerConfig = { OnCalendar = "-*-* *:00,15,30,45:00"; Persistent = true; };
  };
  systemd.services."show-time-notification" = {
    serviceConfig.ExecStart = "/home/dhilipsiva/.files/scripts/show_time_notification.sh"; # Ensure this path exists!
  };

  # --- PROGRAMS ---
  programs.hyprland.enable = true;
  programs.nix-ld.enable = true; # Critical for running random binaries (VSCode server, etc)
  programs.dconf.enable = true;
  programs.fish.enable = true;
  virtualisation.docker = { enable = true; enableOnBoot = false; };

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
    docker bruno discord openconnect openssh android-tools
    # copilot-cli removed upstream (EOL) — dropped on 26.05; re-add a replacement
    # (e.g. the `gh` copilot extension) if wanted.
    arduino-ide code-cursor codex
    ssm-session-manager-plugin wasm-pack watchman
    typescript-language-server difftastic
    
    # Desktop / GUI
    rofi waybar dunst mako grim slurp wl-clipboard flameshot
    firefox
    
    # Wine / Gaming
    lutris wineWow64Packages.stable winetricks vulkan-tools
  ];

  # --- ENVIRONMENT VARIABLES ---
  environment.variables = {
    EDITOR = "hx";
    VISUAL = "hx";
    XDG_CONFIG_HOME = "/home/dhilipsiva/.files/.config";
    # Removed DRI_PRIME=1 because on Desktop your monitor is directly connected to the GPU
  };
  
  # First-install anchor for the never-installed desktop (NOT a bump on an existing
  # machine). A revived ThinkPad would keep its own original stateVersion.
  system.stateVersion = "26.05";
}
