"""検査した入力の不変、記録の終了状態、相対リンクとパスの伏せ方を確認する。"""
from pathlib import Path
from datetime import datetime, timedelta, timezone
import ast
import hashlib
import json
import re
import subprocess

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
BASE = 'be57d4e92d7a48fb74dc33a4d3c3867b60207aeb'

def sha(data):
    return hashlib.sha256(data).hexdigest()

inputs = json.loads((OUT / 'work-inputs.json').read_text())
for name, expected in inputs.items():
    assert sha((ROOT / name).read_bytes()) == expected, name
result = subprocess.run(['python3', str(OUT / 'contract-check.py')], cwd=ROOT,
                        capture_output=True, text=True)
assert result.returncode == 0, result.stdout.replace(str(ROOT), '<repo>')
for label in ['fixed-domain-local', 'sound-local', 'fixed-domain-examples-types-fixed',
              'default-up-to-date', 'dry-run', 'axioms']:
    assert json.loads((OUT / (label + '.json')).read_text())['exit'] == 0, label
assert json.loads((OUT / 'work-check.json').read_text())['check_exit'] == 0
assert json.loads((OUT / 'work.json').read_text())['exit'] == 1
work = (OUT / 'work.log').read_text()
assert 'sysctl kern.clockrate: Operation not permitted' in work
assert '7 passed; 0 failed; 0 ignored' in work
assert 'selected checks passed' in work
assert 'All targets up-to-date (353 jobs).' in (OUT / 'default-up-to-date.log').read_text()
assert (OUT / 'axioms.log').read_text().count('depends on axioms:') == 25
assert 'sorryAx' not in (OUT / 'axioms.log').read_text()
contracts = json.loads((OUT / 'contract-check.json').read_text())
assert contracts['unchanged_existing_theorem_statements'] == 3443
assert len(contracts['changed_position_statements']) == 8
for path in OUT.glob('*.py'):
    ast.parse(path.read_text())
assert not subprocess.check_output(['git', 'diff', '--cached', '--name-only'], cwd=ROOT)
subprocess.run(['git', 'diff', '--check'], cwd=ROOT, check=True)
link_count = 0
for path in [OUT / 'results.md', ROOT / 'docs/design/01-spec/01-12-core-calculus.md',
             ROOT / 'docs/design/07-quality/07-04-formal-semantics.md']:
    prose = re.sub(r'```.*?```', '', path.read_text(), flags=re.S)
    prose = re.sub(r'`[^`]*`', '', prose)
    for target in re.findall(r'\]\(([^)]+)\)', prose):
        target = target.split('#', 1)[0]
        if not target or '://' in target: continue
        destination = path.parent / target
        if destination.resolve() == (OUT / 'final-review.json').resolve(): continue
        assert destination.exists(), (str(path.relative_to(ROOT)), target)
        link_count += 1
for path in OUT.iterdir():
    if path.is_file():
        text = path.read_text()
        assert str(ROOT) not in text and str(Path.home()) not in text, path.name
end = datetime.now(timezone(timedelta(hours=9)))
begin = datetime.fromisoformat('2026-10-26T07:25:18+09:00')
seconds = int((end - begin).total_seconds())
path = OUT / 'results.md'
text = path.read_text().replace('終了・所要時間: 最終確認時に記録する。',
    '終了: ' + end.strftime('%Y-%m-%d %H:%M:%S JST') +
    f'。所要時間は{seconds // 60}分{seconds % 60}秒である。')
path.write_text(text)
record = dict(base=BASE, head=BASE, exit=0, source_input_hashes_preserved=True,
    fixed_tables_unchanged=True, check_exit=0, time_exit=1,
    maximum_resident_set_size=None, measurement_limit='sandbox denied sysctl kern.clockrate',
    no_parallel_lean_builds=True, links_checked=link_count,
    records_redacted=True, python_syntax=True, git_diff_check=0, index_unchanged=True,
    end=end.strftime('%Y-%m-%d %H:%M:%S JST'), elapsed_seconds=seconds,
    input_sha256=inputs,
    artifacts_sha256={str(p.relative_to(ROOT)): sha(p.read_bytes()) for p in OUT.iterdir()
                      if p.is_file() and p.name != 'final-review.json'})
(OUT / 'final-review.json').write_text(json.dumps(record, ensure_ascii=False, indent=2) + '\n')
print(json.dumps({k: record[k] for k in ['exit', 'source_input_hashes_preserved',
    'check_exit', 'time_exit', 'maximum_resident_set_size', 'end', 'elapsed_seconds',
    'links_checked']}, ensure_ascii=False))
