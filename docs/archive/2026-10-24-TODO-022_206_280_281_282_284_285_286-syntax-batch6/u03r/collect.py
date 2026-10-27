#!/usr/bin/env python3
"""U02b・U03a の追加4例をそのまま取り出し、既存の観測入口で測る。"""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]


def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')


def main():
    inputs_dir = HERE / 'inputs'
    inputs_dir.mkdir(exist_ok=True)
    rows = []
    documents = ['docs/reference/benitoite.md',
                 'crates/benitoite/skill/references/idioms.md']
    selectors = [
        (documents[0], 'reference-http', 'benitoite check', 'bind plain <- Http.text', 'check'),
        (documents[1], 'skill-http', 'benitoite check', 'bind response <- Http.text', 'check'),
        (documents[1], 'skill-range', 'benitoite test', 'function checkedIncrement', 'test'),
        (documents[1], 'skill-warnings', 'text', 'function divide(value:', 'check'),
    ]
    for document, name, info, marker, command in selectors:
        text = (ROOT / document).read_text()
        blocks = [m for m in re.finditer(r'^```([^\n]*)\n(.*?)^```\s*$', text, re.M | re.S)
                  if m[1] == info and marker in m[2]]
        assert len(blocks) == 1, name
        block = blocks[0]
        source = block[2]
        path = inputs_dir / (name + '.bnt')
        path.write_text(source)
        rows.append({'id': name, 'path': str(path.relative_to(ROOT)), 'command': command,
                     'document': document, 'line': text[:block.start()].count('\n') + 1,
                     'sha256': hashlib.sha256(source.encode()).hexdigest(),
                     'documentSha256': hashlib.sha256(text.encode()).hexdigest()})
    manifest = HERE / 'inputs.json'
    write(manifest, {'inputs': rows})
    env = dict(os.environ, BENITOITE_INTERVAL_INVENTORY=str(manifest),
               BENITOITE_INTERVAL_RECORDS=str(HERE / 'observations.jsonl'))
    command = ['cargo', 'test', '-p', 'benitoite', '--lib',
               'pipeline::interval_inventory::interval_inventory_matches_pipeline',
               '--', '--exact', '--nocapture']
    subprocess.run([sys.executable, str(HERE / 'run.py'), 'plain', 'inventory'] + command,
                   cwd=ROOT, env=env, check=True)
    records = [json.loads(line) for line in (HERE / 'observations.jsonl').read_text().splitlines()]
    assert [r['id'] for r in records] == [r['id'] for r in rows]
    maxima = {}
    entries = []
    bodies = 0
    for row in records:
        assert len(row['targets']) == 1, row['id']
        target = row['targets'][0]
        assert target['stage'] == 'typecheck' and target['accepted'], row['id']
        summary = target['summary']
        assert all(summary[key] == 0 for key in
                   ('bodyBudgetExceeded', 'wholeBudgetSkipped', 'unidentifiedBodies'))
        phase = summary['phaseStops']
        assert not any(phase[k][v] for k in ('exceeded', 'unidentified') for v in phase[k])
        assert phase['depth'] == phase['other'] == 0
        for field in ('maxBodyOperations', 'maxBodyItems', 'operations', 'peakItems'):
            value = summary[field]
            if field not in maxima or value > maxima[field]['value']:
                maxima[field] = {'value': value, 'id': row['id']}
        for body in target['observed']:
            if body.get('kind') == 'whole':
                assert int(body['after']['operations']) == summary['operations']
                assert int(body['after']['peak']) == summary['peakItems']
                continue
            bodies += 1
            occurrences = body['occurrences']
            assert occurrences and occurrences[0]['end'] is not None
            assert int(body['next']) == len(occurrences)
        entries.append({'id': row['id'], 'summary': summary})
    write(HERE / 'consumption.json', {'entries': entries, 'bodies': bodies,
          'maxima': maxima, 'budgetStoppedTargets': 0, 'depthStops': 0, 'otherStops': 0,
          'manifestSha256': hashlib.sha256(manifest.read_bytes()).hexdigest(),
          'observationsSha256': hashlib.sha256((HERE / 'observations.jsonl').read_bytes()).hexdigest()})
    print(json.dumps({'bodies': bodies, 'maxima': maxima}, ensure_ascii=False))


if __name__ == '__main__':
    main()
