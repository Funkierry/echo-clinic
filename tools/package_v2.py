from pathlib import Path
import hashlib, json, re, shutil, zipfile

root=Path(__file__).resolve().parents[1]
release=root/'release/EchoClinic-Windows-v0.2'
captures=root/'captures/v0.2'
report=json.loads((captures/'test-report.json').read_text(encoding='utf-8'))
assert report['passed'] and len(report['checks'])>=61 and all(report['checks'].values())
exe=release/'EchoClinic.exe'
assert exe.is_file()
shutil.copy2(root/'README-v0.2.md',release/'README.md')
shutil.copy2(captures/'test-report.json',release/'test-report.json')
shutil.copy2(captures/'echo-clinic-initial.png',release/'preview.png')
shutil.copy2(root/'tools/art-direction-v02.json',release/'art-direction.json')
digest=hashlib.sha256(exe.read_bytes()).hexdigest()
(release/'SHA256.txt').write_text(digest+'  EchoClinic.exe\n',encoding='utf-8')
winzip=root/'release/EchoClinic-Windows-v0.2.zip'
with zipfile.ZipFile(winzip,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
    for p in release.rglob('*'):
        if p.is_file(): z.write(p,p.relative_to(release.parent))
srczip=root/'release/EchoClinic-Godot-source-v0.2.zip'
with zipfile.ZipFile(srczip,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
    for p in (root/'project').rglob('*'):
        if not p.is_file() or '.godot' in p.parts: continue
        target=Path('echo-clinic')/p.relative_to(root)
        if p.name=='export_presets.cfg':
            text=p.read_text(encoding='utf-8')
            text=re.sub(r'custom_template/(debug|release)="[^"]*"',r'custom_template/\1=""',text)
            text=text.replace('../release/EchoClinic-Windows-v0.2/EchoClinic.exe','../EchoClinic.exe')
            z.writestr(str(target),text)
        else: z.write(p,target)
    z.write(root/'README-v0.2.md','echo-clinic/README.md')
    for name in ['.gitignore','tools/art-direction-v02.json','tools/prepare_audio_v2.py','tools/package_v2.py']:
        z.write(root/name,'echo-clinic/'+name)
    for p in (release/'licenses').rglob('*'):
        if p.is_file(): z.write(p,Path('echo-clinic/licenses')/p.relative_to(release/'licenses'))
    z.write(captures/'test-report.json','echo-clinic/test-report.json')
print(json.dumps({'exe':str(exe),'windows_zip':str(winzip),'source_zip':str(srczip),'exe_bytes':exe.stat().st_size,'zip_bytes':winzip.stat().st_size,'sha256':digest,'checks':len(report['checks'])},ensure_ascii=False,indent=2))
