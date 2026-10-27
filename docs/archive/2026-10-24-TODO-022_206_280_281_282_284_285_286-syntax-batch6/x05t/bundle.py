"""局所試行の生の記録を gitignore の ZIP へ保存し、全項目を読み戻す。"""
import hashlib
import json
from pathlib import Path
import sys
import zipfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(HERE))
from run import redact
from state import digest


def main():
    archive = ROOT/'work/m012/records/x05t-local-records.zip'
    assert not archive.exists(), 'archive must be fresh'
    archive.parent.mkdir(parents=True, exist_ok=True)
    entries = []
    with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as output:
        for path in sorted((ROOT/'target/x05t-check').rglob('*')):
            if not path.is_file():
                continue
            assert not path.is_symlink(), 'unexpected local artifact link'
            name = path.relative_to(ROOT).as_posix()
            data = path.read_bytes()
            original = hashlib.sha256(data).hexdigest()
            if path.suffix in ('.json', '.stdout', '.stderr', '.log', '.bnt'):
                data = redact(data.decode()).encode()
            output.writestr(name, data)
            entries.append(dict(path=name, bytes=len(data), sha256=hashlib.sha256(data).hexdigest(),
                                originalSha256=original))
    with zipfile.ZipFile(archive) as output:
        assert output.namelist() == [e['path'] for e in entries]
        for entry in entries:
            assert hashlib.sha256(output.read(entry['path'])).hexdigest() == entry['sha256']
    record = dict(archive=archive.relative_to(ROOT).as_posix(), zipBytes=archive.stat().st_size,
                  zipSha256=digest(archive), entries=entries, files=len(entries),
                  bytes=sum(e['bytes'] for e in entries), readBackMatched=True)
    (HERE/'local-records-index.json').write_text(json.dumps(record, ensure_ascii=False, indent=2)+'\n')
    print(json.dumps({k: v for k, v in record.items() if k != 'entries'}), flush=True)


if __name__ == '__main__':
    main()
