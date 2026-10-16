"""Assemble the current v0.9 Windows release folder and zips. Refuses to package unless both the
source self-test and the exported-exe self-test passed with the same number of checks."""
from pathlib import Path
import hashlib, json, re, shutil, subprocess, zipfile

root = Path(__file__).resolve().parents[1]
VERSION = '0.9.1-prototype'
release = root / f'release/EchoClinic-Windows-v{VERSION}'
source_report_path = root / f'captures/v{VERSION}/test-report.json'
source_report = json.loads(source_report_path.read_text(encoding='utf-8'))
assert source_report['passed'] and all(source_report['checks'].values()), 'source self-test failed'
export_report_path = root / f'captures/v{VERSION}-export/test-report.json'
export_report = json.loads(export_report_path.read_text(encoding='utf-8'))
assert export_report['passed'] and all(export_report['checks'].values()), 'exported exe self-test failed'
assert export_report['count'] >= 344, export_report['count']
assert source_report['count'] == export_report['count'], 'source and export check counts differ'
exe = release / 'EchoClinic.exe'
assert exe.is_file()

shutil.copy2(root / 'README-v0.9.md', release / 'README.md')
shutil.copy2(export_report_path, release / 'export-test-report.json')
shutil.copy2(source_report_path, release / 'source-test-report.json')
shots = root / f'captures/v{VERSION}-export'
for name, target in [('01-clinic.png', 'preview.png'), ('16-start-menu.png', 'start-menu.png'), ('19-context-menu.png', 'context-menu.png'), ('21-recycle.png', 'recycle.png'), ('23-welcome.png', 'welcome.png')]:
    shutil.copy2(shots / name, release / target)
shutil.copytree(root / 'licenses', release / 'licenses', dirs_exist_ok=True)
probe = root / 'captures/npc-probe-v0.8-final/npc-probe.md'
if probe.is_file():
    shutil.copy2(probe, release / 'npc-probe.md')
digest = hashlib.sha256(exe.read_bytes()).hexdigest()
(release / 'SHA256.txt').write_text(digest + '  EchoClinic.exe\n', encoding='utf-8')

winzip = root / f'release/EchoClinic-Windows-v{VERSION}.zip'
with zipfile.ZipFile(winzip, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
    for path in release.rglob('*'):
        if path.is_file():
            archive.write(path, path.relative_to(release.parent))

srczip = root / f'release/EchoClinic-Godot-source-v{VERSION}.zip'
# Use Git's tracked manifest so source, tools, credits and older dependency files
# are complete, while local credentials, caches and captures stay excluded.
source_names = subprocess.check_output(['git', 'ls-files', '-z'], cwd=root).decode('utf-8').split('\0')
with zipfile.ZipFile(srczip, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
    for name in sorted(filter(None, source_names)):
        path = root / name
        if not path.is_file():
            continue
        target = Path('echo-clinic') / name
        if path.name == 'export_presets.cfg':
            # Machine-specific template paths never ship.
            content = path.read_text(encoding='utf-8')
            content = re.sub(r'custom_template/(debug|release)="[^"]*"', r'custom_template/\1=""', content)
            archive.writestr(str(target), content)
        else:
            archive.write(path, target)

checksum_path = root / f'release/CHECKSUMS-v{VERSION}.sha256'
checksum_path.write_text(''.join(hashlib.sha256(path.read_bytes()).hexdigest() + '  ' + path.name + '\n' for path in [winzip, srczip]), encoding='utf-8')

print(json.dumps({'exe': str(exe), 'exe_mb': round(exe.stat().st_size / 1e6, 1), 'windows_zip_mb': round(winzip.stat().st_size / 1e6, 1),
                  'source_zip_mb': round(srczip.stat().st_size / 1e6, 1), 'sha256': digest, 'checks': export_report['count']}, ensure_ascii=False, indent=2))
