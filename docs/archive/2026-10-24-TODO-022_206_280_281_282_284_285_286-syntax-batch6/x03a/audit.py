"""作業末の入力・保護対象・件数・記録のパスを読み取りで点検する。"""
import ast
import hashlib
import json
from pathlib import Path
import re
import subprocess
import zipfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
BASE = '65b165272b42c3f3621ad59bc2a2c6c9cec9c46e'


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, text=True)


def main():
    assert git('rev-parse', 'HEAD').strip() == BASE
    assert git('branch', '--show-current').strip() == 'mod012/X03a'
    inputs = json.loads((HERE/'work-final-inputs.json').read_text())['inputs']
    assert all(hashlib.sha256((ROOT/name).read_bytes()).hexdigest() == sha for name, sha in inputs.items())
    for name in inputs:
        if name.endswith('.py'):
            ast.parse((ROOT/name).read_text())
    for path in HERE.glob('*.py'):
        ast.parse(path.read_text())
    protected = [p for p in git('ls-files', 'formal').splitlines()
                 if p.endswith('.lean') or p.endswith(('lakefile.toml', 'lean-toolchain'))]
    protected += git('ls-files', 'crates/benitoite/src', 'crates/benitoite/tests/call_allocations.rs',
                     'crates/benitoite/tests/desugar_export/interval/*.json', 'Cargo.lock',
                     'Cargo.toml', 'fuzz/Cargo.lock', 'fuzz/Cargo.toml', 'deny.toml', 'rust-toolchain.toml').splitlines()
    subprocess.run(['git', 'diff', '--exit-code', BASE, '--', *protected], cwd=ROOT, check=True,
                   stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    assert not [p for p in git('ls-files', '--others', '--exclude-standard', 'formal').splitlines() if p.endswith('.lean')]
    allowed = set(inputs)
    assert set(git('diff', '--name-only', BASE).splitlines()) <= allowed
    subprocess.run(['git', 'diff', '--check'], cwd=ROOT, check=True)
    assert json.loads((HERE/'work-check.json').read_text())['exit'] == 1
    work = json.loads((HERE/'work-final-check.json').read_text())
    assert work['exit'] == 0
    log = (HERE/'work-final-check.log').read_text()
    assert set(re.findall(r'^== (\w+)$', log, re.M)) == {
        'fmt', 'lint_default', 'lib_default', 'tests_related', 'source_rules',
        'skill_generated', 'spec_tally', 'formal_build'}
    rows = []
    for part in log.split('     Running ')[1:]:
        result = re.search(r'test result: ok\. (\d+) passed; (\d+) failed; (\d+) ignored;', part)
        if result:
            rows.append(dict(target=part.splitlines()[0], counts=list(map(int, result.groups()))))
    assert rows[0]['counts'] == [1332, 0, 21]
    assert len(rows[1:]) == 40
    assert [sum(row['counts'][i] for row in rows[1:]) for i in range(3)] == [394, 0, 10]
    vm = json.loads((HERE/'vm-summary.json').read_text())
    assert (vm['compared'], vm['excluded'], vm['operations']) == (39, 0, 80)
    assert len(vm['negativeCases']) == 5 and vm['markerFailureExcluded'] == 'R0201'
    assert sum(bool(r['errors']) for r in vm['runs']) == 13
    assert sum(len(r['reached']) for r in vm['runs']) == 70
    index = json.loads((HERE/'local-records-index.json').read_text())
    archive = HERE/index['archive']
    assert hashlib.sha256(archive.read_bytes()).hexdigest() == index['sha256']
    with zipfile.ZipFile(archive) as saved:
        assert set(saved.namelist()) == {r['name'] for r in index['entries']}
        for entry in index['entries']:
            raw = saved.read(entry['name'])
            assert hashlib.sha256(raw).hexdigest() == entry['sha256']
            assert str(ROOT).encode() not in raw and str(Path.home()).encode() not in raw
    for path in HERE.iterdir():
        if path.suffix in {'.py', '.md', '.json', '.log'}:
            raw = path.read_bytes()
            assert str(ROOT).encode() not in raw and str(Path.home()).encode() not in raw, path.name
    result = dict(inputs=inputs, protectedFiles=len(protected), lib=rows[0], integration=rows[1:],
                  work=work, archiveEntries=len(index['entries']), archiveLinks=len(index['links']),
                  pythonSyntax=True, pathsRedacted=True, diffCheck=True)
    (HERE/'self-review.json').write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps(dict(protectedFiles=len(protected), inputs=len(inputs), integrationTargets=40,
                         libPassed=1332, integrationPassed=394, records=len(index['entries']))))


if __name__ == '__main__':
    main()
