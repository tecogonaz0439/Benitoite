"""局所の入出力を相対名とハッシュ付きの ZIP に保存する。元の出力は消さない。"""
import hashlib
import json
import os
from pathlib import Path
import shutil
import stat
import zipfile

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
names = ['x02a-identity', 'x02a-scope', 'x02a-exchange', 'x02a-manifest-check', 'x02a-scope-check']
entries = []
with zipfile.ZipFile(HERE/'local-records.zip', 'w', zipfile.ZIP_DEFLATED) as archive:
    for directory in names:
        for path in sorted((ROOT/'target'/directory).rglob('*')):
            if path.is_symlink():
                data = os.readlink(path).encode()
                info = zipfile.ZipInfo(str(path.relative_to(ROOT/'target')))
                info.create_system = 3
                info.external_attr = (stat.S_IFLNK | 0o777) << 16
                archive.writestr(info, data)
                kind = 'symlink'
            elif path.is_file():
                data = path.read_bytes()
                assert str(ROOT).encode() not in data and str(Path.home()).encode() not in data, path.name
                archive.writestr(str(path.relative_to(ROOT/'target')), data)
                kind = 'file'
            else:
                continue
            entries.append(dict(name=str(path.relative_to(ROOT/'target')), kind=kind,
                                bytes=len(data), sha256=hashlib.sha256(data).hexdigest()))
with zipfile.ZipFile(HERE/'local-records.zip') as archive:
    assert len(archive.infolist()) == len(entries)
    for entry in entries:
        data = archive.read(entry['name'])
        assert len(data) == entry['bytes'] and hashlib.sha256(data).hexdigest() == entry['sha256']
(HERE/'local-records-index.json').write_text(json.dumps(entries, indent=2)+'\n')
for source, name in [('x02a-manifest-check/manifest-comparison.json', 'identity-manifest-comparison.json'),
                     ('x02a-scope-check/manifest-comparison.json', 'scope-manifest-comparison.json'),
                     ('x02a-exchange/profile-manifest.json', 'profile-manifest.json'),
                     ('x02a-exchange/fuel-selection.json', 'fuel-selection.json')]:
    shutil.copyfile(ROOT/'target'/source, HERE/name)
print(json.dumps(dict(entries=len(entries), bytes=(HERE/'local-records.zip').stat().st_size)))
