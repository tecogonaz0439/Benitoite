"""T1 の本番 Rust 出力を Coverage の二つの Lean CLI へ渡す。"""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[3]
OUTPUT = Path(__file__).resolve().parent / 'exchange'
OUTPUT.mkdir(exist_ok=True)
SOURCE = ROOT / 'target/formal-t1-integer'
for path in SOURCE.iterdir():
    if path.suffix == '.bnt' or path.name in ('coverage.json', 'accepted-program.json', 'accepted-builtins.json', 'hole-program.json', 'hole-builtins.json'):
        shutil.copyfile(path, OUTPUT / path.name)

records = []

def compare(label, tool, inputs, expected_exit, count):
    report_path = OUTPUT / (label + '-report.json')
    command = [str(ROOT / 'formal/.lake/build/bin' / tool),
               *map(str, inputs), str(report_path)]
    start = time.monotonic()
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
    elapsed = time.monotonic() - start
    (OUTPUT / (label + '.log')).write_text(result.stdout + result.stderr)
    assert result.returncode == expected_exit, (label, result.returncode, result.stdout, result.stderr)
    report = json.loads(report_path.read_text())
    assert report['fuelExhausted'] == 0, report
    assert report.get('outOfScope', 0) == 0, report
    assert (report['matched'], report['mismatched']) == ((count, 0) if expected_exit == 0 else (0, count)), report
    if expected_exit == 1:
        assert report['mismatches'][0]['outcome']['detail'] == {
            'exhaustive': False, 'uncovered': '_', 'unreachable': [], 'coveredBy': []}, report
    records.append(dict(label=label, command=command, exit_code=result.returncode,
                        expected_exit=expected_exit, count=count, seconds=elapsed,
                        inputs=[dict(path=str(p.relative_to(ROOT)), sha256=hashlib.sha256(p.read_bytes()).hexdigest()) for p in inputs]))
    if report_path.stat().st_size > 1024 * 1024:
        full = report_path.read_bytes()
        entries = report['boundaryResults']
        report['boundaryResults'] = entries[:report['boundaryCases']]
        target = SOURCE / (label + '-full-report.json')
        report['storage'] = dict(fullReportSha256=hashlib.sha256(full).hexdigest(),
                                 omittedMatchedBoundaryResults=len(entries)-len(report['boundaryResults']),
                                 fullReport=str(target.relative_to(ROOT)))
        report_path.rename(target)
        (OUTPUT / (label + '-summary.json')).write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print(f'{label}: exit={result.returncode}, cases={count}, fuel=0, {elapsed:.3f}s', flush=True)

if '--random-only' not in sys.argv:
    compare('integer', 'coverageDiff', [OUTPUT / 'coverage.json'], 0, 3)
    compare('accepted', 'coverageProgramDiff', [OUTPUT / 'accepted-program.json', OUTPUT / 'accepted-builtins.json'], 0, 2)
    compare('hole', 'coverageProgramDiff', [OUTPUT / 'hole-program.json', OUTPUT / 'hole-builtins.json'], 1, 1)
for stem, count in [('named-all', 10020), ('future', 10028)]:
    corpus = ROOT / 'target/coverage-diff/default' / (stem + '-corpus.json')
    data = json.loads(corpus.read_text())
    assert len(data['cases']) == count and data['budget']['stopped'] == 0
    compare(stem, 'coverageDiff', [corpus], 0, count)
(OUTPUT / 'commands.json').write_text(json.dumps(records, ensure_ascii=False, indent=2) + '\n')
