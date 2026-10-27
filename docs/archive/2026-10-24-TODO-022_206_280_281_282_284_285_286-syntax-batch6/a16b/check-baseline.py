#!/usr/bin/env python3
"""本番コードだけを基準へ一時復元し、退行テストの失敗と復元を記録する。"""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

out = Path(__file__).resolve().parent
repo = out.parents[2]
base = 'a7a82d12f3ab1e15d88345cb8ba2c7f2392ab4d3'
paths = [
    'crates/benitoite/src/typeck/consts.rs',
    'crates/benitoite/src/typeck/interval/input.rs',
    'crates/benitoite/src/typeck/interval/flow.rs',
    'crates/benitoite/src/typeck/interval/flow/range.rs',
    'crates/benitoite/src/typeck/interval/environment.rs',
    'crates/benitoite/src/typeck/interval/discovery.rs',
]
saved = {path: (repo / path).read_bytes() for path in paths}
try:
    for path in paths:
        (repo / path).write_bytes(subprocess.check_output(['git', 'show', f'{base}:{path}'], cwd=repo))
    result = subprocess.run([sys.executable, str(out / 'run.py'), 'regression-baseline', 'cargo', 'test', '-p', 'benitoite', '--lib', 'typeck::interval::tests::range_calls', '--', '--nocapture'], cwd=repo)
finally:
    for path, content in saved.items():
        (repo / path).write_bytes(content)
    record = {path: {'sha256': hashlib.sha256(content).hexdigest(), 'restored': (repo / path).read_bytes() == content} for path, content in saved.items()}
    (out / 'baseline-restore.json').write_text(json.dumps(record, ensure_ascii=False, indent=2) + '\n')
assert result.returncode == 101, result.returncode
assert all(item['restored'] for item in record.values())
