from pathlib import Path
import zipfile, hashlib, json, shutil

root=Path(__file__).resolve().parents[1]
release=root/'release'/'EchoClinic-Windows-v0.1'
report=json.loads((root/'captures'/'test-report.json').read_text())
assert report['passed'] and all(report['checks'].values()), 'Verification failed'
shutil.copy2(root/'captures'/'test-report.json',release/'test-report.json')
shutil.copy2(root/'captures'/'echo-clinic-initial.png',release/'preview.png')
exe=release/'EchoClinic.exe'
digest=hashlib.sha256(exe.read_bytes()).hexdigest()
(release/'SHA256.txt').write_text(digest+'  EchoClinic.exe\n',encoding='utf-8')
archive_path=root/'release'/'EchoClinic-Windows-v0.1.zip'
with zipfile.ZipFile(archive_path,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as archive:
    for p in release.rglob('*'):
        if p.is_file(): archive.write(p,p.relative_to(release.parent))
source_path=root/'release'/'EchoClinic-Godot-source-v0.1.zip'
with zipfile.ZipFile(source_path,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as archive:
    for p in (root/'project').rglob('*'):
        if p.is_file() and '.godot' not in p.parts: archive.write(p,Path('echo-clinic')/p.relative_to(root))
    for name in ['README.md','.gitignore','tools/bootstrap.py','tools/prepare_assets.py','tools/package_release.py','tools/release.json']:
        archive.write(root/name,Path('echo-clinic')/name)
    for p in (release/'licenses').iterdir(): archive.write(p,Path('echo-clinic')/'licenses'/p.name)
print(json.dumps({'executable':str(exe),'exe_bytes':exe.stat().st_size,'sha256':digest,'windows_zip':str(archive_path),'zip_bytes':archive_path.stat().st_size,'source_zip':str(source_path),'source_bytes':source_path.stat().st_size},ensure_ascii=False,indent=2))
