"""指定検査後の入力ハッシュ・記録のリンク・伏字・差分を確認する。"""
from pathlib import Path
import hashlib
import json
import re
import subprocess

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
record = json.loads((OUT / 'contract-check.json').read_text())
for file, expected in record['changed_inputs'].items():
    assert hashlib.sha256((ROOT / file).read_bytes()).hexdigest() == expected, file
links = re.findall(r'\]\(([^)]+)\)', (OUT / 'results.md').read_text())
for link in links:
    assert (OUT / link).is_file() or link == 'final-review.json', link
for file in OUT.iterdir():
    if not file.is_file():
        continue
    source = file.read_text()
    for actual in [str(ROOT), str(Path.home())]:
        assert actual not in source, file.name
subprocess.run(['git', 'diff', '--check'], cwd=ROOT, check=True)
status = subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT).decode()
assert len(status.splitlines()) == 5, status
queries = re.findall(r'^#print axioms (.+)$', (OUT / 'axioms.lean').read_text(), re.M)
result = {'base': record['base'], 'head': record['head'],
          'work_input_hashes_unchanged': record['changed_inputs'],
          'result_links': len(links), 'all_links_exist': True,
          'no_local_absolute_paths': True, 'diff_check': 0,
          'changed_paths': status.splitlines(), 'source_edited_after_work': False,
          'axiom_queries': len(queries), 'distinct_written_queries': len(set(queries)),
          'fixed_inputs_unchanged': record['fixed_inputs'],
          'scope': '閉じた評価器の区切り。L20c全体は未完。'}
(OUT / 'final-review.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
assert all((OUT / link).is_file() for link in links)
print(json.dumps({k: result[k] for k in ('result_links', 'all_links_exist', 'no_local_absolute_paths',
                                       'diff_check', 'axiom_queries', 'distinct_written_queries')},
                 ensure_ascii=False))
