"""作業末の入力、保護対象、記録と差分を点検する。git の書き込みは行わない。"""
import ast
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
BASE = '2878da41c88ad296c7d6d4e2a6eec63c64412bcb'


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)


def main():
    assert git('rev-parse', 'HEAD').decode().strip() == BASE
    assert git('branch', '--show-current').decode().strip() == 'mod012/X02a'
    inputs = json.loads((HERE/'work-inputs.json').read_text())
    assert all(hashlib.sha256((ROOT/path).read_bytes()).hexdigest() == digest for path, digest in inputs.items())
    assert not git('diff', '--name-only', BASE, '--', 'formal').strip()
    assert not git('ls-files', '--others', '--exclude-standard', 'formal').strip()
    protected = ['Cargo.toml', 'Cargo.lock', 'fuzz/Cargo.toml', 'fuzz/Cargo.lock', 'deny.toml',
                 'rust-toolchain.toml', 'scripts/check-formal.sh', 'formal/lakefile.toml',
                 'crates/benitoite/tests/call_allocations.rs',
                 'crates/benitoite/src/typeck/interval/budget.rs',
                 'crates/benitoite/tests/desugar_export/exchange-manifest.json',
                 'crates/benitoite/tests/desugar_export/routing-manifest.json']
    protected += git('ls-files', 'crates/benitoite/testdata/interval-budget').decode().splitlines()
    hashes = {}
    for name in protected:
        assert (ROOT/name).exists(), name
        value = (ROOT/name).read_bytes()
        assert value == git('show', BASE+':'+name), name
        hashes[name] = hashlib.sha256(value).hexdigest()
    for path in [*HERE.glob('*.py'), ROOT/'crates/benitoite/tests/desugar_export/interval/check-manifest.py']:
        ast.parse(path.read_text())
    for path in HERE.iterdir():
        if path.suffix in ['.log', '.json', '.py', '.md']:
            text = path.read_text()
            assert str(ROOT) not in text and str(Path.home()) not in text, path.name
    assert not git('diff', '--check').strip()
    totals = dict(production=[0, 0], rustTests=[0, 0], pythonComparison=[0, 0])
    for row in git('diff', '--numstat').decode().splitlines():
        added, removed, name = row.split('\t')
        key = 'production' if name.startswith('crates/benitoite/src/') else 'rustTests' if name.startswith('crates/benitoite/tests/') and name.endswith('.rs') else None
        if key is not None:
            totals[key][0] += int(added)
            totals[key][1] += int(removed)
    totals['rustTests'][0] += len((ROOT/'crates/benitoite/tests/desugar_export/interval/manifest.rs').read_text().splitlines())
    totals['pythonComparison'][0] = len((ROOT/'crates/benitoite/tests/desugar_export/interval/check-manifest.py').read_text().splitlines())
    legacy = json.loads((ROOT/'crates/benitoite/tests/desugar_export/exchange-manifest.json').read_text())
    routing = json.loads((ROOT/'crates/benitoite/tests/desugar_export/routing-manifest.json').read_text())
    assert len(legacy['programs']) == len(routing) == 1790
    result = dict(base=BASE, head=BASE, inputHashesUnchanged=True, formalUnchanged=True,
                  protectedHashes=hashes, legacyProgramInputs=len(routing),
                  legacyManifestUnchanged=True, codeLines=totals)
    (HERE/'self-review.json').write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps(result))


if __name__ == '__main__':
    main()
