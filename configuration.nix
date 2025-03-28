{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  i18n.defaultLocale = "en_IN";

  console = {
    keyMap = "us";
  };

  nix = {
    gc = {
      automatic = true;                 
      dates = "daily";                 
      options = "--delete-older-than 7d";  
    };  
  };
  
  nixpkgs.config = {
    allowUnfree = true;
    android_sdk.accept_license = true;
  };

  system = {
    stateVersion = "24.11";
    autoUpgrade = {
      enable = true;
      allowReboot = true;
    };
  };
  
  security = {
    polkit = {
      enable = true;
    };
  };

  boot = {
    loader = {
      systemd-boot = {
        enable = true;
      };
      efi.canTouchEfiVariables = true;
    };
    kernelPackages = pkgs.linuxPackages_latest;
    extraModulePackages = [ config.boot.kernelPackages.bbswitch ];
  };

  swapDevices = [];

  users = {
    mutableUsers = false;
    users.dhilipsiva = {
      isNormalUser = true;
      extraGroups = [ 
        "adbusers"
        "docker"
        "input"
        "kvm"
        "networkmanager"
        "plugdev"
        "wheel"
      ];
      hashedPassword = "$6$3TFqdE8hE9Hr9RS.$vd5EFAbzbHXn9qdQRRYtuwHyauBv/m1j.qe7LMo5tmz7KKhRZ1Fao8rS3BNPcS6f0yE4cOFHvf8ofcjzzkT671";
      createHome = true;
    };
  };

  programs = {
    hyprland.enable = true;
    # sway = {
    #   enable = true;
    # };
    bash = {
      promptInit = "eval $(starship init bash)";
      interactiveShellInit = "eval $(atuin init bash)";
    };
    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };
    waybar = {
      enable = true;
    };
    nix-ld = {
      enable = true;
      libraries = with pkgs; [];
    };
    adb.enable = true;
    
  };

  systemd = {
    timers."backup-nix-config" = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*-*-* *:00:00";
        Persistent = true;
      };
    };
    services."backup-nix-config" = {
      serviceConfig = {
        ExecStart = "/run/current-system/sw/bin/cp -r /etc/nixos/configuration.nix /home/dhilipsiva/.files/configuration.nix";
      };
    };

    timers."show-time-notification" = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "-*-* *:00,15,30,45:00";
        Persistent = true;
      };
    };

    services."show-time-notification" = {
      description = "Show a notification with the current time";
      serviceConfig = {
        ExecStart = "/home/dhilipsiva/.files/scripts/show_time_notification.sh";
      };
    }; 

  };
  
  time.timeZone = "Asia/Kolkata";
  xdg.portal = {
    enable = true;
    wlr.enable = true;
    # gtk portal needed to make firefox happy
    # extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    extraPortals = [ pkgs.xdg-desktop-portal-hyprland ];
    # gtkUsePortal = true;
  };

  services = {
    dbus.enable = true;
    udev.packages = [
      pkgs.android-udev-rules
    ];
    syslogd.enable = true;
    timesyncd.enable = true;
    cron = {
      enable = true;
    };
    gnome.gnome-keyring = {
      enable = true;
    };
    xserver = {
      enable = false;
    };
    displayManager = {
      enable = false;
    };
    
    pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
      jack.enable = false;
    };

    resolved = {
      enable = true;
    };

    udev.extraRules = ''
      SUBSYSTEM=="usb", ATTR{idVendor}=="18d1", ATTR{idProduct}=="4ee7", MODE="0660", GROUP="plugdev"
    '';

  };

  hardware = {
    pulseaudio.enable = false;
    nvidia = {
      modesetting.enable = true;
      nvidiaSettings.enable = true;
      powerManagement.enable = true;
      prime.offload.enable = true;
    };
    nvidiaOptimus = {
      disable = true;
    };
  };

  networking = {
    networkmanager.enable = true;
    hostName = "dhilipsiva-thinkpad";
    firewall.allowedTCPPorts = [ 8080 ];
  };

  fonts.packages = with pkgs; [
    fira-code
    font-awesome
    nerdfonts
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-emoji
  ];

  environment= {
    systemPackages = with pkgs; [
      alacritty
      atuin
      awscli2
      bottom
      bruno
      copilot-cli
      curl
      delta
      discord
      docker
      dunst
      firefox-wayland
      fish
      gcc
      git
      gnome-keyring
      gnumake
      gnupg
      google-chrome
      grim
      helix
      libinput
      libnotify
      libxml2
      mako
      microsoft-edge
      mitmproxy
      openconnect
      openssh
      openssl
      pass-wayland
      pkg-config
      python3
      ripgrep
      rofi-wayland
      rustup
      rye
      seahorse
      slurp
      ssm-session-manager-plugin
      starship
      tree
      typescript-language-server
      unzip
      vscode
      vscode-langservers-extracted
      wasm-pack
      watchman
      waybar
      wl-clipboard
      xdg-desktop-portal
      zellij
    ];
    variables = {
      EDITOR = "hx";
      VISUAL = "hx";
      XDG_CONFIG_HOME = "/home/dhilipsiva/.files/.config";
    };
    shellAliases = {
      g = "git";
      e = "hx";
      q = "exit";
    };
  };

  virtualisation = {
    docker = {
      enable = true;
      enableOnBoot = false;
    };
  };

  networking = {
    hosts = {
      "127.0.0.1" = [ 
        "www.youtube.com" 
        "youtube.com" 
        
        "www.linkedin.com"
        "linkedin.com"

        "reddit.com"
        "www.reddit.com"
      ];
    };
  };

}
