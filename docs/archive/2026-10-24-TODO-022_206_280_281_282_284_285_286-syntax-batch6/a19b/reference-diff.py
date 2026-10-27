"""B_WORK と新しい Lean の固定表の差をキーごとに数える。"""
import collections
import json
from pathlib import Path
import subprocess

BASE = '60b2267cbd677a99697df344ae7f29d1bdfcd5f6'
HERE = Path(__file__).resolve().parent
report = {}
for name in ['body', 'whole', 'summary']:
    path = 'crates/benitoite/testdata/interval-budget/' + name + '.tsv'
    old = subprocess.check_output(['git', 'show', BASE + ':' + path], text=True)
    new = Path(path).read_text()
    rows = lambda s: {tuple(r[:3]): r for line in s.splitlines() if not line.startswith('#') for r in [line.split('\t')]}
    before, after = rows(old), rows(new)
    changed = [k for k in before.keys() & after.keys() if before[k] != after[k]]
    added = after.keys() - before.keys()
    removed = before.keys() - after.keys()
    report[name] = {'old': len(before), 'new': len(after), 'changed': dict(collections.Counter(k[0] for k in changed)), 'added': dict(collections.Counter(k[0] for k in added)), 'removed': list(removed)}
assert report['body'] == {'old': 18336, 'new': 18342, 'changed': {'with': 52, 'nestedWith': 106}, 'added': {'with': 2, 'nestedWith': 4}, 'removed': []}
assert all(not report[n]['changed'] and not report[n]['added'] and not report[n]['removed'] for n in ['whole','summary'])
(HERE / 'reference-diff.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report))
