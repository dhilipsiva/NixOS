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

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      inherit (nixpkgs) lib;
      # Plain release packages for repository tooling and checks. Host package
      # sets carry the overlays below and are reached through nixosConfigurations.
      pkgs = nixpkgs.legacyPackages.${system};
      desktop = self.nixosConfigurations.desktop;

      # Applications whose packaged version must equal the recorded official
      # stable channel in pkgs/stable-channels.json. The kernel and NVIDIA driver
      # are host configuration and are appended where they are compared.
      stableApps = [
        "codex"
        "claude-code"
        "zed-editor"
        "helix"
        "alacritty"
        "fish"
        "fuzzel"
        "tuigreet"
        "atuin"
        "herdr"
        "ollama"
        "python-latest"
        "rust-toolchain"
        "uv"
        "hyprland"
        "hypridle"
        "hyprlock"
        "uwsm"
        "zoxide"
        "ripgrep"
        "slack"
        "google-chrome"
        "obs-studio"
      ];

      # Newer stable upstream releases layered over the release package set. The
      # separate package tree is instantiated once here and exposed as
      # `pkgs.nixpkgs-apps`, so host modules never import it a second time.
      appsOverlay =
        final: prev:
        let
          apps = import inputs.nixpkgs-apps {
            inherit (prev.stdenv.hostPlatform) system;
            config.allowUnfree = true;
          };
          newer =
            package: minimum: fallback:
            if
              builtins.match "[0-9]+(\\.[0-9]+){1,3}" package.version != null
              && prev.lib.versionAtLeast package.version minimum
            then
              package
            else
              fallback;
          releases = builtins.fromJSON (builtins.readFile ./pkgs/releases.json);
          ollamaRelease = apps.callPackage ./pkgs/ollama.nix { };
        in
        {
          nixpkgs-apps = apps;
          inherit (apps)
            codex
            zed-editor
            fish
            fuzzel
            helix
            alacritty
            tuigreet
            zoxide
            ripgrep
            google-chrome
            obs-studio
            hyprland
            hypridle
            hyprlock
            uwsm
            xdg-desktop-portal-hyprland
            ;
          atuin = newer apps.atuin releases.atuin.version (apps.callPackage ./pkgs/atuin.nix { });
          uv = newer apps.uv releases.uv.version (apps.callPackage ./pkgs/uv.nix { });
          herdr = newer apps.herdr releases.herdr.version (apps.callPackage ./pkgs/herdr.nix { });
          # Separate development interpreter: leave NixOS's Python
          # dependencies on the tested release package set.
          python-latest = newer apps.python3 releases.python.version (
            import ./pkgs/python.nix { pkgs = apps; }
          );
          rust-toolchain = final.rust-bin.stable.latest.default.override {
            extensions = [
              "rust-src"
              "rust-analyzer"
            ];
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
        };

      # Share software and dotfiles; each host owns its hardware, filesystems,
      # bootloader, secrets file, NixOS/Home Manager stateVersion anchors and
      # platform (`nixpkgs.hostPlatform` in its hardware configuration).
      mkHost =
        hostModule:
        lib.nixosSystem {
          specialArgs = { inherit inputs; };
          modules = [
            hostModule
            ./modules/nixos
            inputs.sops-nix.nixosModules.sops
            home-manager.nixosModules.home-manager
            (
              { pkgs, ... }:
              {
                nixpkgs.overlays = [
                  inputs.rust-overlay.overlays.default
                  appsOverlay
                ];
                home-manager = {
                  useGlobalPkgs = true;
                  useUserPackages = true;
                  backupCommand = "${pkgs.python3}/bin/python3 ${./scripts/backup-home-file.py}";
                  extraSpecialArgs = { inherit inputs; };
                  users.dhilipsiva = import ./home/dhilipsiva;
                };
              }
            )
          ];
        };
    in
    {
      nixosConfigurations = {
        desktop = mkHost ./hosts/desktop;
        thinkpad = mkHost ./hosts/thinkpad;
      };

      # The shared system and Home Manager configuration, reusable from another
      # flake or a future per-host split.
      nixosModules.default = import ./modules/nixos;
      homeModules.default = import ./home/dhilipsiva;

      packages.${system}.nixosctl = pkgs.callPackage ./pkgs/nixosctl.nix { };

      # `nix fmt` runs nixfmt over the whole tree through its zero-setup treefmt
      # wrapper; `nix develop` provides the tools used by scripts, tests and checks.
      formatter.${system} = pkgs.nixfmt-tree;
      devShells.${system}.default = pkgs.mkShellNoCC {
        packages = with pkgs; [
          python3
          git
          age
          sops
          ssh-to-age
          nixfmt
          deadnix
          ruff
        ];
      };

      # Export evaluated facts; hardware UUIDs have a single declaration.
      lib.hosts = lib.mapAttrs (name: host: {
        inherit (host.config.repo.maintenance)
          owner
          repository
          branch
          remote
          publishRemote
          role
          boardName
          ;
        hostname = host.config.networking.hostName;
        rootDevice = host.config.fileSystems."/".device;
        bootDevice = host.config.fileSystems."/boot".device;
        rootFsType = host.config.fileSystems."/".fsType;
        secureBoot = host.config.boot.lanzaboote.enable or false;
        bootMode =
          if host.config.boot.lanzaboote.enable or false then
            "lanzaboote"
          else if host.config.boot.loader.systemd-boot.enable then
            "systemd-boot"
          else
            "unsupported";
        luksDevices = lib.mapAttrs (_: device: device.device) host.config.boot.initrd.luks.devices;
        requiredSecrets = builtins.attrNames host.config.sops.secrets;
        nvidiaVersion = host.config.hardware.nvidia.package.version;
        flatpakApps = lib.optional (name == "thinkpad") "org.vinegarhq.Sober";
        secretsFile = "secrets/${name}.yaml";
      }) self.nixosConfigurations;

      lib.stableVersions = lib.genAttrs stableApps (name: desktop.pkgs.${name}.version) // {
        linux = desktop.config.boot.kernelPackages.kernel.version;
        nvidia = desktop.config.hardware.nvidia.package.version;
      };

      checks.${system} = {
        ollama-on-demand = import ./tests/ollama-on-demand.nix { inherit pkgs; };

        # Each host's storage, power, graphics and application-preservation
        # policy, pinned so a shared-module change cannot silently alter them.
        host-policies =
          let
            thinkpad = self.nixosConfigurations.thinkpad.config;
            channels = builtins.fromJSON (builtins.readFile ./pkgs/stable-channels.json);
            allHostsStable = builtins.all (
              host:
              host.config.boot.kernelPackages.kernel.version == channels.linux.version
              && host.config.hardware.nvidia.package.version == channels.nvidia.version
            ) (builtins.attrValues self.nixosConfigurations);
          in
          assert lib.assertMsg (
            desktop.config.boot.lanzaboote.enable
            && !desktop.config.systemd.sleep.settings.Sleep.AllowSuspend
            && thinkpad.boot.loader.systemd-boot.enable
            &&
              thinkpad.boot.initrd.luks.devices.root.device
              == "/dev/disk/by-uuid/4a7c2f90-d44a-479c-82f6-f764d6cab51d"
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
            &&
              thinkpad.environment.sessionVariables.AQ_DRM_DEVICES
              == "/dev/dri/thinkpad-intel:/dev/dri/thinkpad-nvidia"
            && !(desktop.config.environment.sessionVariables ? AQ_DRM_DEVICES)
            &&
              thinkpad.home-manager.users.dhilipsiva.wayland.windowManager.hyprland.settings.monitor == [
                {
                  output = "";
                  mode = "preferred";
                  position = "auto";
                  scale = 1;
                }
              ]
            && builtins.any (
              monitor: monitor.output == "HDMI-A-1" && monitor.scale == 1.5
            ) desktop.config.home-manager.users.dhilipsiva.wayland.windowManager.hyprland.settings.monitor
            && thinkpad.services.flatpak.enable
            && thinkpad.programs.obs-studio.enable
            && thinkpad.programs.obs-studio.package.version == channels.obs-studio.version
            && self.lib.hosts.thinkpad.requiredSecrets == [ "dhilipsiva/hashedPassword" ]
            && allHostsStable
          ) "Host storage, power, graphics, stable versions or application preservation policy changed.";
          pkgs.runCommand "host-policies-check" { } "touch $out";

        repository-workflow =
          pkgs.runCommand "repository-workflow-check"
            {
              nativeBuildInputs = [
                pkgs.python3
                pkgs.git
                pkgs.age
                pkgs.sops
                pkgs.ssh-to-age
                pkgs.openssh
              ];
            }
            ''
              export HOME="$TMPDIR/home"
              mkdir -p "$HOME"
              export PYTHONDONTWRITEBYTECODE=1
              python3 ${./tests/test-nixosctl.py} ${./scripts}
              python3 ${./tests/test-deployment.py} ${./scripts}
              python3 ${./tests/test-secret-encryption.py} ${./scripts}
              python3 ${./scripts/check-secrets.py} ${./.}
              touch "$out"
            '';

        # Every tracked Nix file must be formatted by the official formatter and
        # free of unused bindings, and the Python helpers must pass ruff, so edits
        # from any machine or agent stay uniform.
        formatting =
          pkgs.runCommand "formatting-check"
            {
              nativeBuildInputs = [
                pkgs.nixfmt
                pkgs.deadnix
                pkgs.ruff
              ];
            }
            ''
              find ${self} -name '*.nix' -print0 | xargs -0 nixfmt --check
              deadnix --fail ${self}
              ruff check ${self}/scripts ${self}/tests
              touch "$out"
            '';

        # Every host's generated Lua configuration must parse with its Hyprland.
        hyprland-config =
          let
            verify = lib.mapAttrsToList (
              _: host:
              "${host.pkgs.hyprland}/bin/Hyprland --verify-config -c ${
                host.config.home-manager.users.dhilipsiva.xdg.configFile."hypr/hyprland.lua".source
              }"
            ) self.nixosConfigurations;
          in
          desktop.pkgs.runCommand "hyprland-config-check" { } ''
            export XDG_RUNTIME_DIR="$TMPDIR/runtime"
            export XDG_CACHE_HOME="$TMPDIR/cache"
            mkdir -m 700 -p "$XDG_RUNTIME_DIR" "$XDG_CACHE_HOME"
            ${lib.concatStringsSep "\n" verify}
            touch "$out"
          '';

        # Home Manager generates Zellij's KDL; parse it with the installed release.
        zellij-config =
          let
            zellijConfig =
              desktop.config.home-manager.users.dhilipsiva.xdg.configFile."zellij/config.kdl".source;
          in
          desktop.pkgs.runCommand "zellij-config-check" { } ''
            export HOME="$TMPDIR/home"
            mkdir -p "$HOME"
            ${lib.getExe desktop.pkgs.zellij} --config ${zellijConfig} setup --check
            touch "$out"
          '';

        stable-releases =
          let
            packages = map (name: desktop.pkgs.${name}) stableApps ++ [
              desktop.config.boot.kernelPackages.kernel
              desktop.config.hardware.nvidia.package
            ];
            isStable = package: builtins.match "[0-9]+(\\.[0-9]+){1,3}" package.version != null;
            channels = builtins.fromJSON (builtins.readFile ./pkgs/stable-channels.json);
            versions = self.lib.stableVersions;
            matchesChannels =
              builtins.attrNames versions == builtins.attrNames channels
              && builtins.all (name: versions.${name} == channels.${name}.version) (builtins.attrNames versions);
          in
          assert lib.assertMsg (builtins.all isStable packages)
            "A selected package has a prerelease/development version; refusing the update.";
          assert lib.assertMsg matchesChannels
            "A selected application differs from the recorded official stable channel; refresh its packaging.";
          desktop.pkgs.runCommand "stable-releases-check" { nativeBuildInputs = [ desktop.pkgs.python3 ]; } ''
            export PYTHONDONTWRITEBYTECODE=1
            python3 ${./tests/test-stable-releases.py} ${./scripts/update-stable-releases.py}
            touch "$out"
          '';
      };
    };
}
