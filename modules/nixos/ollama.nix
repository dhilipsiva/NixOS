# Ollama does not consume systemd's listening socket itself. A socket proxy starts
# the backend on the first connection and stops it after connections go idle.
# Owner's request: every host serves the API to its LAN on port 11434. The API
# has no authentication, so any device there can chat with, pull and delete
# models. The backend stays on loopback; only the proxy's port is open.
{
  config,
  lib,
  pkgs,
  ...
}:

{
  services.ollama = {
    enable = true;
    host = "127.0.0.1";
    port = 11435; # internal backend; clients keep using the normal port 11434
    openFirewall = false;
    environmentVariables.OLLAMA_KEEP_ALIVE = "0";
  };

  systemd.services.ollama = {
    wantedBy = lib.mkForce [ ];
    unitConfig.StopWhenUnneeded = true;
    # Do not accept proxied requests before the backend has bound its port.
    postStart = ''
      ${pkgs.curl}/bin/curl --fail --silent --show-error \
        --retry 30 --retry-connrefused --retry-delay 1 --max-time 2 \
        http://127.0.0.1:${toString config.services.ollama.port}/api/version > /dev/null
    '';
  };

  systemd.sockets.ollama-proxy = {
    description = "On-demand Ollama API";
    wantedBy = [ "sockets.target" ];
    listenStreams = [ "0.0.0.0:11434" ];
    socketConfig.NoDelay = true;
  };

  networking.firewall.allowedTCPPorts = [ 11434 ];

  systemd.services.ollama-proxy = {
    description = "Socket proxy for on-demand Ollama";
    requires = [ "ollama.service" ];
    bindsTo = [ "ollama.service" ];
    after = [ "ollama.service" ];
    serviceConfig = {
      ExecStart = "${pkgs.systemd}/lib/systemd/systemd-socket-proxyd --exit-idle-time=5min 127.0.0.1:${toString config.services.ollama.port}";
      DynamicUser = true;
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
    };
  };
}
