"""短い試行の入力と全報告を保管し、ハッシュで読み戻す。"""
import hashlib
import json
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
BASE = ROOT/'target/interval-diff/x05r-local'
DESUGAR = ROOT/'target/desugar-diff/x05r-local'
rows = []
with zipfile.ZipFile(HERE/'local-records.zip', 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
    directories = [BASE/'manifest', BASE/'final-comparison', BASE/'fixed',
                   ROOT/'target/interval-diff/x05r-indexed-final', DESUGAR]
    selected = [(directory, directory.relative_to(ROOT).as_posix()) for directory in directories]
    for directory, label in selected:
        for path in sorted(directory.rglob('*')):
            if path.is_dir():
                continue
            data = path.read_bytes()
            assert b'/Users/' not in data and b'/private/var/folders/' not in data, path.name
            name = label+'/'+path.relative_to(directory).as_posix()
            archive.writestr(name, data)
            rows.append(dict(path=name, bytes=len(data), sha256=hashlib.sha256(data).hexdigest()))
with zipfile.ZipFile(HERE/'local-records.zip') as archive:
    assert sorted(archive.namelist()) == sorted(r['path'] for r in rows)
    for row in rows:
        data = archive.read(row['path'])
        assert len(data) == row['bytes'] and hashlib.sha256(data).hexdigest() == row['sha256']
result = dict(files=rows, count=len(rows), bytes=sum(row['bytes'] for row in rows),
              zipBytes=(HERE/'local-records.zip').stat().st_size,
              zipSha256=hashlib.sha256((HERE/'local-records.zip').read_bytes()).hexdigest())
(HERE/'local-records-index.json').write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k != 'files'}))
