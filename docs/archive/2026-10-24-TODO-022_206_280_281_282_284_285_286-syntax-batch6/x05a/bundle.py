"""K1 の出力を永続の ZIP とハッシュ索引へ保存し、全項目を読み戻す。"""
import hashlib
import json
import os
from pathlib import Path
import re
import runpy
import tempfile
import zipfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
redact = runpy.run_path(str(HERE/'run.py'))['redact']


def file_hash(path):
    result = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024*1024), b''):
            result.update(chunk)
    return result.hexdigest()


def copy_redacted(path, output):
    # 全件の manifest は数 GB になる。分割の境目をまたぐパスも伏せる。
    substitutions = {s.encode(): label.encode() for s, label in (
        (str(ROOT), '<repo>'), (str(Path.home()), '<home>'),
        (os.path.realpath(tempfile.gettempdir()), '<tmp>'),
        (tempfile.gettempdir(), '<tmp>'), ('/private/tmp', '<tmp>'), ('/tmp/', '<tmp>/'))}
    pattern = re.compile(b'|'.join(re.escape(s) for s in sorted(substitutions, key=len, reverse=True)))
    overlap = max(map(len, substitutions))
    original, stored = hashlib.sha256(), hashlib.sha256()
    size, buffer = 0, b''
    with path.open('rb') as stream:
        while True:
            chunk = stream.read(1024*1024)
            original.update(chunk)
            buffer += chunk
            cutoff = max(0, len(buffer)-overlap) if chunk else len(buffer)
            for match in pattern.finditer(buffer):
                if match.start() < cutoff < match.end():
                    cutoff = match.start()
                    break
            content = pattern.sub(lambda m: substitutions[m.group()], buffer[:cutoff])
            buffer = buffer[cutoff:]
            output.write(content)
            stored.update(content)
            size += len(content)
            if not chunk:
                break
    return dict(bytes=size, sha256=stored.hexdigest(), originalSha256=original.hexdigest())


def main():
    rows = []
    pending = HERE/'k1-records.pending.zip'
    with zipfile.ZipFile(pending, 'w', zipfile.ZIP_DEFLATED, compresslevel=3) as archive:
        for label in ('interval', 'desugar', 'coverage'):
            directory = ROOT/'target'/(label+'-diff')/'x05a-k1-20261027'
            for path in sorted(directory.rglob('*')):
                if path.is_dir():
                    continue
                name = label+'/'+path.relative_to(directory).as_posix()
                # 巨大な再生成入力はハッシュで索引する。報告とログは大きさで省かない。
                if path.stat().st_size > 16*1024*1024 and not (
                    path.name.endswith(('.log', '.report.json', '-report.json'))):
                    rows.append(dict(path=name, bytes=path.stat().st_size,
                                     originalSha256=file_hash(path), persisted=False,
                                     reason='largeGeneratedInput; source state and input hashes saved'))
                    continue
                with archive.open(name, 'w', force_zip64=True) as output:
                    row = dict(path=name, persisted=True, **copy_redacted(path, output))
                if path.is_symlink():
                    row['link'] = redact(path.readlink().as_posix())
                rows.append(row)
    with zipfile.ZipFile(pending) as archive:
        assert archive.testzip() is None
        for row in rows:
            if not row['persisted']:
                continue
            result = hashlib.sha256()
            with archive.open(row['path']) as stream:
                for chunk in iter(lambda: stream.read(1024*1024), b''):
                    result.update(chunk)
            assert result.hexdigest() == row['sha256']
    pending.replace(HERE/'k1-records.zip')
    index = dict(files=rows, count=len(rows), persistedCount=sum(r['persisted'] for r in rows),
                 hashOnlyCount=sum(not r['persisted'] for r in rows),
                 redactedCount=sum(r['persisted'] and r['sha256'] != r['originalSha256'] for r in rows),
                 zipSha256=file_hash(HERE/'k1-records.zip'))
    (HERE/'k1-records-index.json').write_text(json.dumps(index, indent=2)+'\n')
    print(json.dumps(dict(files=len(rows), redactedFiles=index['redactedCount'],
                         persisted=index['persistedCount'], hashOnly=index['hashOnlyCount'],
                         zipBytes=(HERE/'k1-records.zip').stat().st_size)))


if __name__ == '__main__':
    main()
