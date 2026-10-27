"""逐次ビルドと参照計算の生ログを、終了状態の索引付きで圧縮する。"""
from pathlib import Path
import hashlib
import json
import zipfile

OUT = Path(__file__).resolve().parent
groups = [
    (OUT, 'development-logs.zip', sorted(
        path for path in OUT.iterdir()
        if path.suffix in ['.json', '.log'] and
        path.name.startswith(('regression-Benitoite', 'final-Benitoite', 'ready-Benitoite')))),
    (OUT / 'reference-output', 'raw-logs.zip', sorted((OUT / 'reference-output').glob('*.lean.log'))),
]
for directory, archive, paths in groups:
    if not paths:
        continue
    index = []
    with zipfile.ZipFile(directory / archive, 'w', zipfile.ZIP_DEFLATED) as bundle:
        for path in paths:
            content = path.read_bytes()
            bundle.writestr(path.name, content)
            item = dict(name=path.name, bytes=len(content), sha256=hashlib.sha256(content).hexdigest())
            if path.suffix == '.json':
                item['result'] = json.loads(content)
            index.append(item)
    (directory / (archive.removesuffix('.zip') + '-index.json')).write_text(
        json.dumps(index, ensure_ascii=False, indent=2) + '\n')
    for path in paths:
        path.unlink()
    print(f'{archive}: {len(paths)} logs')
