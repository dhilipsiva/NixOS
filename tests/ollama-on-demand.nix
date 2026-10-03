# Exercise the real socket/backend lifecycle without a GPU or downloaded model.
{ pkgs }:

pkgs.testers.runNixOSTest {
  name = "ollama-on-demand";
  nodes.machine = { pkgs, lib, ... }: {
    imports = [ ../modules/nixos/ollama.nix ];
    services.ollama.package = pkgs.writers.writePython3Bin "ollama" { } ''
      import http.server
      import json
      import os


      class Handler(http.server.BaseHTTPRequestHandler):
          def do_GET(self):
              body = json.dumps({
                  "version": "test",
                  "keep_alive": os.environ["OLLAMA_KEEP_ALIVE"],
              }).encode()
              self.send_response(200)
              self.send_header("Content-Length", str(len(body)))
              self.end_headers()
              self.wfile.write(body)


      http.server.HTTPServer(("127.0.0.1", 11435), Handler).serve_forever()
    '';
    systemd.services.ollama-proxy.serviceConfig.ExecStart = lib.mkForce
      "${pkgs.systemd}/lib/systemd/systemd-socket-proxyd --exit-idle-time=2s 127.0.0.1:11435";
    environment.systemPackages = [ pkgs.curl ];
    virtualisation.memorySize = 1024;
    system.stateVersion = "26.05";
  };

  testScript = ''
    import json

    start_all()
    machine.wait_for_unit("ollama-proxy.socket")
    machine.fail("systemctl is-active --quiet ollama.service")

    # The first request starts a ready backend; the daemon is not started at boot.
    response = json.loads(machine.succeed("curl -fsS http://127.0.0.1:11434/api/version"))
    assert response["keep_alive"] == "0", response
    machine.wait_until_fails("systemctl is-active --quiet ollama-proxy.service")
    machine.wait_until_fails("systemctl is-active --quiet ollama.service")

    # The socket stays available and a later request starts a fresh backend.
    machine.succeed("curl -fsS http://127.0.0.1:11434/api/version")
    machine.wait_for_unit("ollama.service")
    machine.wait_until_fails("systemctl is-active --quiet ollama.service")
  '';
}
