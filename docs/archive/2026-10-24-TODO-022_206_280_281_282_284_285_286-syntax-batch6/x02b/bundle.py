"""局所比較の元入力・報告を、相対名とハッシュを付けて保存する。"""
import hashlib
import json
from pathlib import Path
import stat
import zipfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
SOURCES = {'identity': 'target/x02b-identity-final',
           'scope': 'target/x02b-scope-observed',
           'range': 'target/x02b-range-observed',
           'comparison': 'target/x02b-comparison-final'}


def main():
    index = []
    with zipfile.ZipFile(HERE/'local-records.zip', 'w', zipfile.ZIP_DEFLATED) as archive:
        for group, source in SOURCES.items():
            for path in sorted((ROOT/source).rglob('*')):
                if path.is_dir():
                    continue
                name = group+'/'+path.relative_to(ROOT/source).as_posix()
                if path.is_symlink():
                    data = path.readlink().as_posix().encode()
                    entry = zipfile.ZipInfo(name)
                    entry.create_system = 3
                    entry.external_attr = (stat.S_IFLNK | 0o777) << 16
                    archive.writestr(entry, data)
                else:
                    data = path.read_bytes()
                    assert str(ROOT).encode() not in data and str(Path.home()).encode() not in data, name
                    archive.writestr(name, data)
                index.append(dict(path=name, bytes=len(data), sha256=hashlib.sha256(data).hexdigest(),
                                  symlink=path.is_symlink()))
    with zipfile.ZipFile(HERE/'local-records.zip') as archive:
        assert archive.testzip() is None
        for row in index:
            assert hashlib.sha256(archive.read(row['path'])).hexdigest() == row['sha256']
    result = dict(entries=index, zipSha256=hashlib.sha256((HERE/'local-records.zip').read_bytes()).hexdigest())
    (HERE/'local-records-index.json').write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps(dict(files=len(index), zipBytes=(HERE/'local-records.zip').stat().st_size,
                          zipSha256=result['zipSha256'])))


if __name__ == '__main__':
    main()
