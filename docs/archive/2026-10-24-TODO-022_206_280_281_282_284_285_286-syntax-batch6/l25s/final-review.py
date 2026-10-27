"""最終のソースと保存物のハッシュ、パスの伏せ字、終了状態を照合する。"""
from datetime import datetime
from pathlib import Path
import ast
import hashlib
import json
import re
import subprocess
import zipfile
import run

OUT, ROOT = run.OUT, run.ROOT
work = json.loads((OUT / 'work-check.json').read_text())
assert work['check_exit'] == 0
assert json.loads((OUT / 'work.json').read_text())['exit'] == 1
assert 'time: sysctl kern.clockrate: Operation not permitted' in (OUT / 'work.log').read_text()
assert 'selected checks passed' in (OUT / 'work.log').read_text()
index = json.loads((OUT / 'development-logs-index.json').read_text())
assert all(item['result']['exit'] == 0 for item in index if 'result' in item)
for path in OUT.glob('*.py'):
    ast.parse(path.read_text(), str(path.relative_to(ROOT)))
for path in OUT.rglob('*'):
    if not path.is_file():
        continue
    contents = [path.read_bytes()]
    if path.suffix == '.zip':
        with zipfile.ZipFile(path) as bundle:
            assert bundle.testzip() is None
            contents = [bundle.read(name) for name in bundle.namelist()]
    for content in contents:
        assert str(ROOT).encode() not in content, str(path.relative_to(ROOT))
        assert str(Path.home()).encode() not in content, str(path.relative_to(ROOT))

subprocess.run(['git', 'diff', '--check'], cwd=ROOT, check=True)
changed = subprocess.check_output(['git', 'diff', run.BASE, '--name-only'], cwd=ROOT, text=True).splitlines()
artifacts = [str(path.relative_to(ROOT)) for path in OUT.rglob('*')
             if path.is_file() and path.name != 'final-review.json']
record = dict(checked_at=datetime.now().astimezone().isoformat(), base=run.BASE,
              files={name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
                     for name in sorted(changed + artifacts)})
(OUT / 'final-review.json').write_text(json.dumps(record, ensure_ascii=False, indent=2) + '\n')
print(f'最終の {len(record["files"])} ファイルのハッシュ、終了状態、パス表記を確認した。')
