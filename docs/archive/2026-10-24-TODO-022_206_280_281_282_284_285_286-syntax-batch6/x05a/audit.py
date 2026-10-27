"""保存した失敗の証拠、入力の同一性、パスの伏せ方を点検する。"""
import ast
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import zipfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]


def sha(path):
    result = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024*1024), b''):
            result.update(chunk)
    return result.hexdigest()


def main():
    state = json.loads((HERE/'source-state-before.json').read_text())
    changed = [r['path'] for r in state['trackedInputs'] if sha(ROOT/r['path']) != r['sha256']]
    assert not changed, changed
    head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT).decode().strip()
    assert head == state['base']
    diff = subprocess.check_output(['git', 'diff', '--name-only', state['base']], cwd=ROOT).decode().splitlines()
    assert not diff, diff
    untracked = subprocess.check_output(['git', 'ls-files', '--others', '--exclude-standard'], cwd=ROOT).decode().splitlines()
    assert all(p.startswith(HERE.relative_to(ROOT).as_posix()+'/') for p in untracked)
    after = dict(base=state['base'], head=head, trackedInputCount=len(state['trackedInputs']),
                 changed=changed, trackedDiff=diff, untracked=untracked)
    (HERE/'source-state-after.json').write_text(json.dumps(after, ensure_ascii=False, indent=2)+'\n')
    index = json.loads((HERE/'k1-records-index.json').read_text())
    assert sha(HERE/'k1-records.zip') == index['zipSha256']
    by_path = {r['path']: r for r in index['files']}
    with zipfile.ZipFile(HERE/'k1-records.zip') as archive:
        assert set(archive.namelist()) == {r['path'] for r in index['files'] if r['persisted']}
        inputs = json.loads(archive.read('interval/input-manifest.json'))['artifacts']
        assert all(by_path[r['root']+'/'+r['path']]['originalSha256'] == r['sha256'] for r in inputs)
        needles = [str(ROOT).encode(), str(Path.home()).encode(), tempfile.gettempdir().encode(),
                   os.path.realpath(tempfile.gettempdir()).encode()]
        def check_stream(stream, name):
            tail = b''
            for chunk in iter(lambda: stream.read(1024*1024), b''):
                content = tail+chunk
                assert not any(s in content for s in needles), name
                tail = content[-max(map(len, needles)):]
        for name in archive.namelist():
            with archive.open(name) as stream:
                check_stream(stream, name)
    for path in HERE.iterdir():
        if path.suffix == '.zip':
            continue
        with path.open('rb') as stream:
            check_stream(stream, path.name)
        if path.suffix == '.py':
            ast.parse(path.read_text())
    for target in re.findall(r'\]\(([^)]+)\)', (HERE/'results.md').read_text()):
        if not target.startswith(('https:', 'http:', '#')):
            assert (HERE/target.split('#')[0]).exists(), target
    subprocess.run(['git', 'diff', '--check'], cwd=ROOT, check=True)
    result = dict(sourceFilesUnchanged=len(state['trackedInputs']), head=head,
                  inputHashesMatched=len(inputs), artifactIndexCount=index['count'],
                  storedFiles=index['persistedCount'], hashOnly=index['hashOnlyCount'],
                  zipSha256=index['zipSha256'], pathsRedacted=True, recordPythonSyntax=True,
                  markdownLinks=True, gitDiffCheck=True, onlyX05aRecordsChanged=True)
    (HERE/'self-review.json').write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n')
    print(json.dumps(result, ensure_ascii=False))


if __name__ == '__main__':
    main()
