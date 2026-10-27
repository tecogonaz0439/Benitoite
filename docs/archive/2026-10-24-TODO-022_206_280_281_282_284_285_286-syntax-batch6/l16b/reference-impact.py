"""固定表を変更せず、新しい Lean の実行値を L16a の保存ログと比較する。"""
from pathlib import Path
import collections
import hashlib
import json
import subprocess
import time

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
DIRECTORY = ROOT / 'crates/benitoite/testdata/interval-budget'
BASELINE = OUT.parent / 'l16/resume-reference'
fixed = {name: (DIRECTORY / (name + '.tsv')).read_bytes() for name in ('body', 'whole', 'summary')}
summary = {}
for name, widths in [('budget-reference.lean', (11, 14)), ('summary-reference.lean', (9,))]:
    command = ['lake', 'env', 'lean', '-M', '12288', str(DIRECTORY / name)]
    started = time.monotonic()
    result = subprocess.run(command, cwd=ROOT / 'formal', capture_output=True, text=True)
    elapsed = time.monotonic() - started
    output = result.stdout + result.stderr
    raw_dir = OUT / 'reference-raw'
    raw_dir.mkdir(exist_ok=True)
    (raw_dir / (name + '.log')).write_text(output.replace(str(ROOT), '<repo>').replace(str(Path.home()), '<home>'))
    assert result.returncode == 0, (name, result.returncode)
    def rows(text):
        return {tuple(row[:3]): row for line in text.splitlines()
                if len(row := line.split('\t')) in widths and row[1].isdigit()}
    before = rows((BASELINE / (name + '.log')).read_text())
    after = rows(output)
    assert before and after, name
    changes = collections.Counter()
    for key in before.keys() | after.keys():
        if before.get(key) != after.get(key):
            changes[key[0]] += 1
    summary[name] = {'exit': result.returncode, 'seconds': elapsed,
                     'baseline_rows': len(before), 'current_rows': len(after),
                     'changed_rows_by_shape': dict(changes)}
    print(name, summary[name], flush=True)
for name, data in fixed.items():
    assert data == (DIRECTORY / (name + '.tsv')).read_bytes(), name
summary['saved_sha256'] = {name: hashlib.sha256(data).hexdigest() for name, data in fixed.items()}
(OUT / 'reference-impact.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2) + '\n')
