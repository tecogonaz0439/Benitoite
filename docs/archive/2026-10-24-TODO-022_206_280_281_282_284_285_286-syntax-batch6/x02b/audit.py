"""作業末の関係状態・保護対象・検査の件数と保存記録を照合する。"""
import ast
import hashlib
import json
from pathlib import Path
import re
import subprocess

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
BASE = '873d5200d771be06c822a0c91acd9e25322c0df2'


def command(*args):
    return subprocess.check_output(args, cwd=ROOT, text=True)


def main():
    before = json.loads((HERE/'work-inputs.json').read_text())
    for name, digest in before.items():
        assert hashlib.sha256((ROOT/name).read_bytes()).hexdigest() == digest, name
    tracked = command('git', 'ls-files').splitlines()
    protected = [p for p in tracked if p.startswith('formal/') and (p.endswith('.lean') or p.endswith('lakefile.toml'))
                 or p.startswith('crates/benitoite/testdata/interval-budget/')
                 or p in ['crates/benitoite/src/typeck/interval/budget.rs', 'crates/benitoite/tests/call_allocations.rs',
                          'Cargo.lock', 'fuzz/Cargo.lock', 'rust-toolchain.toml']
                 or p.endswith(('exchange-manifest.json', 'routing-manifest.json'))]
    for name in protected:
        assert (ROOT/name).read_bytes() == subprocess.check_output(['git', 'show', BASE+':'+name], cwd=ROOT), name
    for name in ['formal/tests/test_interval_exchange.py', 'formal/tests/interval_source_compare.py']:
        ast.parse((ROOT/name).read_text(), filename=name)
    for path in HERE.glob('*.py'):
        ast.parse(path.read_text(), filename=path.name)
    for path in HERE.iterdir():
        if path.suffix in ['.py', '.md', '.json', '.log']:
            data = path.read_bytes()
            assert str(ROOT).encode() not in data and str(Path.home()).encode() not in data, path.name
    subprocess.run(['git', 'diff', '--check'], cwd=ROOT, check=True)
    changes = command('git', 'diff', '--numstat', BASE).splitlines()
    new = ROOT/'formal/tests/interval_source_compare.py'
    log = (HERE/'work-check.log').read_text()
    tests = [tuple(map(int, row)) for row in re.findall(
        r'test result: ok\. (\d+) passed; (\d+) failed; (\d+) ignored;', log)]
    assert tests and all(failed == 0 for _, failed, _ in tests)
    assert len(re.findall(r'^     Running tests/', log, re.M)) == 40
    check = json.loads((HERE/'work-check.json').read_text())
    assert check['exit'] == 0 and 'selected checks passed' in log
    assert len(set(re.findall(r'^== (fmt|lint_default|lib_default|tests_related|source_rules|skill_generated|spec_tally|formal_build)$', log, re.M))) == 8
    olean = [p.relative_to(ROOT/'formal').as_posix() for p in (ROOT/'formal/.lake/build').rglob('*.olean')
             if p.stat().st_mtime > (HERE/'work-check.log').stat().st_birthtime]
    result = dict(base=BASE, protectedFiles=len(protected), protectedUnchanged=True,
                  workInputsUnchanged=True, pythonSyntax='passed', pathsRedacted=True,
                  lib=tests[0], integrationTargets=40,
                  integrationTotals=[sum(row[i] for row in tests[1:]) for i in range(3)],
                  work=check, changedDuringWorkOlean=olean, trackedNumstat=changes,
                  newPythonLines=len(new.read_text().splitlines()),
                  versions=dict(rust=command('rustc', '--version').strip(),
                                cargo=command('cargo', '--version').strip(),
                                python=command('python3', '--version').strip()))
    (HERE/'self-review.json').write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n')
    print(json.dumps(result, ensure_ascii=False))


if __name__ == '__main__':
    main()
