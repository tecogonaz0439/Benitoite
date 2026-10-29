#!/usr/bin/env python3
"""SD の成果物を読むだけで点検し、SD 内へ結果を保存する。Lean は起動しない。"""
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[3]
START = datetime(2026, 10, 26, 16, 4, 55, tzinfo=timezone.utc)
BASE = 'ec1c26afbe4253d38fc24c2d63d0ca367fa08b2c'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


model = (HERE / 'Model.lean').read_text()
report = (HERE / 'findings.md').read_text()
run = json.loads((HERE / 'final-run.json').read_text())
inventory = json.loads((HERE / 'inventory.json').read_text())
log = (HERE / 'final.log').read_text()
assert run['passed'] and run['remote_exit'] == 0
assert run['source_sha256_before'] == run['source_sha256_after'] == digest(HERE / 'Model.lean')
assert inventory['spike']['sha256'] == digest(HERE / 'Model.lean')
assert not run['diagnostics'] and 'sorryAx' not in log
assert re.findall(r'^import (.+)$', model, re.M) == ['Std']
assert not re.search(r'\b(?:sorry|admit|axiom)\b', model)
assert not re.search(r'\b(?:error|warning):', log)
assert run['remote_summary'].strip() == log.splitlines()[-1].strip()

stack = []
theorems = set()
for line in model.splitlines():
    if m := re.match(r'^namespace (\w+)', line):
        stack.append(m[1])
    elif re.match(r'^end(?:\s|$)', line):
        stack.pop()
    elif m := re.match(r'^theorem ([\w.]+)', line):
        theorems.add('.'.join(stack + [m[1]]))
assert not stack
required = '''
SD.validate_sound SD.validate_failure_iff SD.rangeCover_sound SD.widen_checked
SD.eval_type SD.envTyped_push SD.checked_member SD.expr_low_eq SD.lowEq_push
SD.covers_mono SD.high_pc SD.noninterference SD.trace_noninterference
SD.receiver_noninterference SD.send_uses_checked_value SD.checked_send_has_no_range_failure
SD.Readers.covers_iff SD.Readers.range_cover_gives_flow SD.Readers.destination_noninterference
SD.Examples.accepts_dynamic_send SD.Examples.range_send_typed SD.Examples.wildcard_send_typed
SD.Examples.rejects_uncovered_range SD.Examples.rejects_secret_destination
SD.Examples.rejects_secret_pc_destination SD.Examples.payload_only_rule_accepts_secret_destination
SD.Examples.secret_destination_leaks SD.Examples.secret_pc_destination_leaks
SD.Examples.accepts_authorized_secret_destination SD.Examples.authorized_secret_destination_NI
SD.Examples.forged_checked_value_counterexample SD.Examples.accepts_public_validation
SD.Examples.public_validation_success SD.Examples.public_validation_failure
SD.Examples.rejects_secret_validation SD.Examples.rejects_secret_pc_validation
SD.Examples.rejects_secret_failure SD.Examples.secret_validation_leaks_status
SD.Examples.secret_validation_leaks_trace SD.Examples.secret_pc_validation_leaks
SD.Examples.secret_failure_leaks SD.Examples.accepts_public_failure
SD.Examples.rejects_secret_nonresumption SD.Examples.nonresumption_leaks_trace
SD.Examples.accepts_public_nonresumption SD.Examples.public_nonresumption_result
'''.split()
assert set(required) <= theorems, set(required) - theorems
links = re.findall(r'\[[^\]]+\]\(([^)]+)\)', report)
generated_outputs = {'artifact-check.json', 'provenance.json'}
missing_links = [target for target in links
                 if target not in generated_outputs and not (HERE / target.split('#')[0]).exists()]
assert not missing_links, missing_links
assert '/Users/' not in report and '/private/' not in report
assert not any(term in report or term in model for term in ['情報の流れの型', '情報流'])
assert inventory['spike']['lines'] == len(model.splitlines())
assert inventory['spike']['named_theorems'] == len(theorems) == 102
assert inventory['spike']['guards'] == len(re.findall(r'^#guard ', model, re.M)) == 13
assert inventory['spike']['axiom_reports'] == len(re.findall(r'^#print axioms ', model, re.M)) == 11

sources = [
    'work/m013/spike-common.md',
    'work/m013/spikes/SG/findings.md', 'work/m013/spikes/SG/Model.lean',
    'work/m013/spikes/SF/findings.md', 'work/m013/spikes/SF/Model.lean',
    'work/m013/spikes/SA/SA.lean', 'work/m013/spikes/SA/findings.md',
    'docs/todo/sources/2026-10-17-feasibility-spikes/142/Scope.lean',
    'work/m013/TODO-283_287-permission-and-effect-mechanisms/reviews/RV-S5.md',
    'work/m013/TODO-283_287-permission-and-effect-mechanisms/study/questions.md',
    'work/m013/TODO-283_287-permission-and-effect-mechanisms/study/information-flow-generality.md',
    'work/m013/remote-lean.sh', 'work/m013/remote/run-lean.sh',
]
now = datetime.now(timezone.utc)
provenance = {
    'base_commit': BASE,
    'started_utc': START.isoformat(),
    'source_hash_recorded_utc': now.isoformat(),
    'source_hash_note': '参照資料の記録時点のハッシュ。本番の固定版のハッシュは inventory.json に別記。',
    'sources': {name: digest(REPO / name) for name in sources},
    'model_sha256': digest(HERE / 'Model.lean'),
    'command': run['command'],
}
(HERE / 'provenance.json').write_text(json.dumps(provenance, ensure_ascii=False, indent=2) + '\n')

elapsed = (now - START).total_seconds()
record = {
    'started_utc': START.isoformat(),
    'finished_utc': now.isoformat(),
    'wall_seconds': round(elapsed, 3),
    'wall_duration': f'{int(elapsed // 60)}分{int(elapsed % 60):02d}秒',
    'time_limit_minutes': 120,
    'within_time_limit': elapsed <= 7200,
    'remote_summary': run['remote_summary'],
    'remote_maximum_resident_bytes': run['time_maximum_resident_bytes'],
    'model_sha256': digest(HERE / 'Model.lean'),
    'findings_sha256': digest(HERE / 'findings.md'),
    'named_theorems': len(theorems), 'required_theorems_checked': len(required),
    'guards': inventory['spike']['guards'], 'axiom_reports': inventory['spike']['axiom_reports'],
    'checked_links': len(links), 'missing_links': missing_links,
    'no_proof_holes_or_custom_axioms': True,
    'local_lean_executed': False, 'independent_review_executed': False,
    'passed': True,
}
(HERE / 'artifact-check.json').write_text(json.dumps(record, ensure_ascii=False, indent=2) + '\n')
assert all((HERE / target.split('#')[0]).exists() for target in links)
print(json.dumps(record, ensure_ascii=False, indent=2))
