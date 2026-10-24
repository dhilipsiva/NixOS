"""Exercise the packaged Rust service and self-model in a Nix build sandbox.

The runtime uses Ollama's fixed loopback port. Bind our own fixture before
starting Lucy; fail if the port is occupied, never contact an existing model.
All configuration, memory, workspaces and service sockets are disposable.
"""

import argparse
import json
import os
import socket
import subprocess
import tempfile
import threading
import time
from contextlib import contextmanager
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


class Ollama(BaseHTTPRequestHandler):
    def log_message(self, *_args):
        pass

    def reply(self, value):
        body = json.dumps(value).encode()
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        assert self.path == '/api/tags', self.path
        self.reply({'models': [{'name': self.server.model, 'digest': self.server.digest}]})

    def do_POST(self):
        assert self.path == '/api/chat', self.path
        request = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
        self.server.requests.append(request)
        if len(self.server.requests) == 1:
            message = {'role': 'assistant', 'content': '', 'tool_calls': [{
                'id': 'read-fixture', 'type': 'function',
                'function': {'name': 'read', 'arguments': {'path': 'note.txt'}},
            }]}
        else:
            message = {'role': 'assistant', 'content': 'Package fixture read.'}
        self.reply({'message': message, 'done': True})


def rpc(path, request):
    with socket.socket(socket.AF_UNIX) as client:
        client.settimeout(30)
        client.connect(str(path))
        client.sendall(json.dumps(request).encode() + b'\n')
        with client.makefile('rb') as response:
            return json.loads(response.readline())


@contextmanager
def service(binary, env, workspace, log_path):
    with log_path.open('w+') as log:
        process = subprocess.Popen([binary, 'serve'], env=env, cwd=workspace,
                                   stdout=log, stderr=log)
        path = Path(env['XDG_RUNTIME_DIR']) / 'lucy/service.sock'
        try:
            deadline = time.monotonic() + 15
            while True:
                if process.poll() is not None:
                    raise AssertionError('Packaged service exited at startup')
                if path.exists():
                    try:
                        if rpc(path, {'op': 'status'}).get('runtime') == 'rust':
                            break
                    except (ConnectionError, FileNotFoundError):
                        pass
                if time.monotonic() >= deadline:
                    raise AssertionError('Packaged Rust service did not become ready')
                time.sleep(0.05)
            yield path
        except BaseException:
            log.seek(0)
            print(log.read())
            raise
        finally:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--binary', required=True)
    parser.add_argument('--model', default='qwen3.6:35b-a3b-q4_K_M')
    parser.add_argument('--digest', default='07d35212591fc27746f0a317c975a6d68754fb38e9053d82e25f06057af28522')
    parser.add_argument('--context', type=int, default=16384)
    parser.add_argument('--expect-host-pin', action='store_true')
    args = parser.parse_args()

    with tempfile.TemporaryDirectory(prefix='lucy-package-') as directory:
        root = Path(directory)
        env = {k: v for k, v in os.environ.items() if not k.startswith('LUCY_')}
        for key, name in [('HOME', 'home'), ('XDG_CONFIG_HOME', 'config'),
                          ('XDG_DATA_HOME', 'share'), ('XDG_RUNTIME_DIR', 'runtime')]:
            path = root / name
            path.mkdir(mode=0o700)
            env[key] = str(path)
        data = root / 'memory'
        env['LUCY_DATA_DIR'] = str(data)
        if args.expect_host_pin:
            # A host pin must override inherited settings for all three fields.
            env.update(LUCY_CHAT_MODEL='wrong-inherited-model',
                       LUCY_CHAT_DIGEST='0' * 64, LUCY_CHAT_CONTEXT='1')
        workspace = root / 'workspace'
        workspace.mkdir()
        marker = 'Evidence from the packaged executor.'
        (workspace / 'note.txt').write_text(marker)

        def audit():
            result = subprocess.run([args.binary, 'self-model', 'audit'], env=env,
                                    cwd=workspace, capture_output=True, text=True,
                                    timeout=30, check=True)
            return json.loads(result.stdout)

        with ThreadingHTTPServer(('127.0.0.1', 11434), Ollama) as model:
            model.model = args.model
            model.digest = 'mismatched-manifest'
            model.requests = []
            worker = threading.Thread(target=model.serve_forever, daemon=True)
            worker.start()
            try:
                with service(args.binary, env, workspace, root / 'service.log') as path:
                    opened = rpc(path, {'op': 'open'})
                    assert opened['model'] == args.model, opened
                    assert not data.exists(), 'Opening the service loaded private memory'
                    assert path.stat().st_mode & 0o777 == 0o600
                    empty = audit()
                    assert empty['integrity'] == 'checked', empty
                    assert empty['predictions'] == empty['observations'] == 0, empty

                    request = {**opened, 'op': 'chat', 'workspace': str(workspace),
                               'text': 'Read note.txt', 'event': 'wrong-digest'}
                    refused = rpc(path, request)
                    assert 'digest differs' in refused.get('error', ''), refused
                    assert not model.requests, 'A mismatched model reached inference'

                    model.digest = 'sha256:' + args.digest
                    response = rpc(path, {**request, 'event': 'read-fixture'})
                    assert response.get('text') == 'Package fixture read.', response
                    assert len(model.requests) == 2, model.requests
                    for chat in model.requests:
                        assert chat['model'] == args.model, chat
                        assert chat['options']['num_ctx'] == args.context, chat
                        assert chat['keep_alive'] == 0, chat
                    evidence = model.requests[-1]['messages'][-1]
                    assert evidence['role'] == 'tool' and marker in evidence['content'], evidence
                    checked = audit()
                    assert checked['integrity'] == 'checked', checked
                    assert checked['predictions'] == checked['observations'] == 1, checked
                    assert checked['pending'] == 0, checked
                    assert checked['scopes'][0]['scope']['measurement'] == 'runtime', checked

                with service(args.binary, env, workspace, root / 'restart.log') as path:
                    assert not rpc(path, {'op': 'status'})['active']
                    assert audit() == checked, 'Self-model history changed across restart'
            finally:
                model.shutdown()
                worker.join(timeout=5)

    print('Packaged Rust service, host model pin and persistent self-model passed.')


if __name__ == '__main__':
    main()
