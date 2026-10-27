"""局所試行の入力・報告・manifest を保存し、ZIP の全項目を読み戻す。"""
import hashlib
import json
from pathlib import Path
import runpy
import zipfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
redact = runpy.run_path(str(HERE/'run.py'))['redact']


def main():
    rows = []
    with zipfile.ZipFile(HERE/'local-records.zip', 'w', zipfile.ZIP_DEFLATED) as archive:
        for label in ('interval', 'desugar', 'coverage'):
            directory = ROOT/'target'/(label+'-diff')/'x04a-local'
            for path in sorted(directory.rglob('*')):
                if path.is_dir():
                    continue
                content = path.read_bytes()
                original_hash = hashlib.sha256(content).hexdigest()
                try:
                    content = redact(content.decode()).encode()
                except UnicodeDecodeError:
                    pass
                name = label+'/'+path.relative_to(directory).as_posix()
                archive.writestr(name, content)
                row = dict(path=name, bytes=len(content), sha256=hashlib.sha256(content).hexdigest(),
                           originalSha256=original_hash)
                if path.is_symlink():
                    row['link'] = path.readlink().as_posix()
                rows.append(row)
    with zipfile.ZipFile(HERE/'local-records.zip') as archive:
        assert archive.testzip() is None
        for row in rows:
            assert hashlib.sha256(archive.read(row['path'])).hexdigest() == row['sha256']
    index = dict(files=rows, count=len(rows),
                 redactedCount=sum(r['sha256'] != r['originalSha256'] for r in rows))
    (HERE/'local-records-index.json').write_text(json.dumps(index, indent=2)+'\n')
    manifest = json.loads((ROOT/'target/interval-diff/x04a-local/manifest.json').read_text())
    (HERE/'local-summary.json').write_text(json.dumps(dict(
        artifactCount=len(manifest['artifacts']), counts=manifest['counts'],
        zipSha256=hashlib.sha256((HERE/'local-records.zip').read_bytes()).hexdigest()),
        ensure_ascii=False, indent=2)+'\n')
    print(json.dumps(dict(files=len(rows), redactedFiles=index['redactedCount'],
                         zipBytes=(HERE/'local-records.zip').stat().st_size)))


if __name__ == '__main__':
    main()
