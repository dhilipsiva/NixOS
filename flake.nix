{
  description = "Dhilipsiva's NixOS hosts and shared Home Manager configuration";

  inputs = {
    # Keep NixOS and Home Manager on the newest released stable series together.
    # The maintenance updater advances both branches after an official release.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";

    # Selected applications need newer stable upstream releases than the NixOS
    # release branch carries. This supplies packages only, never NixOS modules.
    # Check their versions against upstream releases when refreshing the lock.
    nixpkgs-apps.url = "github:nixos/nixpkgs/master";

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.2.0";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.rust-overlay.follows = "rust-overlay";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Hardware quirks (AMD microcode, NVIDIA, SSD) offloaded to nixos-hardware.
    nixos-hardware = {
      url = "github:nixos/nixos-hardware/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Declarative secrets. Pinned via flake.lock; re-verify the activation-script
    # wiring (setupSecretsForUsers) after any `nix flake update` (see modules/nixos/sops.nix).
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs = { nixpkgs, home-manager, ... }@inputs:
    let
      # Share software and dotfiles; each host owns its hardware, filesystems,
      # bootloader, secrets file, and NixOS/Home Manager stateVersion anchors.
      mkHost = hostModule: nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          hostModule
          ./modules/nixos
          inputs.sops-nix.nixosModules.sops
          home-manager.nixosModules.home-manager
          {
            nixpkgs.overlays = [
              inputs.rust-overlay.overlays.default
              (final: prev:
                let
                  apps = import inputs.nixpkgs-apps {
                    inherit (prev.stdenv.hostPlatform) system;
                    config.allowUnfree = true;
                  };
                  newer = package: minimum: fallback:
                    if builtins.match "[0-9]+(\\.[0-9]+){1,3}" package.version != null
                      && prev.lib.versionAtLeast package.version minimum
                    then package else fallback;
                  releases = builtins.fromJSON (builtins.readFile ./pkgs/releases.json);
                  ollamaRelease = apps.callPackage ./pkgs/ollama.nix { };
                in {
                  inherit (apps) codex zed-editor fish fuzzel helix alacritty tuigreet
                    zoxide ripgrep google-chrome obs-studio
                    hyprland hypridle hyprlock uwsm xdg-desktop-portal-hyprland;
                  atuin = newer apps.atuin releases.atuin.version (apps.callPackage ./pkgs/atuin.nix { });
                  uv = newer apps.uv releases.uv.version (apps.callPackage ./pkgs/uv.nix { });
                  herdr = newer apps.herdr releases.herdr.version (apps.callPackage ./pkgs/herdr.nix { });
                  # Separate development interpreter: leave NixOS's Python
                  # dependencies on the tested release package set.
                  python-latest = newer apps.python3 releases.python.version (import ./pkgs/python.nix { pkgs = apps; });
                  rust-toolchain = final.rust-bin.stable.latest.default.override {
                    extensions = [ "rust-src" "rust-analyzer" ];
                  };
                  ollama = newer apps.ollama releases.ollama.version ollamaRelease;
                  ollama-cuda = newer apps.ollama-cuda releases.ollama.version ollamaRelease;
                  slack = apps.slack.overrideAttrs {
                    inherit (releases.slack) version;
                    src = apps.fetchurl {
                      url = "https://downloads.slack-edge.com/desktop-releases/linux/x64/${releases.slack.version}/slack-desktop-${releases.slack.version}-amd64.deb";
                      inherit (releases.slack) hash;
                    };
                  };
                  # Claude's upstream 'stable' channel intentionally trails 'latest'.
                  claude-code = apps.claude-code.override {
                    manifest = builtins.fromJSON (builtins.readFile ./pkgs/claude-code-manifest.json);
                  };
                })
            ];
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupCommand =
              let pkgs = nixpkgs.legacyPackages.x86_64-linux;
              in "${pkgs.python3}/bin/python3 ${./scripts/backup-home-file.py}";
            home-manager.extraSpecialArgs = { inherit inputs; };
            home-manager.users.dhilipsiva = import ./home/dhilipsiva;
          }
        ];
      };
    in {
      packages.x86_64-linux.nixosctl = nixpkgs.legacyPackages.x86_64-linux.callPackage ./pkgs/nixosctl.nix { };

      # Export evaluated facts; hardware UUIDs have a single declaration.
      lib.hosts = nixpkgs.lib.mapAttrs (name: host: {
        inherit (host.config.repo.maintenance) owner repository branch remote publishRemote role boardName;
        hostname = host.config.networking.hostName;
        rootDevice = host.config.fileSystems."/".device;
        bootDevice = host.config.fileSystems."/boot".device;
        rootFsType = host.config.fileSystems."/".fsType;
        secureBoot = host.config.boot.lanzaboote.enable or false;
        bootMode = if host.config.boot.lanzaboote.enable or false then "lanzaboote"
          else if host.config.boot.loader.systemd-boot.enable then "systemd-boot" else "unsupported";
        luksDevices = nixpkgs.lib.mapAttrs (_: device: device.device) host.config.boot.initrd.luks.devices;
        requiredSecrets = builtins.attrNames host.config.sops.secrets;
        nvidiaVersion = host.config.hardware.nvidia.package.version;
        flatpakApps = nixpkgs.lib.optional (name == "thinkpad") "org.vinegarhq.Sober";
        secretsFile = "secrets/${name}.yaml";
      }) inputs.self.nixosConfigurations;

      lib.stableVersions = let
        desktop = inputs.self.nixosConfigurations.desktop;
        names = [ "codex" "claude-code" "zed-editor" "helix" "alacritty" "fish" "fuzzel"
          "tuigreet" "atuin" "herdr" "ollama" "python-latest" "rust-toolchain" "uv"
          "hyprland" "hypridle" "hyprlock" "uwsm" "zoxide" "ripgrep" "slack" "google-chrome" "obs-studio" ];
      in builtins.listToAttrs (map (name: { inherit name; value = desktop.pkgs.${name}.version; }) names)
        // {
          linux = desktop.config.boot.kernelPackages.kernel.version;
          nvidia = desktop.config.hardware.nvidia.package.version;
        };

      nixosConfigurations = {
        desktop = mkHost ./hosts/desktop;
        thinkpad = mkHost ./hosts/thinkpad;
      };

      checks.x86_64-linux.ollama-on-demand = import ./tests/ollama-on-demand.nix {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
      };
      checks.x86_64-linux.host-policies =
        let
          desktop = inputs.self.nixosConfigurations.desktop.config;
          thinkpad = inputs.self.nixosConfigurations.thinkpad.config;
          channels = builtins.fromJSON (builtins.readFile ./pkgs/stable-channels.json);
          allHostsStable = builtins.all (host:
            host.config.boot.kernelPackages.kernel.version == channels.linux.version
            && host.config.hardware.nvidia.package.version == channels.nvidia.version
          ) (builtins.attrValues inputs.self.nixosConfigurations);
        in assert nixpkgs.lib.assertMsg (
          desktop.boot.lanzaboote.enable && !desktop.systemd.targets.suspend.enable
          && thinkpad.boot.loader.systemd-boot.enable
          && thinkpad.boot.initrd.luks.devices.root.device == "/dev/disk/by-uuid/4a7c2f90-d44a-479c-82f6-f764d6cab51d"
          && thinkpad.fileSystems."/".device == "/dev/disk/by-uuid/84250d8e-f63c-4427-99dd-db945a069258"
          && thinkpad.fileSystems."/boot".device == "/dev/disk/by-uuid/BE19-6095"
          && thinkpad.system.stateVersion == "24.11"
          && thinkpad.home-manager.users.dhilipsiva.home.stateVersion == "26.05"
          && thinkpad.systemd.sleep.settings.Sleep.AllowSuspend
          && !thinkpad.systemd.sleep.settings.Sleep.AllowHibernation
          && thinkpad.services.logind.settings.Login.IdleAction == "ignore"
          && thinkpad.services.logind.settings.Login.HandleLidSwitch == "suspend"
          && thinkpad.services.logind.settings.Login.HandleLidSwitchDocked == "ignore"
          && thinkpad.hardware.nvidia.prime.offload.enable
          && thinkpad.hardware.nvidia.prime.intelBusId == "PCI:0:2:0"
          && thinkpad.hardware.nvidia.prime.nvidiaBusId == "PCI:1:0:0"
          && thinkpad.environment.sessionVariables.AQ_DRM_DEVICES == "/dev/dri/thinkpad-intel:/dev/dri/thinkpad-nvidia"
          && !(desktop.environment.sessionVariables ? AQ_DRM_DEVICES)
          && thinkpad.services.flatpak.enable && thinkpad.programs.obs-studio.enable
          && thinkpad.programs.obs-studio.package.version == channels.obs-studio.version
          && inputs.self.lib.hosts.thinkpad.requiredSecrets == [ "dhilipsiva/hashedPassword" ]
          && allHostsStable
        ) "Host storage, power, graphics, stable versions or application preservation policy changed.";
        nixpkgs.legacyPackages.x86_64-linux.runCommand "host-policies-check" { } "touch $out";
      checks.x86_64-linux.repository-workflow =
        let pkgs = nixpkgs.legacyPackages.x86_64-linux;
        in pkgs.runCommand "repository-workflow-check" {
          nativeBuildInputs = [ pkgs.python3 pkgs.git pkgs.age pkgs.sops pkgs.ssh-to-age pkgs.openssh ];
        } ''
          export HOME="$TMPDIR/home"
          mkdir -p "$HOME"
          export PYTHONDONTWRITEBYTECODE=1
          python3 ${./tests/test-nixosctl.py} ${./scripts}
          python3 ${./tests/test-deployment.py} ${./scripts}
          python3 ${./tests/test-secret-encryption.py} ${./scripts}
          python3 ${./scripts/check-secrets.py} ${./.}
          touch "$out"
        '';
      checks.x86_64-linux.hyprland-config =
        let
          desktop = inputs.self.nixosConfigurations.desktop;
          configurations = nixpkgs.lib.mapAttrsToList (name: host:
            "${host.pkgs.hyprland}/bin/Hyprland --verify-config -c ${host.config.home-manager.users.dhilipsiva.xdg.configFile."hypr/hyprland.lua".source}"
          ) inputs.self.nixosConfigurations;
        in desktop.pkgs.runCommand "hyprland-config-check" { } ''
          export XDG_RUNTIME_DIR="$TMPDIR/runtime"
          export XDG_CACHE_HOME="$TMPDIR/cache"
          mkdir -m 700 -p "$XDG_RUNTIME_DIR" "$XDG_CACHE_HOME"
          ${nixpkgs.lib.concatStringsSep "\n" configurations}
          touch "$out"
        '';
      checks.x86_64-linux.stable-releases =
        let
          desktop = inputs.self.nixosConfigurations.desktop;
          packages = with desktop.pkgs; [
            codex claude-code zed-editor helix alacritty fish fuzzel tuigreet
            atuin herdr ollama python-latest rust-toolchain uv
            hyprland hypridle hyprlock uwsm
            zoxide ripgrep slack google-chrome obs-studio
            desktop.config.boot.kernelPackages.kernel
            desktop.config.hardware.nvidia.package
          ];
          isStable = package:
            builtins.match "[0-9]+(\\.[0-9]+){1,3}" package.version != null;
          channels = builtins.fromJSON (builtins.readFile ./pkgs/stable-channels.json);
          versions = inputs.self.lib.stableVersions;
          matchesChannels = builtins.attrNames versions == builtins.attrNames channels
            && builtins.all (name: versions.${name} == channels.${name}.version) (builtins.attrNames versions);
        in assert desktop.pkgs.lib.assertMsg (builtins.all isStable packages)
          "A selected package has a prerelease/development version; refusing the update.";
        assert desktop.pkgs.lib.assertMsg matchesChannels
          "A selected application differs from the recorded official stable channel; refresh its packaging.";
        desktop.pkgs.runCommand "stable-releases-check" {
          nativeBuildInputs = [ desktop.pkgs.python3 ];
        } ''
          export PYTHONDONTWRITEBYTECODE=1
          python3 ${./tests/test-stable-releases.py} ${./scripts/update-stable-releases.py}
          touch "$out"
        '';
    };
}
