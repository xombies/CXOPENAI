#!/usr/bin/env python3
import http.server
import urllib.request
import urllib.error
import json
import sys

UPSTREAM = 'http://localhost:11434'
ALLOW_ORIGIN = '*'

class Handler(http.server.BaseHTTPRequestHandler):
    def _set_cors(self):
        self.send_header('Access-Control-Allow-Origin', ALLOW_ORIGIN)
        self.send_header('Access-Control-Allow-Headers', 'Content-Type, Accept')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')

    def do_OPTIONS(self):
        self.send_response(204)
        self._set_cors()
        self.end_headers()

    def do_GET(self):
        if self.path == '/' or self.path.startswith('/?'):
            self.send_response(200)
            self._set_cors()
            self.send_header('Content-Type', 'text/plain; charset=utf-8')
            self.end_headers()
            self.wfile.write(b'ollama-proxy ok\n')
            return

        if self.path == '/health':
            target = UPSTREAM + '/api/version'
            try:
                req = urllib.request.Request(target, method='GET')
                with urllib.request.urlopen(req, timeout=10) as resp:
                    data = resp.read()
                    status = resp.status
            except Exception as e:
                self.send_response(502)
                self._set_cors()
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps({'ok': False, 'error': str(e)}).encode())
                return

            if status != 200:
                self.send_response(502)
                self._set_cors()
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps({'ok': False, 'upstream_status': status}).encode())
                return

            try:
                payload = json.loads(data.decode('utf-8'))
            except Exception:
                payload = {'raw': data.decode('utf-8', errors='replace')}

            self.send_response(200)
            self._set_cors()
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({'ok': True, 'upstream': UPSTREAM, 'version': payload.get('version')}).encode())
            return

        if self.path == '/favicon.ico':
            self.send_response(204)
            self._set_cors()
            self.end_headers()
            return

        if self.path.startswith('/api/'):
            target = UPSTREAM + self.path
            try:
                req = urllib.request.Request(target, method='GET')
                with urllib.request.urlopen(req, timeout=60) as resp:
                    data = resp.read()
                    status = resp.status
                    headers = dict(resp.headers)
            except urllib.error.HTTPError as e:
                data = e.read()
                status = e.code
                headers = dict(e.headers)
            except Exception as e:
                self.send_response(502)
                self._set_cors()
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps({'error': str(e)}).encode())
                return

            self.send_response(status)
            self._set_cors()
            self.send_header('Content-Type', headers.get('Content-Type', 'application/json'))
            self.end_headers()
            self.wfile.write(data)
            return

        self.send_response(404)
        self._set_cors()
        self.send_header('Content-Type', 'text/plain; charset=utf-8')
        self.end_headers()
        self.wfile.write(b'not found\n')

    def do_POST(self):
        length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(length) if length else b''
        target = UPSTREAM + self.path
        try:
            req = urllib.request.Request(target, data=body, method='POST')
            req.add_header('Content-Type', self.headers.get('Content-Type', 'application/json'))
            with urllib.request.urlopen(req, timeout=300) as resp:
                data = resp.read()
                status = resp.status
                headers = dict(resp.headers)
        except urllib.error.HTTPError as e:
            data = e.read()
            status = e.code
            headers = dict(e.headers)
        except Exception as e:
            self.send_response(502)
            self._set_cors()
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({'error': str(e)}).encode())
            return

        self.send_response(status)
        self._set_cors()
        self.send_header('Content-Type', headers.get('Content-Type', 'application/json'))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, format, *args):
        sys.stderr.write("%s - - [%s] %s\n" % (self.client_address[0], self.log_date_time_string(), format%args))

if __name__ == '__main__':
    port = 3030
    http.server.ThreadingHTTPServer(('0.0.0.0', port), Handler).serve_forever()
