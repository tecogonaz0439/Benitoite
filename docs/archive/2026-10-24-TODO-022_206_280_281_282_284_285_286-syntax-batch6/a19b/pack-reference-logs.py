"""二回の Lean の生出力をハッシュ付きで圧縮保存する。"""
import hashlib
import json
from pathlib import Path
import zipfile

HERE = Path(__file__).resolve().parent
for directory in ['reference-generate', 'reference-check']:
    folder = HERE / directory
    logs = sorted(folder.glob('*.log'))
    if not logs:
        continue
    index = {}
    with zipfile.ZipFile(folder / 'raw-logs.zip', 'w', zipfile.ZIP_DEFLATED) as archive:
        for path in logs:
            payload = path.read_bytes()
            index[path.name] = {'bytes': len(payload), 'sha256': hashlib.sha256(payload).hexdigest()}
            archive.writestr(path.name, payload)
    (folder / 'raw-logs-index.json').write_text(json.dumps(index, indent=2) + '\n')
    with zipfile.ZipFile(folder / 'raw-logs.zip') as archive:
        for name, record in index.items():
            assert hashlib.sha256(archive.read(name)).hexdigest() == record['sha256']
    for path in logs:
        path.unlink()
