from pathlib import Path
import hashlib, json, re, shutil, zipfile

root = Path(__file__).resolve().parents[1]
release = root / 'release/EchoClinic-Windows-v0.7.0'
captures = root / 'captures/v0.7'
report = json.loads((captures / 'test-report.json').read_text(encoding='utf-8'))
assert report['passed'] and len(report['checks']) >= 224 and all(report['checks'].values())
export_report = json.loads((root / 'captures/v0.7-export/test-report.json').read_text(encoding='utf-8'))
assert export_report['passed'] and export_report['count'] == report['count']
exe = release / 'EchoClinic.exe'
assert exe.is_file()
shutil.copy2(root / 'README-v0.7.md', release / 'README.md')
shutil.copy2(captures / 'test-report.json', release / 'test-report.json')
shutil.copy2(root / 'captures/v0.7-export/test-report.json', release / 'export-test-report.json')
shutil.copy2(captures / '03-lounge.png', release / 'preview.png')
shutil.copy2(captures / '02-workshop.png', release / 'workshop.png')
shutil.copy2(captures / '04-casebook.png', release / 'casebook.png')
shutil.copy2(root / 'tools/art-direction-v03.json', release / 'art-direction.json')
shutil.copytree(root / 'licenses', release / 'licenses', dirs_exist_ok=True)
digest = hashlib.sha256(exe.read_bytes()).hexdigest()
(release / 'SHA256.txt').write_text(digest + '  EchoClinic.exe\n', encoding='utf-8')
winzip = root / 'release/EchoClinic-Windows-v0.7.0.zip'
with zipfile.ZipFile(winzip, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
    for path in release.rglob('*'):
        if path.is_file():
            archive.write(path, path.relative_to(release.parent))
srczip = root / 'release/EchoClinic-Godot-source-v0.7.0.zip'
with zipfile.ZipFile(srczip, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
    for path in (root / 'project').rglob('*'):
        if not path.is_file() or '.godot' in path.parts:
            continue
        target = Path('echo-clinic') / path.relative_to(root)
        if path.name == 'export_presets.cfg':
            content = path.read_text(encoding='utf-8')
            content = re.sub(r'custom_template/(debug|release)="[^"]*"', r'custom_template/\1=""', content)
            content = content.replace('../release/EchoClinic-Windows-v0.7.0/EchoClinic.exe', '../EchoClinic.exe')
            archive.writestr(str(target), content)
        else:
            archive.write(path, target)
    for name in ['README.md', 'README-v0.7.md', 'CHANGELOG.md', 'CREDITS.md', '.gitignore', '.gitattributes', 'tools/art-direction-v03.json', 'tools/prepare_audio_v2.py', 'tools/package_v7.py', 'tools/mock_deepseek_v7.py', 'tools/test_v7.py']:
        archive.write(root / name, 'echo-clinic/' + name)
    for path in (root / 'docs').rglob('*'):
        if path.is_file(): archive.write(path, Path('echo-clinic') / path.relative_to(root))
    for path in (release / 'licenses').rglob('*'):
        if path.is_file(): archive.write(path, Path('echo-clinic/licenses') / path.relative_to(release / 'licenses'))
    archive.write(captures / 'test-report.json', 'echo-clinic/test-report.json')
print(json.dumps({'exe': str(exe), 'windows_zip': str(winzip), 'source_zip': str(srczip), 'exe_bytes': exe.stat().st_size, 'zip_bytes': winzip.stat().st_size, 'sha256': digest, 'checks': len(report['checks'])}, ensure_ascii=False, indent=2))
