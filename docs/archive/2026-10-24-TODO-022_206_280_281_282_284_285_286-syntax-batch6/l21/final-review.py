"""検査後の入力・リンク・保存記録を読み取りで点検する。"""
from pathlib import Path
import hashlib
import json
import re
import subprocess

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
contract = json.loads((OUT / 'contract-check.json').read_text())
hashes = dict(contract['unchanged_files_sha256'])
hashes.update({path: value['after'] for path, value in contract['changed_files_sha256'].items()})
for path, expected in hashes.items():
    assert hashlib.sha256((ROOT / path).read_bytes()).hexdigest() == expected, path

checked_links = []
for path in [OUT / 'results.md', OUT / 'x03-range-cases.md']:
    for target in re.findall(r'\]\(([^)]+)\)', path.read_text()):
        if '://' in target:
            continue
        if (path.parent / target) == OUT / 'final-review.json':
            continue  # この点検の成功時に初めて生成する出力。
        assert (path.parent / target.split('#', 1)[0]).exists(), (path.name, target)
        checked_links.append([path.name, target])

for path in OUT.rglob('*'):
    if path.is_file() and path.suffix in ['.md', '.py', '.sh', '.lean', '.log', '.json']:
        text = path.read_text()
        assert str(ROOT) not in text and str(Path.home()) not in text, path.name

work = json.loads((OUT / 'work.json').read_text())
assert work['check_exit'] == 0 and work['wrapper_exit'] == 0
axioms = (OUT / 'axioms.log').read_text()
axiom_lines = [line for line in axioms.splitlines() if 'depends on axioms:' in line]
assert len(axiom_lines) == 80, len(axiom_lines)
dependencies = re.findall(r'depends on axioms: \[([^]]*)\]', axioms, re.S)
assert len(dependencies) == len(axiom_lines)
for dependency in dependencies:
    assert {name.strip() for name in dependency.split(',')} <= {
        'propext', 'Classical.choice', 'Quot.sound'}
subprocess.run(['git', 'diff', '--check'], cwd=ROOT, check=True)
record = {
    'base': contract['base'],
    'head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT).decode().strip(),
    'unchanged_since_contract_check_files': len(hashes),
    'input_sha256': hashes,
    'design_sha256': {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
        for path in [ROOT / 'docs/design/01-spec/01-12-core-calculus.md',
                     ROOT / 'docs/design/07-quality/07-04-formal-semantics.md']},
    'relative_links_checked': checked_links,
    'no_local_absolute_paths_in_saved_records': True,
    'axiom_dependency_queries': len(axiom_lines),
    'axioms_within_existing_three': True,
    'specified_work_exit': work['check_exit'], 'git_diff_check': 0,
    'changed_files': subprocess.check_output(['git', 'diff', '--name-only'], cwd=ROOT).decode().splitlines(),
}
(OUT / 'final-review.json').write_text(json.dumps(record, ensure_ascii=False, indent=2) + '\n')
print(json.dumps({'checked_inputs': len(hashes), 'checked_links': len(checked_links),
                  'axiom_queries': len(axiom_lines), 'work_exit': work['check_exit']}, ensure_ascii=False))
