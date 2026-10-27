#!/usr/bin/env python3
"""関係入力、固定表、差分、記録中のパスとリンクを読み取りで点検する。"""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

out = Path(__file__).resolve().parent
repo = out.parents[2]
base = 'a7a82d12f3ab1e15d88345cb8ba2c7f2392ab4d3'

def git(*args):
    return subprocess.check_output(['git', *args], cwd=repo, text=True)

saved = json.loads((out / 'final-inputs-sha256.json').read_text())
inputs = {p: hashlib.sha256((repo / p).read_bytes()).hexdigest() == digest for p, digest in saved.items()}
fixed = {}
for path in (repo / 'crates/benitoite/testdata/interval-budget').iterdir():
    if path.is_file():
        relative = str(path.relative_to(repo))
        fixed[relative] = path.read_bytes() == subprocess.check_output(['git', 'show', f'{base}:{relative}'], cwd=repo)
leaks = []
for path in out.rglob('*'):
    if path.is_file():
        source = path.read_text()
        if any(marker and marker in source for marker in [str(repo), str(Path.home()), os.environ.get('TMPDIR', '')]):
            leaks.append(str(path.relative_to(repo)))
links = []
for target in re.findall(r'\]\(([^)]+)\)', (out / 'results.md').read_text()):
    if '://' not in target and not target.startswith('#'):
        links.append({'target': target, 'exists': (out / target.split('#')[0]).exists()})
statistics = {'production_added': 0, 'production_deleted': 0, 'tests_added': 0, 'tests_deleted': 0}
for line in git('diff', '--numstat').splitlines():
    added, deleted, path = line.split('\t')
    if path.startswith('crates/') and path.endswith('.rs'):
        category = 'tests' if path.endswith('/tests.rs') else 'production'
        statistics[category + '_added'] += int(added)
        statistics[category + '_deleted'] += int(deleted)
statistics['tests_added'] += len((repo / 'crates/benitoite/src/typeck/interval/tests/range_calls.rs').read_text().splitlines())
result = {
    'head': git('rev-parse', 'HEAD').strip(),
    'base': base,
    'inputs_unchanged': inputs,
    'fixed_files_match_base': fixed,
    'formal_diff': git('diff', '--name-only', '--', 'formal'),
    'dependency_diff': git('diff', '--name-only', '--', 'Cargo.toml', 'Cargo.lock', 'fuzz/Cargo.toml', 'fuzz/Cargo.lock'),
    'diff_check': subprocess.run(['git', 'diff', '--check'], cwd=repo).returncode,
    'indexed_diff': git('diff', '--cached', '--name-only'),
    'links': links,
    'path_leaks': leaks,
    'rust_lines': statistics,
}
(out / 'final-review.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
assert all(inputs.values()) and all(fixed.values())
assert all(link['exists'] for link in links)
assert not leaks and not result['formal_diff'] and not result['dependency_diff']
assert not result['indexed_diff'] and result['diff_check'] == 0
print('関係入力・固定表・差分・記録の点検はすべて成功')
print(json.dumps(statistics, ensure_ascii=False))
