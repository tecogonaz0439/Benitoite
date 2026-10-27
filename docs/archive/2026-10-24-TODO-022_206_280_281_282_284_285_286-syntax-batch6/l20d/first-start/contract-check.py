"""基準との差分と固定表を照合する。内容を書き換えない。"""
from pathlib import Path
import hashlib
import json
import re
import subprocess

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
BASE = '8a59b630f9fdef8d1e1595f7999c6242d167d739'

def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)

def digest(data):
    return hashlib.sha256(data).hexdigest()

unchanged = {}
for path in git('ls-files', 'formal', 'docs/design/01-spec/01-12-core-calculus.md',
                'docs/design/07-quality/07-04-formal-semantics.md',
                'crates/benitoite/testdata/interval-budget').decode().splitlines():
    data = (ROOT / path).read_bytes()
    assert data == git('show', BASE + ':' + path), path
    unchanged[path] = digest(data)
source = (OUT / 'key-obstruction.lean').read_text()
assert not re.search(r'\b(sorry|admit|axiom|native_decide|implemented_by|extern)\b', source)
log = (OUT / 'key-obstruction.log').read_text()
assert log.count('depends on axioms:') == 5
assert 'sorryAx' not in log
assert json.loads((OUT / 'key-obstruction.json').read_text())['wrapper_exit'] == 0
subprocess.run(['git', 'diff', '--check'], cwd=ROOT, check=True)
record = {'base': BASE, 'head': git('rev-parse', 'HEAD').decode().strip(),
          'tracked_diff': git('diff', BASE, '--stat').decode(),
          'unchanged_file_count': len(unchanged), 'unchanged_files_sha256': unchanged,
          'central_and_main_statements_unchanged': True,
          'fixed_tables_unchanged': True, 'new_axioms_or_holes': False,
          'reproduction_propositions': 5,
          'reproduction_sha256': digest(source.encode()), 'git_diff_check': 0}
(OUT / 'contract-check.json').write_text(json.dumps(record, ensure_ascii=False, indent=2) + '\n')
print(json.dumps({k: v for k, v in record.items() if k != 'unchanged_files_sha256'},
                 ensure_ascii=False, indent=2))
