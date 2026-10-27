"""局所試行の生の記録をgitignore下に保管し、索引と全文を読み戻す。"""
import hashlib
import json
from pathlib import Path
import stat
import zipfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]


def digest(data):
    return hashlib.sha256(data).hexdigest()


def main():
    source = ROOT/'target/x05s-records'
    output = ROOT/'work/m012/records/x05s-local-records.zip'
    output.parent.mkdir(parents=True, exist_ok=True)
    assert not output.exists(), 'archive must be new'
    rows = []
    with zipfile.ZipFile(output, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as saved:
        for path in sorted(source.rglob('*')):
            if path.is_dir():
                continue
            name = path.relative_to(ROOT).as_posix()
            row = dict(path=name)
            if path.is_symlink():
                link = path.readlink().as_posix()
                assert not Path(link).is_absolute() and '..' not in Path(link).parts
                data = link.encode()
                info = zipfile.ZipInfo(name)
                info.create_system = 3
                info.external_attr = (stat.S_IFLNK | 0o777) << 16
                saved.writestr(info, data)
                row['link'] = link
            else:
                data = path.read_bytes()
                saved.writestr(name, data)
            rows.append(dict(row, bytes=len(data), sha256=digest(data)))
    with zipfile.ZipFile(output) as saved:
        assert set(saved.namelist()) == {r['path'] for r in rows}
        for row in rows:
            data = saved.read(row['path'])
            assert len(data) == row['bytes'] and digest(data) == row['sha256']
    result = dict(archive=output.relative_to(ROOT).as_posix(), bytes=output.stat().st_size,
                  sha256=digest(output.read_bytes()), files=rows, count=len(rows),
                  originalBytes=sum(r['bytes'] for r in rows))
    (HERE/'local-records-index.json').write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n')
    print(json.dumps({k: v for k, v in result.items() if k != 'files'}, ensure_ascii=False))


if __name__ == '__main__':
    main()
