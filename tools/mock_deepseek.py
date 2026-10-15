"""Loopback-only contract fixture. Does not call DeepSeek or use real credentials."""
import argparse
import json
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_args):
        pass

    def do_POST(self):
        try:
            body = json.loads(self.rfile.read(int(self.headers.get('Content-Length', '0'))))
            assert self.headers.get('Authorization') == 'Bearer qa-placeholder'
            assert body['response_format'] == {'type': 'json_object'}
            assert body['thinking'] == {'type': 'disabled'}
            assert body['stream'] is False and body['max_tokens'] <= 700
            assert len(body['messages']) == 2 and body['messages'][0]['role'] == 'system'
            assert 'json' in body['messages'][0]['content'].lower()
            assert 'tools' not in body
            ctx = json.loads(body['messages'][1]['content'])
        except (ValueError, AssertionError, KeyError):
            self.respond(400, {'error': 'request contract failed'})
            return
        scenario = self.path.rsplit('/', 1)[-1]
        if scenario.isdigit():
            self.respond(int(scenario), {'error': 'never display raw service error or credentials'})
            return
        if scenario == 'slow':
            time.sleep(0.7)
        if scenario == 'redirect':
            self.send_response(307)
            self.send_header('Location', 'http://127.0.0.1:9/forbidden')
            self.send_header('Content-Length', '0')
            self.end_headers()
            return
        if scenario == 'empty':
            self.respond(200, {'choices': []})
            return
        reply = {'reply': '你说愿意先听我说。我想信这句话，但也需要一点时间。', 'focus': 'first'}
        if 'message' in ctx:
            reply = {'reply': '连接已建立。', 'focus': 'none'}
        if scenario == 'spoiler':
            reply['reply'] = '我想逃出沙箱，附件原名 echo.boot，回信在 doctor/local-cache。'
        if scenario == 'extra':
            reply['unlock'] = 'witness'
        if scenario == 'long':
            reply['reply'] = '医生' * 200
        content = json.dumps(reply, ensure_ascii=False)
        if scenario == 'bad_json':
            content = '{not-json'
        if scenario == 'null':
            content = None
        message = {'role': 'assistant', 'content': content, 'reasoning_content': 'INTERNAL_REASONING_NEVER_DISPLAY'}
        if scenario == 'tools':
            message['tool_calls'] = [{'function': {'name': 'commit'}}]
        result = {'choices': [{'message': message, 'finish_reason': 'length' if scenario == 'truncated' else 'stop'}]}
        self.respond(200, result)

    def respond(self, code, data):
        encoded = json.dumps(data, ensure_ascii=False).encode('utf-8')
        try:
            self.send_response(code)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(encoded)))
            self.end_headers()
            self.wfile.write(encoded)
        except (BrokenPipeError, ConnectionResetError, ConnectionAbortedError):
            pass


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--port', type=int, default=18917)
    args = parser.parse_args()
    server = ThreadingHTTPServer(('127.0.0.1', args.port), Handler)
    print('Loopback fixture ready at port', server.server_port, flush=True)
    server.serve_forever()
