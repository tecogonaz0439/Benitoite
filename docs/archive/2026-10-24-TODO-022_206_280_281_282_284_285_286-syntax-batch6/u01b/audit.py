#!/usr/bin/env python3
"""保存した観測・最大値・入力の不変と、記録の索引を確認する。"""
import ast
import collections
import gzip
import importlib.util
import json
import re
import subprocess
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('inventory', HERE / 'inventory.py')
inventory = importlib.util.module_from_spec(spec)
spec.loader.exec_module(inventory)


def main():
    inputs = inventory.inputs()
    ids = [r['id'] for r in inputs]
    groups = {r['id']: r['group'] for r in inputs}
    maxima = collections.defaultdict(lambda: collections.Counter())
    independent = []
    without_identity = []
    totals = collections.Counter()
    details = {}
    observed_ids = []
    with gzip.open(inventory.RECORDS / 'all-observations.jsonl.gz', 'rt') as stream:
        for line in stream:
            row = json.loads(line)
            observed_ids.append(row['id'])
            if row['id'] == inventory.EXISTING_BUDGET:
                continue
            group = maxima[groups[row['id']]]
            for target in row['targets']:
                summary = target['summary']
                bodies = [r for r in target['observed'] if r.get('kind') != 'whole']
                names = {r['definition'] for r in bodies}
                missing = [b for w in target['observed'] if w.get('kind') == 'whole'
                           for b in w['bodies'] if b['definition'] not in names]
                assert all(b['coverage'] == 'None' for b in missing)
                without_identity.extend({'id': row['id'], 'target': target['target'], **b}
                                        for b in missing)
                assert not any(summary[k] for k in ('bodyBudgetExceeded', 'wholeBudgetSkipped', 'unidentifiedBodies'))
                assert all(v == 0 for k in ('exceeded', 'unidentified') for v in summary['phaseStops'][k].values())
                assert summary['phaseStops']['depth'] == summary['phaseStops']['other'] == 0
                for field, raw in [('maxBodyOperations', 'operations'), ('maxBodyItems', 'peak')]:
                    observed_max = max([int(b['usage'][raw]) for b in bodies] or [0])
                    assert summary[field] >= observed_max
                    if not missing:
                        assert summary[field] == observed_max
                for key in ('operations', 'peakItems', 'maxBodyOperations', 'maxBodyItems'):
                    group[key] = max(group[key], summary[key])
                totals['wholeOperations'] += summary['operations']
                for body in bodies:
                    occurrences = body['occurrences']
                    assert occurrences and int(occurrences[0]['end']) == len(occurrences)
                    assert int(body['next']) == len(occurrences)
                    group['expandedTreeNodes'] = max(group['expandedTreeNodes'], len(occurrences))
                    totals['observedBodyOperations'] += int(body['usage']['operations'])
                    totals['discoveryQueueOperations'] += int(body['usage']['operations']) - int(body['contextBudget']['body']['operations'])
                    if '%body:' in body['definition']:
                        totals['embeddedBodyOperations'] += int(body['usage']['operations'])
                    for item in body['independent']:
                        for candidate in item['candidates']:
                            independent.append({'id': row['id'], 'target': target['target'],
                                'definition': body['definition'], 'start': item['start'], 'candidate': candidate})
                for whole in (r for r in target['observed'] if r.get('kind') == 'whole'):
                    assert whole['limits'] == {'body': {'operations': '100000', 'items': '100000'},
                                               'whole': {'operations': '1000000', 'items': '1000000'}}
                    assert whole['stopped'] is None
    assert observed_ids == ids
    assert len(independent) == 5
    # 全5件は call 引数内の閉じた算術であり、外の事実による未到達の枝はない。
    names = {row['id'] for row in independent}
    assert names == {'crates/benitoite/testdata/eval/int_overflow_' + op + '.bnt'
                     for op in ('add', 'sub', 'mul', 'neg')} | {'crates/benitoite/testdata/runner/run-stopped.bnt'}
    for row in independent:
        row['classification'] = 'closed arithmetic under call argument; no outer branch'
        row['sourceSha256'] = inventory.sha((inventory.ROOT / row['id']).read_bytes())
    details.update(categoryMaxima=maxima, normalTotals=totals, independentCandidates=independent,
                   bodiesWithoutIdentity=without_identity,
                   independentCandidatesInBranchesUnreachableByOuterFacts=0)
    inventory.write(HERE / 'consumption-details.json', details)
    records = []
    for path in sorted(inventory.RECORDS.iterdir()):
        if not path.is_file():
            continue
        data = path.read_bytes()
        plain = gzip.decompress(data) if path.suffix == '.gz' else data
        assert str(inventory.ROOT).encode() not in plain, path.name
        assert str(Path.home()).encode() not in plain, path.name
        records.append({'path': str(path.relative_to(inventory.ROOT)), 'bytes': len(data),
                        'sha256': inventory.sha(data), 'uncompressedBytes': len(plain)})
    inventory.write(HERE / 'records-index.json', records)
    links = 0
    for path in [HERE / 'results.md', HERE.parent / 'u01/warnings.md']:
        for target in re.findall(r'\]\(([^)]+)\)', path.read_text()):
            if '://' not in target and not target.startswith('#'):
                assert (path.parent / target.split('#')[0]).is_file(), (path.name, target)
                links += 1
    for path in HERE.iterdir():
        if not path.is_file():
            continue
        assert path.stat().st_size <= 1_000_000, path.name
        data = path.read_bytes()
        assert str(inventory.ROOT).encode() not in data, path.name
        assert str(Path.home()).encode() not in data, path.name
        if path.suffix == '.json':
            json.loads(data)
        if path.suffix == '.py':
            ast.parse(data)
    subprocess.run(['git', 'diff', '--check'], cwd=inventory.ROOT, check=True)
    inventory.write(HERE / 'audit.json', {'inputEntriesUnchanged': len(ids),
        'normalEntries': 1216, 'normalBudgetStops': 0, 'normalIncompleteTrees': 0,
        'rawRecords': len(records), 'rawRecordBytes': sum(r['bytes'] for r in records),
        'relativeLinks': links, 'filesAtMostOneMB': True,
        'unredactedHomeOrRepoPaths': 0})
    print(json.dumps({'entries': len(ids), 'rawFiles': len(records), 'links': links,
                      'normalBudgetStops': 0, 'normalIncompleteTrees': 0}))


if __name__ == '__main__':
    main()
