"""Run source or Windows executable tests against a loopback-only AI fixture.

Uses only the Python standard library. No real API key or DeepSeek request.
"""
from pathlib import Path
import argparse
import importlib.util
import json
import os
import subprocess
import threading
from http.server import ThreadingHTTPServer

ROOT = Path(__file__).resolve().parents[1]


def run():
    parser = argparse.ArgumentParser(description=__doc__)
    target = parser.add_mutually_exclusive_group(required=True)
    target.add_argument('--godot', help='Godot executable; tests the source project')
    target.add_argument('--exe', help='Exported Windows executable to test')
    parser.add_argument('--timeout', type=int, default=120)
    args = parser.parse_args()
    output = ROOT / ('captures/v0.9.1-prototype-export' if args.exe else 'captures/v0.9.1-prototype')
    output.mkdir(parents=True, exist_ok=True)
    report_path = output / 'test-report.json'
    if report_path.exists():
        report_path.unlink()  # This exact generated report must not mask a failed run.
    options = {'cwd': ROOT, 'timeout': args.timeout, 'check': True}
    if os.name == 'nt':
        options['creationflags'] = subprocess.CREATE_NO_WINDOW
        startup = subprocess.STARTUPINFO()
        startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        startup.wShowWindow = 0
        options['startupinfo'] = startup
    if args.godot:
        with (output / 'import.log').open('w', encoding='utf-8') as log:
            subprocess.run([args.godot, '--headless', '--path', str(ROOT / 'project'), '--editor', '--quit'], stdout=log, stderr=subprocess.STDOUT, **options)
    spec = importlib.util.spec_from_file_location('fixture', ROOT / 'tools/mock_deepseek_v7.py')
    fixture = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(fixture)
    server = ThreadingHTTPServer(('127.0.0.1', 0), fixture.Handler)
    worker = threading.Thread(target=server.serve_forever, daemon=True)
    worker.start()
    try:
        command = [args.exe or args.godot]
        if args.godot:
            command += ['--path', str(ROOT / 'project')]
        command += ['--position', '8000,8000', '--', '--self-test',
                    f'--ai-mock-url=http://127.0.0.1:{server.server_port}',
                    f'--capture-dir={output.as_posix()}']
        with (output / 'run.log').open('w', encoding='utf-8') as log:
            subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, **options)
    finally:
        server.shutdown()
        server.server_close()
        worker.join(timeout=5)
    report = json.loads(report_path.read_text(encoding='utf-8'))
    if not report['passed'] or not all(report['checks'].values()):
        raise SystemExit(f'Tests failed. See {output / "run.log"}')
    if report.get('version') != '0.9' or report['count'] < 344:
        raise SystemExit('Expected the current v0.9 suite with at least 344 checks')
    print(f"PASS: {report['count']} checks. Report: {report_path}")


if __name__ == '__main__':
    run()
