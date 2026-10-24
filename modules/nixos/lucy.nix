# On-demand Lucy desktop integration (README "Lucy on demand"). A host opts in
# by importing this module and setting repo.lucy.enable. Lucy pins one Ollama
# model for the desktop GPU; a host whose memory cannot hold it sets
# repo.lucy.model to a smaller library tag with that tag's manifest digest, and
# only that pin changes in the packaged runtime.
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.repo.lucy;
  # Helpers are immutable and authenticate via pkexec; no root model process.
  inputHelper = pkgs.writeShellScript "lucy-start-input" ''
    set -eu
    test "$#" -eq 0
    ${pkgs.systemd}/bin/systemctl start lucy-input.service
    for attempt in $(${pkgs.coreutils}/bin/seq 1 30); do
      test -S /run/lucy-input/socket && exit 0
      ${pkgs.coreutils}/bin/sleep 0.1
    done
    exit 1
  '';
  dmiHelper = pkgs.writeShellScript "lucy-hardware-info" ''
    set -eu
    test "$#" -eq 0
    exec ${pkgs.dmidecode}/bin/dmidecode --type memory
  '';
  native = {
    codex = "Submitted-prompt and final-response hooks; Codex trust review required";
    claude-code = "Submitted-prompt and final-response hooks; explicit commentary recording";
    cursor = "Prompt/response hooks; explicit skill supplies context";
    vscode = "Explicit sticky @lucy participant; selected model preserved";
    zed-editor = "Manual /lucy skill; explicit response recording and sleep required";
    firefox = "Ask Lucy extension; native messaging; persistent install requires signing";
    google-chrome = "Ask Lucy extension; activeTab and native messaging enrollment";
    dolphin = "Ask Lucy service-menu file handoff";
    alacritty = "lucy chat and explicit stdin/file handoff";
    zellij = "lucy chat and explicit stdin/file handoff";
    helix = "Pipe selected text into lucy ui --handoff-stdin as a JSON handoff";
    helix-wrapped = "Pipe selected text into lucy ui --handoff-stdin as a JSON handoff";
  };
  # Remove Lucy itself to avoid a package/inventory evaluation cycle.
  apps = builtins.filter (p: (p.name or "") != "lucy-desktop") (
    config.home-manager.users.dhilipsiva.home.packages ++ config.environment.systemPackages
  );
  inventory = pkgs.writeText "lucy-integrations.json" (
    builtins.toJSON (
      map
        (name: {
          inherit name;
          integration = if native ? ${name} then "native or explicit adapter" else "explicit handoff";
          detail =
            native.${name}
              or "Super+Alt+L opens Ask Lucy. No reliable conversation hook is configured; select and hand off task context explicitly.";
        })
        (
          lib.unique (
            (map (p: p.pname or (lib.getName p)) apps)
            ++ builtins.attrNames config.home-manager.users.dhilipsiva.xdg.desktopEntries
          )
        )
    )
  );
  identity = pkgs.writeText "lucy-identity.nibli" (
    builtins.readFile "${inputs.lucy}/lucy-cli/constitution/lucy.nibli"
    + "\n"
    + builtins.readFile ../../lucy/memory.nibli
    + "\n"
    + builtins.readFile "${inputs.lucy}/lucy/memory.nibli"
  );
  package = pkgs.callPackage ../../pkgs/lucy.nix {
    lucy = inputs.lucy;
    ollama = config.services.ollama.package;
    inherit
      identity
      inventory
      inputHelper
      dmiHelper
      ;
    inherit (cfg) model;
  };
in
{
  options.repo.lucy = {
    enable = lib.mkEnableOption "the on-demand Lucy desktop integration";
    model = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.submodule {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = "Ollama library tag, for example qwen3.5:9b-q4_K_M.";
            };
            digest = lib.mkOption {
              type = lib.types.strMatching "[0-9a-f]{64}";
              description = "SHA-256 of that tag's registry manifest, as Ollama's /api/tags reports it.";
            };
            context = lib.mkOption {
              type = lib.types.ints.positive;
              default = 16384;
              description = "num_ctx per request; Lucy's fixed 48 kB prompt budget assumes 16K.";
            };
          };
        }
      );
      default = null;
      description = ''
        Replace Lucy's pinned Ollama model on this host. null keeps Lucy's
        own pin, sized for the desktop GPU. Inference still refuses a missing
        or changed model; lucy setup-model downloads the configured tag.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.dhilipsiva.repo.lucy = {
      enable = true;
      inherit package;
    };
    services.ollama.environmentVariables.OLLAMA_NO_CLOUD = "1";
    boot.kernelModules = [ "uinput" ];
    systemd.services.lucy-input = {
      description = "Short-lived Lucy input device, started only after authentication";
      serviceConfig = {
        Type = "simple";
        RuntimeDirectory = "lucy-input";
        RuntimeDirectoryMode = "0755";
        ExecStart = pkgs.writeShellScript "lucy-input-daemon" ''
          export PATH=${lib.makeBinPath [ pkgs.systemd ]}
          exec ${pkgs.python3}/bin/python3 ${../../scripts/lucy-input.py} ${pkgs.ydotool}/bin/ydotoold
        '';
        RuntimeMaxSec = 15;
        TimeoutStopSec = 1;
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        DevicePolicy = "closed";
        DeviceAllow = [ "/dev/uinput rw" ];
        RestrictAddressFamilies = [ "AF_UNIX" ];
      };
    };
    # Cancellation may always remove this exact device; starting still authenticates.
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (action.id == "org.freedesktop.systemd1.manage-units" &&
            action.lookup("unit") == "lucy-input.service" &&
            action.lookup("verb") == "stop" && subject.user == "dhilipsiva") {
          return polkit.Result.YES;
        }
      });
    '';
  };
}
