"""局所比較の入力・出力を相対名とハッシュで永続保存する。"""
from pathlib import Path
import hashlib
import json
import os
import zipfile

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
index = []
with zipfile.ZipFile(OUT/'local-records.zip', 'w', zipfile.ZIP_DEFLATED) as archive:
    for prefix, directory in [('source', 'target/interval-x01b-final'),
                              ('comparison', 'target/interval-x01b-verified')]:
        source = ROOT/directory
        for path in sorted(source.rglob('*')):
            if not path.is_file():
                continue
            data = path.read_bytes()
            for private_path in [str(ROOT), str(Path.home()), os.path.realpath(os.path.join(os.sep, 'tmp'))]:
                assert private_path.encode() not in data, (prefix, path.name)
            name = prefix+'/'+path.relative_to(source).as_posix()
            archive.writestr(name, data)
            index.append(dict(path=name, bytes=len(data), sha256=hashlib.sha256(data).hexdigest()))
with zipfile.ZipFile(OUT/'local-records.zip') as archive:
    for row in index:
        assert hashlib.sha256(archive.read(row['path'])).hexdigest() == row['sha256']
(OUT/'local-records-index.json').write_text(json.dumps(index, indent=2)+'\n')
for name in ['source-summary.json', 'profile-manifest.json', 'fuel-selection.json']:
    (OUT/name).write_bytes((ROOT/'target/interval-x01b-verified'/name).read_bytes())
summary = dict(files=len(index), bytes=sum(row['bytes'] for row in index),
               zipBytes=(OUT/'local-records.zip').stat().st_size,
               zipSha256=hashlib.sha256((OUT/'local-records.zip').read_bytes()).hexdigest(),
               source=json.loads((OUT/'source-summary.json').read_text()))
(OUT/'local-summary.json').write_text(json.dumps(summary, indent=2)+'\n')
print(json.dumps(summary))
