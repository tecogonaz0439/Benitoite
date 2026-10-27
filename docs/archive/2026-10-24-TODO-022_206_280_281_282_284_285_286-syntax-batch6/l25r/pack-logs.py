"""反復した開発検査の生出力と終了状態を、索引付きで保管する。"""
from pathlib import Path
import hashlib
import json
import zipfile
OUT = Path(__file__).resolve().parent
assert not (OUT/'development-logs.zip').exists(), '保存済みのログは上書きしない。'
paths = sorted(path for path in OUT.iterdir()
    if path.suffix in ['.log', '.json'] and path.name.startswith(('dev', 'final-build-', 'comments-final-')))
entries = []
with zipfile.ZipFile(OUT/'development-logs.zip', 'w', zipfile.ZIP_DEFLATED) as archive:
    for path in paths:
        content = path.read_bytes()
        archive.writestr(path.name, content)
        row = dict(name=path.name, bytes=len(content), sha256=hashlib.sha256(content).hexdigest())
        if path.suffix == '.json':
            row['run'] = json.loads(content)
        entries.append(row)
with zipfile.ZipFile(OUT/'development-logs.zip') as archive:
    assert archive.testzip() is None
    for row in entries:
        assert hashlib.sha256(archive.read(row['name'])).hexdigest() == row['sha256']
(OUT/'development-logs-index.json').write_text(json.dumps(entries, ensure_ascii=False, indent=2)+'\n')
for path in paths:
    path.unlink()
print(f'開発ログ {len(entries)} ファイルを保存・照合した。')
