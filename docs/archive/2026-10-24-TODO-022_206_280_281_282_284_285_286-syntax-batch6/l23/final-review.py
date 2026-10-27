"""指定検査の終了・公理・保護対象と、検査後の実装入力をまとめて確認する。"""
from pathlib import Path
import hashlib
import json
import re
import subprocess

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
subprocess.run(['python3', '-B', str(OUT / 'contract-check.py')], cwd=ROOT, check=True)
work = json.loads((OUT / 'work-check.json').read_text())
assert work['check_exit'] == 0
log = (OUT / 'work.log').read_text()
assert 'selected checks passed' in log
assert '7 passed; 0 failed; 0 ignored' in log
assert 'Operation not permitted' in log
assert 'maximum resident set size' not in log
axioms = (OUT / 'axioms.log').read_text()
dependencies = set()
for found in re.findall(r'depends on axioms: \[([^]]*)\]', axioms):
    dependencies.update(x.strip() for x in found.split(',') if x.strip())
assert dependencies <= {'propext', 'Classical.choice', 'Quot.sound'}, dependencies
assert 'sorryAx' not in axioms
inputs = ['docs/design/01-spec/01-12-core-calculus.md',
          'docs/design/07-quality/07-04-formal-semantics.md',
          'formal/Benitoite.lean', 'formal/Benitoite/Interval/Eval.lean',
          'formal/Benitoite/Interval/Environment.lean',
          'formal/Benitoite/Interval/FixedDomain.lean',
          'formal/Benitoite/Interval/HttpRecordExamples.lean']
hashes = {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in inputs}
finished = (OUT / 'work-check.json').stat().st_mtime
started = finished - work['seconds']
written = {}
for name in ['target/debug/.fingerprint', 'formal/.lake/build/lib/lean']:
    files = [p for p in (ROOT / name).rglob('*')
             if p.is_file() and started <= p.stat().st_mtime <= finished]
    written[name] = dict(files_written_during_work=len(files))
    if files:
        written[name]['first'] = str(min(files, key=lambda p: p.stat().st_mtime).relative_to(ROOT))
        written[name]['last'] = str(max(files, key=lambda p: p.stat().st_mtime).relative_to(ROOT))
for path in OUT.iterdir():
    if path.suffix in {'.py', '.md', '.log', '.json', '.jsonl', '.lean'}:
        text = path.read_text()
        assert str(ROOT) not in text and str(Path.home()) not in text, path.name
record = dict(work_check_exit=0, timing_wrapper_exit=json.loads((OUT / 'work.json').read_text())['exit'],
    maximum_resident_set_size='unavailable: sysctl kern.clockrate denied by sandbox',
    axiom_queries=(OUT / 'axioms.lean').read_text().count('#print axioms'),
    axiom_dependencies=sorted(dependencies), inputs_sha256=hashes,
    generated_files_during_work=written,
    guard_count=(ROOT / inputs[-1]).read_text().count('#guard'),
    no_absolute_workspace_paths_in_records=True)
(OUT / 'final-review.json').write_text(json.dumps(record, ensure_ascii=False, indent=2) + '\n')
print(json.dumps(record, ensure_ascii=False))
