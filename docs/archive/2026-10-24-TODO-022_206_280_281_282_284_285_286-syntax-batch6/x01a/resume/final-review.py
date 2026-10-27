# -*- coding: utf-8 -*-
import hashlib
import json
from pathlib import Path
import re
import subprocess
import zipfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]

def main():
    after = json.loads((HERE/'inputs-after.json').read_text())
    for path, expected in after['sha256'].items():
        assert hashlib.sha256((ROOT/path).read_bytes()).hexdigest() == expected, path
    report = HERE.parent/'results.md'
    text = report.read_text()
    assert 'FINISH_TIME' not in text and 'ELAPSED_TIME' not in text
    links = re.findall(r'\]\(([^)]+)\)',text)
    for target in links:
        if not target.startswith(('http:', 'https:', '#')):
            assert (report.parent/target.split('#')[0]).exists(), target
    for path in HERE.glob('*.py'):
        compile(path.read_text(),str(path.relative_to(HERE)),'exec')
    for path in HERE.glob('*.json'):
        json.loads(path.read_text())
    for path in HERE.rglob('*'):
        if path.is_file() and path.suffix in ['.md','.py','.json','.log']:
            value=path.read_text()
            assert str(ROOT) not in value and str(Path.home()) not in value, path.name
    assert str(ROOT) not in text and str(Path.home()) not in text
    with zipfile.ZipFile(HERE/'local-records.zip') as bundle:
        index=json.loads((HERE/'local-records-index.json').read_text())
        assert len(index)==len(bundle.namelist())==547
        for item in index:
            value=bundle.read(item['path'])
            assert hashlib.sha256(value).hexdigest()==item['sha256'],item['path']
            assert str(ROOT).encode() not in value and str(Path.home()).encode() not in value
    assert subprocess.check_output(['git','branch','--show-current'],cwd=ROOT,text=True).strip()=='mod012/X01a'
    subprocess.run(['git','diff','--check'],cwd=ROOT,check=True)
    result=dict(ok=True, unchangedInputs=len(after['sha256']),links=len(links),archiveEntries=len(index))
    (HERE/'final-review.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result))

if __name__=='__main__':
    main()
