"""K1 の生成済み報告・状態・容量を読み取り、永続の要約へ保存する。"""
import datetime
import hashlib
import json
from pathlib import Path
import runpy
import subprocess

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
redact = runpy.run_path(str(HERE/'run.py'))['redact']

def read(p):
    return json.loads(p.read_text())

def digest(p):
    h = hashlib.sha256()
    with p.open('rb') as f:
        for block in iter(lambda: f.read(1024*1024), b''):
            h.update(block)
    return h.hexdigest()

def write(name, value):
    (HERE/name).write_text(redact(json.dumps(value, ensure_ascii=False, indent=2))+'\n')

def main():
    before = read(HERE/'source-state-before.json')
    now = {name: digest(ROOT/name) for name in before['files']}
    changed = [name for name in now if now[name] != before['files'][name]]
    write('source-state-after.json', dict(head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
          status=subprocess.check_output(['git','status','--porcelain=v1'],cwd=ROOT,text=True),
          files=now, changed=changed))
    assert not changed
    roots = {name: ROOT/'target'/(name+'-diff')/'x05a-k1-run3-20261027' for name in ['interval','desugar','coverage']}
    size = {}
    for name, directory in roots.items():
        files = [p for p in directory.rglob('*') if p.is_file()]
        size[name] = dict(files=len(files), bytes=sum(p.stat().st_size for p in files),
            du=subprocess.check_output(['du','-sk',str(directory)],text=True).split()[0])
    parent = ROOT/'target/interval-diff'
    size['intervalParent'] = dict(du=subprocess.check_output(['du','-sk',str(parent)],text=True).split()[0])
    write('output-size.json', size)
    executables = [ROOT/'formal/.lake/build/bin'/name for name in ['desugarDiff','builtinCheck','coverageDiff','coverageProgramDiff','surfaceCheck','surfaceCheckAll','intervalDiff']]
    executables.append(ROOT/'target/debug/benitoite')
    write('executables.json', {p.relative_to(ROOT).as_posix():digest(p) for p in executables})
    result = dict(time=datetime.datetime.now().astimezone().isoformat(), size=size, sourceInputCount=len(now))
    for label, directory in roots.items():
        reports = {}
        for p in sorted(directory.glob('*.json')):
            if 'report' not in p.name:
                continue
            value = read(p)
            reports[p.name] = ({k:v for k,v in value.items() if not isinstance(v, (dict,list))}
                               if isinstance(value, dict) else dict(rows=len(value)))
        result[label+'Reports'] = reports
    interval = roots['interval']
    if (interval/'manifest.json').exists():
        manifest = read(interval/'manifest.json')
        result['manifest'] = {k:v for k,v in manifest.items() if k != 'artifacts'}
        result['artifacts'] = len(manifest['artifacts'])
        result['manifestSha256'] = digest(interval/'manifest.json')
        result['inputArtifacts'] = len(read(interval/'input-manifest.json')['artifacts'])
        result['manifestComparison'] = read(interval/'manifest-comparison.json')
    comparison = interval/'comparison'
    for key,name in [('profiles','profile-manifest.json'),('sources','real-source-summary.json')]:
        if (comparison/name).exists(): result[key] = read(comparison/name)
    write('evidence-summary.json',result)
    print(json.dumps(dict(sourceInputCount=len(now),changed=changed,size=size,hasFinalManifest='manifest' in result),ensure_ascii=False))

if __name__ == '__main__':
    main()
