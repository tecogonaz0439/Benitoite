"""L16 の接続後の実行値を一度だけ計算し、保存済みの固定表との差を記録する。

保存済みの body.tsv・whole.tsv・summary.tsv は読み取りだけにする。
生成器の生成関数と選択規則をそのまま使い、比較対象の列や小予算を除外しない。
"""
from pathlib import Path
import collections
import hashlib
import importlib.util
import json

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
DIRECTORY = ROOT / 'crates/benitoite/testdata/interval-budget'
spec = importlib.util.spec_from_file_location('reference_generator', DIRECTORY / 'regenerate-reference.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
before = {name: (DIRECTORY / f'{name}.tsv').read_bytes() for name in ('body', 'whole', 'summary')}
# この呼び出しだけが二つの Lean 入力を直列に各一度実行する。
tables = module.generate(OUT / 'resume-reference')
columns = {
    'body': 'name kind cap operations saved peak next stop warnings independent unsupported'.split(),
    'whole': 'name kind cap operations saved peak bodies warnings phases discovered pending remaining stop modules'.split(),
    'summary': 'name kind cap inputDefinitions unsupportedBodies bodyBudgetExceeded wholeBudgetSkipped unidentifiedBodies phaseStops'.split(),
}
summary = {}
for name, rows in tables.items():
    oldrows = [line.split('\t') for line in before[name].decode().splitlines() if not line.startswith('#')]
    old = {tuple(row[:3]): row for row in oldrows}
    new = {tuple(row[:3]): row for row in rows}
    changed = collections.defaultdict(lambda: {'changed': 0, 'removed': 0, 'added': 0, 'columns': set()})
    for key in old.keys() | new.keys():
        if key not in old:
            changed[key[0]]['added'] += 1
        elif key not in new:
            changed[key[0]]['removed'] += 1
        elif old[key] != new[key]:
            changed[key[0]]['changed'] += 1
            changed[key[0]]['columns'].update(column for column, left, right in zip(columns[name], old[key], new[key]) if left != right)
    result = {'old_rows': len(oldrows), 'new_rows': len(rows), 'shapes': {}}
    for shape, details in sorted(changed.items()):
        details['columns'] = [column for column in columns[name] if column in details['columns']]
        if name == 'body':
            oldgroups = [[row for row in oldrows if row[0] == shape and row[1] == str(kind)] for kind in range(4)]
            newgroups = [[row for row in rows if row[0] == shape and row[1] == str(kind)] for kind in range(4)]
            details['old_success_caps'] = [next(int(row[2]) for row in group if row[7] == '0') for group in oldgroups]
            details['new_success_caps'] = [next(int(row[2]) for row in group if row[7] == '0') for group in newgroups]
            details['old_complete'] = oldgroups[0][-1][3:]
            details['new_complete'] = newgroups[0][-1][3:]
        result['shapes'][shape] = details
    assert (DIRECTORY / f'{name}.tsv').read_bytes() == before[name]
    result['saved_sha256'] = hashlib.sha256(before[name]).hexdigest()
    summary[name] = result
(OUT / 'reference-impact.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2) + '\n')
print(json.dumps(summary, ensure_ascii=False, indent=2))
