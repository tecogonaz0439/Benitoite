"""指定入力・保護対象・比較記録を読み取りで点検する。"""
import ast
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import zipfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
BASE = '8b6feef2b36ae2a379c15ed5474b159d3622435f'
INPUTS = [
    'crates/benitoite/tests/desugar_export/interval/README.md',
    'crates/benitoite/tests/desugar_export/interval/vm.rs',
    'crates/benitoite/tests/desugar_export/interval/vm-range.bnt',
    'docs/design/07-quality/07-04-formal-semantics.md',
    'formal/tests/interval_range_vm.py',
    'formal/tests/interval_vm_compare.py',
    'formal/tests/test_interval_exchange.py',
]
PROTECTED = ['crates/benitoite/src', 'crates/benitoite/testdata/interval-budget',
             'crates/benitoite/tests/call_allocations.rs', 'Cargo.lock', 'Cargo.toml',
             'fuzz/Cargo.lock', 'rust-toolchain.toml', 'formal/lakefile.toml', 'formal/lean-toolchain']


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, text=True).strip()


def digest(path):
    return hashlib.sha256((ROOT/path).read_bytes()).hexdigest()


def snapshot():
    protected = git('ls-files', '--', *PROTECTED).splitlines()
    protected += [p for p in git('ls-files', '--', 'formal').splitlines() if p.endswith('.lean')]
    return dict(base=BASE, head=git('rev-parse', 'HEAD'),
                inputs={p: digest(p) for p in INPUTS},
                protected={p: digest(p) for p in sorted(set(protected))})


def main():
    current = snapshot()
    assert current['head'] == BASE
    assert git('diff', BASE, '--', *PROTECTED, 'formal/*.lean', 'formal/Benitoite') == ''
    if '--save' in sys.argv:
        (HERE/'work-inputs.json').write_text(json.dumps(current, indent=2)+'\n')
        print(json.dumps(dict(inputs=len(current['inputs']), protected=len(current['protected']))))
        return
    assert current == json.loads((HERE/'work-inputs.json').read_text())
    for path in [ROOT/p for p in INPUTS if p.endswith('.py')]+list(HERE.glob('*.py')):
        ast.parse(path.read_text())
    git('diff', '--check')
    output = ROOT/'target/interval-diff/x03b/comparison-verified'
    summary = json.loads((output/'vm/range/range-vm-summary.json').read_text())
    assert summary['compared'] == 37 and summary['evaluationExcluded'] == 0
    assert summary['selectedOperations'] == 80 and len(summary['selectedOut']) == 9
    assert sum(len(r['reached']) for r in summary['runs']) == 68
    assert len(summary['negativeCases']) == 6
    for path in HERE.rglob('*'):
        if path.is_file() and path.suffix in ['.md', '.py', '.log', '.json']:
            raw = path.read_bytes()
            for private in [str(ROOT), str(Path.home()), os.environ.get('TMPDIR', '\0')]:
                assert private.encode() not in raw, (path.name, 'unredacted path')
    result = dict(inputs=len(current['inputs']), protected=len(current['protected']),
                  unchanged=True, pythonSyntax=True, diffCheck=True, recordsRedacted=True,
                  rangeCompared=37, reached=68, evaluationExcluded=0)
    if '--final' in sys.argv:
        work = json.loads((HERE/'work-check.json').read_text())
        assert work['exit'] == 0
        log = (HERE/'work-check.log').read_text()
        rows = []
        for part in log.split('     Running ')[1:]:
            match = re.search(r'test result: ok\. (\d+) passed; (\d+) failed; (\d+) ignored;', part)
            if match:
                rows.append(dict(target=part.splitlines()[0], counts=list(map(int, match.groups()))))
        assert rows[0]['counts'] == [1332, 0, 21]
        assert len(rows[1:]) == 40
        assert [sum(row['counts'][i] for row in rows[1:]) for i in range(3)] == [394, 0, 10]
        index = json.loads((HERE/'local-records-index.json').read_text())
        archive = HERE/index['archive']
        assert hashlib.sha256(archive.read_bytes()).hexdigest() == index['sha256']
        with zipfile.ZipFile(archive) as saved:
            assert set(saved.namelist()) == {e['name'] for e in index['entries']}
            for entry in index['entries']:
                raw = saved.read(entry['name'])
                assert hashlib.sha256(raw).hexdigest() == entry['sha256']
                assert str(ROOT).encode() not in raw and str(Path.home()).encode() not in raw
        for target in re.findall(r'\]\(([^)]+)\)', (HERE/'results.md').read_text()):
            assert not target.startswith('/') and (HERE/target).is_file(), target
        result.update(work=work, lib=rows[0], integration=rows[1:], archiveEntries=len(index['entries']),
                      archiveLinks=len(index['links']), linksValid=True)
    (HERE/'self-review.json').write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps(result))


if __name__ == '__main__':
    main()
