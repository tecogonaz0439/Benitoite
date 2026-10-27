"""局所比較の入力・報告を、パスを伏せてハッシュとともに保管する。"""
import hashlib
import json
import os
from pathlib import Path
import zipfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
SOURCE = ROOT/'target/interval-diff/x03b'


def redacted(raw):
    for path, label in [(str(ROOT), '<repo>'), (str(Path.home()), '<home>'),
                        (os.path.realpath(os.path.join(os.sep, 'tmp')), '<tmp>'),
                        (os.path.join(os.sep, 'tmp')+os.sep, '<tmp>/')]:
        raw = raw.replace(path.encode(), label.encode())
    return raw


def main():
    entries, links = [], []
    archive = HERE/'local-records.zip'
    with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as output:
        for path in sorted(SOURCE.rglob('*')):
            name = path.relative_to(SOURCE).as_posix()
            if path.is_symlink():
                target = os.readlink(path)
                assert not os.path.isabs(target)
                links.append(dict(name=name, target=target))
            elif path.is_file():
                raw = path.read_bytes()
                saved = redacted(raw)
                output.writestr(name, saved)
                entries.append(dict(name=name, sourceSha256=hashlib.sha256(raw).hexdigest(),
                                    sha256=hashlib.sha256(saved).hexdigest(), size=len(saved)))
    with zipfile.ZipFile(archive) as saved:
        assert saved.namelist() == [e['name'] for e in entries]
        for entry in entries:
            assert hashlib.sha256(saved.read(entry['name'])).hexdigest() == entry['sha256']
    index = dict(archive=archive.name, sha256=hashlib.sha256(archive.read_bytes()).hexdigest(),
                 entries=entries, links=links)
    (HERE/'local-records-index.json').write_text(json.dumps(index, indent=2)+'\n')
    for source, target in [('vm/range/range-vm-summary.json', 'range-vm-summary.json'),
                           ('vm/vm-summary.json', 'arithmetic-vm-summary.json'),
                           ('real-source-summary.json', 'real-source-summary.json'),
                           ('profile-manifest.json', 'profile-manifest.json')]:
        (HERE/target).write_bytes(redacted((SOURCE/'comparison-verified'/source).read_bytes()))
    print(json.dumps(dict(files=len(entries), links=len(links), bytes=archive.stat().st_size)))


if __name__ == '__main__':
    main()
