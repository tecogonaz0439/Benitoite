"""作業末の入力・記録・参照・パスを読み取りで点検する。"""
from pathlib import Path
import ast
import hashlib
import json
import re
import subprocess
import zipfile
import run

OUT, ROOT = run.OUT, run.ROOT
subprocess.run(['python3', '-B', str(OUT/'audit.py')], cwd=ROOT, check=True, stdout=subprocess.DEVNULL)
assert json.loads((OUT/'work-check.json').read_text())['check_exit'] == 0
work = (OUT/'work.log').read_text()
assert '7 passed; 0 failed' in work and 'selected checks passed' in work
assert 'maximum resident set size' not in work
assert 'sysctl kern.clockrate: Operation not permitted' in work
assert 'sorryAx' not in (OUT/'axioms.log').read_text()
assert len(re.findall(r"depends on axioms", (OUT/'axioms.log').read_text())) == 16
leaks, links, archives = [], [], {}
for path in OUT.rglob('*'):
    if not path.is_file():
        continue
    if path.suffix == '.zip':
        with zipfile.ZipFile(path) as archive:
            indexname = 'development-logs-index.json' if path.name.startswith('development') else 'raw-logs-index.json'
            index = json.loads((path.parent/indexname).read_text())
            assert set(archive.namelist()) == set(index)
            for name in archive.namelist():
                raw = archive.read(name)
                assert hashlib.sha256(raw).hexdigest() == index[name]['sha256']
                if re.search(rb'/Users/|/private/tmp/|/var/folders/', raw):
                    leaks.append(str(path.relative_to(ROOT)) + ':' + name)
            archives[str(path.relative_to(ROOT))] = len(index)
        continue
    content = path.read_text()
    if re.search(r'/Users/|/private/tmp/|/var/folders/', content):
        # 正規表現の点検器自身には、検出対象の断片がある。
        if path != Path(__file__).resolve():
            leaks.append(str(path.relative_to(ROOT)))
    if path.suffix == '.py':
        ast.parse(content, filename=str(path.relative_to(ROOT)))
    if path.suffix == '.md':
        for target in re.findall(r'\]\(([^)]+)\)', content):
            assert not target.startswith('/'), target
            assert (path.parent/target.split('#')[0]).exists() or target == 'final-review.json', target
            links.append(target)
assert not leaks, leaks
inputs = {}
for path in subprocess.check_output(['git','diff',run.BASE,'--name-only'],cwd=ROOT,text=True).splitlines():
    inputs[path] = hashlib.sha256((ROOT/path).read_bytes()).hexdigest()
assert len(inputs) == 6, inputs
assert not subprocess.check_output(['git','diff','--cached','--name-only'],cwd=ROOT,text=True).strip()
assert subprocess.check_output(['git','branch','--show-current'],cwd=ROOT,text=True).strip() == 'mod012/L25T'
assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip() == run.BASE
impact = json.loads((OUT/'reference-impact.json').read_text())
assert set(impact['body']['shapes']) == {'with','nestedWith'}
assert sum(s['changed'] for s in impact['body']['shapes'].values()) == 158
assert sum(s['added'] for s in impact['body']['shapes'].values()) == 6
assert not any(s['removed'] for s in impact['body']['shapes'].values())
subprocess.run(['git','diff','--check'],cwd=ROOT,check=True)
record = dict(base=run.BASE, head=run.BASE, inputs_sha256=inputs, archives=archives,
              relative_links=len(links), syntax='success', path_redaction='success',
              work_check_exit=0, maximum_resident_set_size='unavailable: sandbox sysctl denied')
(OUT/'final-review.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n')
assert all((OUT/target.split('#')[0]).exists() for target in links)
print(json.dumps(record,ensure_ascii=False,indent=2))
