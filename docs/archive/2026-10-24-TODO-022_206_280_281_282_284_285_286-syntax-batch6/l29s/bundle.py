"""自分が作った検査記録を、リンクも含めて保存・照合する。"""
from pathlib import Path
import hashlib
import json
import os
import stat
import zipfile

OUT = Path(__file__).resolve().parent
source = OUT / 'test-records'
index, links = {}, {}
with zipfile.ZipFile(OUT/'test-records.zip', 'w', zipfile.ZIP_DEFLATED) as archive:
    for path in sorted(source.rglob('*')):
        name = path.relative_to(source).as_posix()
        if path.is_symlink():
            target = os.readlink(path)
            assert not Path(target).is_absolute()
            data = target.encode()
            info = zipfile.ZipInfo(name)
            info.create_system = 3
            info.external_attr = (stat.S_IFLNK | 0o777) << 16
            archive.writestr(info, data)
            links[name] = target
        elif path.is_file():
            data = path.read_bytes()
            archive.writestr(name, data)
        else:
            continue
        index[name] = hashlib.sha256(data).hexdigest()
with zipfile.ZipFile(OUT/'test-records.zip') as archive:
    assert archive.testzip() is None
    assert set(archive.namelist()) == set(index)
    for name, digest in index.items():
        assert hashlib.sha256(archive.read(name)).hexdigest() == digest
(OUT/'test-records-index.json').write_text(json.dumps(dict(sha256=index, symlinks=links), indent=2)+'\n')
for name in ['profile-manifest.json', 'fuel-selection.json']:
    (OUT/name).write_bytes((source/name).read_bytes())
for path in sorted(source.rglob('*'), reverse=True):
    if path.is_symlink() or path.is_file():
        path.unlink()
    elif path.is_dir():
        path.rmdir()
source.rmdir()
print(json.dumps(dict(archivedFiles=len(index), symlinks=links)))
