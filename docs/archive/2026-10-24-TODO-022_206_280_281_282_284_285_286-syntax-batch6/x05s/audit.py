"""変更範囲・検査状態・ZIP・リンク・構文・記録のパスを最終点検する。"""
import ast
import gzip
import hashlib
import json
from pathlib import Path
import re
import runpy
import subprocess
import sys
import zipfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
BASE = '51dc0fefe2fc7a75df915a19640afb436d051e9e'
redact = runpy.run_path(str(HERE/'run.py'))['redact']


def sha(path):
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024*1024), b''):
            digest.update(block)
    return digest.hexdigest()


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, text=True).strip()


def main():
    assert git('rev-parse', 'HEAD') == BASE
    assert git('branch', '--show-current') == 'mod012/X05S'
    changed = git('diff', '--name-only', BASE).splitlines()
    implementation = ['formal/tests/interval_source_compare.py', 'scripts/check/interval_artifacts.py',
                      'scripts/check/test_policy.py']
    assert sorted(changed) == sorted(implementation), changed
    subprocess.run(['git', 'diff', '--check'], cwd=ROOT, check=True)
    assert not git('diff', BASE, '--', 'formal/Benitoite', 'formal/Benitoite.lean', 'crates/benitoite/src')
    assert json.loads((HERE/'work-body.json').read_text())['exit'] == 0
    log = (HERE/'work.log').read_text()
    assert 'Ran 29 tests' in log and 'selected checks passed' in log
    assert 'sysctl kern.clockrate: Operation not permitted' in log
    assert 'maximum resident set size' not in log
    index = json.loads((HERE/'local-records-index.json').read_text())
    archive = ROOT/index['archive']
    assert sha(archive) == index['sha256']
    restored = 0
    with zipfile.ZipFile(archive) as saved:
        assert len(saved.namelist()) == index['count']
        for row in index['files']:
            data = saved.read(row['path'])
            assert hashlib.sha256(data).hexdigest() == row['sha256']
            if 'link' in row:
                continue
            if row['path'].endswith('.gz'):
                data = gzip.decompress(data)
                restored += 1
            text = data.decode()
            assert redact(text) == text, row['path']
    old_archives = []
    for row in json.loads((HERE/'saved-audit-details.json').read_text())['archives']:
        assert sha(ROOT/row['archive']) == row['sha256']
        old_archives.append(dict(run=row['run'], sha256=row['sha256']))
    links = 0
    for path in HERE.iterdir():
        assert path.stat().st_size <= 1_000_000, path.name
        if path.suffix == '.py':
            ast.parse(path.read_text(), filename=path.name)
        if path.suffix in ['.md', '.json', '.log']:
            text = path.read_text()
            assert redact(text) == text, path.name
        if path.suffix == '.json':
            json.loads(path.read_text())
        if path.suffix == '.md':
            for target in re.findall(r'\]\(([^)]+)\)', path.read_text()):
                assert (path.parent/target).is_file(), target
                links += 1
    previous = json.loads((HERE.parent/'x05a/run2/executables.json').read_text())
    executables = {name: sha(ROOT/name) for name in previous}
    assert executables == previous, 'comparison executable changed'
    state = dict(base=BASE, head=git('rev-parse', 'HEAD'), branch=git('branch', '--show-current'),
        implementation={name: sha(ROOT/name) for name in implementation},
        diff=git('diff', '--numstat'), status=git('status', '--short'), executables=executables,
        python=sys.version, environment={})
    for tool, args in [('rustc', ['--version']), ('cargo', ['--version']), ('lean', ['--version']),
                       ('lake', ['--version']), ('elan', ['--version']), ('sw_vers', [])]:
        process = subprocess.run([tool, *args], cwd=ROOT, capture_output=True, text=True)
        state['environment'][tool] = dict(exit=process.returncode, output=process.stdout+process.stderr)
    (HERE/'source-state.json').write_text(redact(json.dumps(state, ensure_ascii=False, indent=2))+'\n')
    result = dict(implementationFiles=implementation, productionRustAndLeanUnchanged=True,
        workBodyExit=0, workWrapperExit=1, maximumResidentSetSize=None, zipFiles=index['count'],
        gzipInputsRestored=restored, links=links, localPathsRedacted=True,
        oldArchivesUnchanged=old_archives, comparisonExecutablesUnchanged=True)
    (HERE/'self-review.json').write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n')
    print(json.dumps(result, ensure_ascii=False))


if __name__ == '__main__':
    main()
