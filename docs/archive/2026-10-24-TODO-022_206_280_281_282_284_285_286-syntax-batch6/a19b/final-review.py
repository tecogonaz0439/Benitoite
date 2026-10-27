"""最終の入力・保護範囲・ログ・結果のリンクを照合する。"""
import ast
import hashlib
import json
from pathlib import Path
import re
import subprocess
import zipfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent.parent
inputs = json.loads((HERE / 'work-inputs-sha256.json').read_text())
for path, digest in inputs.items():
    assert hashlib.sha256((ROOT / path).read_bytes()).hexdigest() == digest, path
changed = subprocess.check_output(['git', 'diff', '--name-only'], text=True).splitlines()
protected = ['formal/', 'crates/benitoite/skill/', 'fuzz/', 'Cargo.toml', 'Cargo.lock', 'deny.toml', 'crates/benitoite/tests/call_allocations.rs']
assert not [p for p in changed if any(p.startswith(prefix) for prefix in protected)]
subprocess.run(['git', 'diff', '--check'], check=True)
subprocess.run(['git', 'diff', '--exit-code', '--', 'crates/benitoite/testdata/interval-budget/whole.tsv', 'crates/benitoite/testdata/interval-budget/summary.tsv', 'crates/benitoite/testdata/interval-budget/regenerate-reference.py'], check=True)
checked = []
for path in HERE.rglob('*'):
    if not path.is_file():
        continue
    if path.suffix == '.zip':
        with zipfile.ZipFile(path) as archive:
            index = json.loads(path.with_name('raw-logs-index.json').read_text())
            for name in archive.namelist():
                payload = archive.read(name)
                assert hashlib.sha256(payload).hexdigest() == index[name]['sha256']
                assert str(ROOT).encode() not in payload
                assert str(Path.home()).encode() not in payload
    elif path.suffix in ['.py', '.md', '.json', '.log']:
        source = path.read_text()
        assert str(ROOT) not in source, path.name
        assert str(Path.home()) not in source, path.name
        if path.suffix == '.py':
            ast.parse(source)
        if path.suffix == '.md':
            for link in re.findall(r'\]\(([^)#]+)(?:#[^)]*)?\)', source):
                if '://' not in link:
                    assert (path.parent / link).exists(), link
    checked.append(str(path.relative_to(HERE)))
work = json.loads((HERE / 'work-check.json').read_text())
assert work['exit'] == 0, work
report = {'base': subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(), 'input_count': len(inputs), 'unchanged_work_inputs': True, 'protected_unchanged': True, 'whole_summary_generator_unchanged': True, 'diff_check': True, 'checked_records': checked}
(HERE / 'final-review.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
print(json.dumps({k: v for k, v in report.items() if k != 'checked_records'}))
