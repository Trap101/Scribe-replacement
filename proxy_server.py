from http.server import HTTPServer, BaseHTTPRequestHandler
import json
import urllib.request
import urllib.error

class ProxyHandler(BaseHTTPRequestHandler):
    def do_OPTIONS(self):
        self.send_response(200)
        self._cors_headers()
        self.end_headers()

    def do_POST(self):
        content_length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_length)

        if self.path == '/claude':
            url = 'https://api.anthropic.com/v1/messages'
            headers = {
                'Content-Type': 'application/json',
                'x-api-key': self.headers.get('x-api-key', ''),
                'anthropic-version': self.headers.get('anthropic-version', '2023-06-01'),
            }
        elif self.path == '/transcribe':
            url = 'https://api.elevenlabs.io/v1/speech-to-text'
            headers = {
                'xi-api-key': self.headers.get('xi-api-key', ''),
            }
            # For multipart, forward content-type
            ct = self.headers.get('Content-Type', '')
            if ct:
                headers['Content-Type'] = ct
        else:
            self.send_response(404)
            self._cors_headers()
            self.end_headers()
            self.wfile.write(b'Not found')
            return

        try:
            req = urllib.request.Request(url, data=body, headers=headers, method='POST')
            with urllib.request.urlopen(req) as resp:
                resp_body = resp.read()
                self.send_response(resp.status)
                self._cors_headers()
                self.send_header('Content-Type', resp.headers.get('Content-Type', 'application/json'))
                self.end_headers()
                self.wfile.write(resp_body)
        except urllib.error.HTTPError as e:
            resp_body = e.read()
            self.send_response(e.code)
            self._cors_headers()
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(resp_body)
        except Exception as e:
            self.send_response(502)
            self._cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps({'error': str(e)}).encode())

    def _cors_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type, x-api-key, anthropic-version, xi-api-key')

    def log_message(self, format, *args):
        print(f"[proxy] {args[0]}")

if __name__ == '__main__':
    port = 8080
    server = HTTPServer(('localhost', port), ProxyHandler)
    print(f'Proxy server running on http://localhost:{port}')
    print('Routes: POST /claude -> Anthropic API, POST /transcribe -> ElevenLabs API')
    server.serve_forever()
