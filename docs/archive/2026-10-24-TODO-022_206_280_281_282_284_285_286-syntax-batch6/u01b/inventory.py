#!/usr/bin/env python3
"""U01a の固定入力に対する区間解析の消費を、既存の観測から集計する。"""
import collections
import gzip
import hashlib
import json
import os
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
OLD = HERE.parent / 'u01a'
RECORDS = ROOT / 'work/m012/records/u01b'
MANIFEST_SHA = '162de8184a81e1fdecd91a62297e46d6f325f867d381a2db5971b9127d19068a'
EXISTING_BUDGET = 'crates/benitoite/testdata/types/todo178-const-budget.bnt'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')


def redact(text):
    for old, new in [(str(ROOT), '<repo>'), (str(Path.home()), '<home>'),
                     ('/private/tmp', '<tmp>'), ('/tmp', '<tmp>')]:
        text = text.replace(old, new)
    return text


def inputs():
    data = (OLD / 'inputs.json').read_bytes()
    assert sha(data) == MANIFEST_SHA
    rows = json.loads(data)['inputs']
    assert len(rows) == 1217
    # パッケージの付属入力も含め、固定された実ソースと設定を照合する。
    checked = 0
    inherited = []
    for file in ('hosts.json', 'support-hosts.json'):
        for row in json.loads((OLD / file).read_text()):
            if row['path'] == 'crates/benitoite/src/pipeline.rs':
                # 差分は cfg(test) の観測補助の登録だけ。実ソースの入力ではない。
                baseline = subprocess.check_output(['git', 'show',
                    'd1c590250126af256628baa409c833b894b353aa:' + row['path']], cwd=ROOT)
                marker = b'#[cfg(test)]\nmod tests {'
                registration = b'#[cfg(test)]\n#[path = "pipeline/interval_inventory.rs"]\nmod interval_inventory;\n\n'
                assert (ROOT / row['path']).read_bytes() == baseline.replace(marker, registration + marker, 1)
                continue
            if row['path'] == 'crates/benitoite/tests/desugar_export/interval/manifest.rs':
                current = (ROOT / row['path']).read_bytes()
                baseline = subprocess.check_output(['git', 'show', 'd1c590250126af256628baa409c833b894b353aa:' + row['path']], cwd=ROOT)
                assert current == baseline
                inherited.append({'path': row['path'], 'oldSha256': row['sha256'],
                                  'workSha256': sha(current), 'reason': 'X05T observation assertion'})
                continue
            assert sha((ROOT / row['path']).read_bytes()) == row['sha256'], row['path']
            checked += 1
    for row in rows:
        path = ROOT / row['path']
        if path.is_file():
            assert sha(path.read_bytes()) == row['sha256'], row['id']
        for support in row.get('support', []):
            assert sha((path.parent / support['path']).read_bytes()) == support['sha256']
    write(HERE / 'input-check.json', {'manifestSha256': MANIFEST_SHA,
          'inputs': len(rows), 'unchangedHosts': checked,
          'inheritedHostChanges': inherited,
          'testHelperRegistration': 'crates/benitoite/src/pipeline.rs'})
    return rows


def dedicated():
    params = ', '.join(f'p{i}: Integer' for i in range(200))
    values = ', '.join(['1'] * 600)
    result = []
    for name, count in [('bodyBudget', 1), ('wholeBudget', 16)]:
        text = ''.join(f'function many{i}({params}) -> List[Integer]\n return [{values}]\nend function\n'
                       for i in range(count))
        path = RECORDS / (name + '.bnt')
        path.write_text(text)
        result.append({'id': 'dedicated:' + name, 'path': str(path.relative_to(ROOT)),
                       'command': 'test', 'group': 'dedicated-budget', 'sha256': sha(path.read_bytes())})
    return result


def collect(mode):
    RECORDS.mkdir(parents=True, exist_ok=True)
    rows = inputs()
    if mode == 'pilot':
        names = [
            'tools/bench/suite/list_build.bnt',
            'crates/benitoite/testdata/warnings/local-width-intervals.bnt',
            'crates/benitoite/tests/desugar_export/interval/range.bnt',
            'crates/benitoite/testdata/stdlib/width-bits-s8-invalid.bnt',
        ]
        chosen = [r for r in rows if r['id'] in names]
        # 種類の偏りを避け、文書・パッケージ・拒否入力・定数を含める。
        for group in ('bench-input', 'golden-package', 'reference', 'skill-handwritten',
                      'standard-doc', 'golden-or-fixture', 'tool-input'):
            row = next(r for r in rows if r['group'] == group and r not in chosen)
            chosen.append(row)
        rows = chosen[:10]
        assert len(rows) == 10
    elif mode == 'dedicated':
        rows = dedicated()
    request = RECORDS / (mode + '-request.json')
    write(request, {'inputs': rows})
    raw = RECORDS / (mode + '-observations.jsonl')
    command = ['cargo', 'test', '-p', 'benitoite', '--lib',
               'pipeline::interval_inventory::interval_inventory_matches_pipeline',
               '--', '--exact', '--nocapture']
    start = time.monotonic()
    proc = subprocess.run(command, cwd=ROOT, capture_output=True,
                          env={**os.environ, 'BENITOITE_INTERVAL_INVENTORY': str(request),
                               'BENITOITE_INTERVAL_RECORDS': str(raw)})
    elapsed = time.monotonic() - start
    (HERE / (mode + '.log')).write_text(redact(proc.stdout.decode(errors='replace') +
                                             proc.stderr.decode(errors='replace')))
    write(HERE / (mode + '-run.json'), {'command': command, 'exit': proc.returncode,
          'seconds': elapsed, 'inputs': len(rows), 'manifestSha256': MANIFEST_SHA})
    if raw.exists():
        with raw.open() as stream, gzip.open(str(raw) + '.gz', 'wt') as output:
            for line in stream:
                output.write(redact(line))
        raw.unlink()
    assert proc.returncode == 0, 'observation failed; see log'
    summarize(mode, rows)
    print(json.dumps({'mode': mode, 'inputs': len(rows), 'seconds': elapsed,
                      'allEstimateSeconds': elapsed / len(rows) * 1217}))


def summarize(mode, rows, subset=None):
    records = [json.loads(line) for line in gzip.open(RECORDS / (mode + '-observations.jsonl.gz'), 'rt')]
    if subset:
        ids = {r['id'] for r in rows}
        records = [r for r in records if r['id'] in ids]
    assert [r['id'] for r in records] == [r['id'] for r in rows]
    groups = {r['id']: r['group'] for r in rows}
    maxima = {}
    compact = []
    stops = []
    categories = collections.defaultdict(collections.Counter)
    all_bodies = []
    incomplete_trees = []

    def maximum(key, number, identity):
        if key not in maxima or number > maxima[key]['value']:
            maxima[key] = {'value': number, **identity}

    for row in records:
        group = groups[row['id']]
        counts = categories[group]
        counts['entries'] += 1
        targets = []
        for target in row['targets']:
            identity = {'id': row['id'], 'target': target['target']}
            summary = target['summary']
            counts['targets'] += 1
            counts['acceptedTargets'] += target['accepted']
            counts['typecheckedTargets'] += target['stage'] == 'typecheck'
            counts['unstartedTargets'] += target['stage'] != 'typecheck'
            phase = summary['phaseStops']
            stopped = any(summary[k] for k in ('bodyBudgetExceeded', 'wholeBudgetSkipped', 'unidentifiedBodies'))
            stopped |= any(phase[k][v] for k in ('exceeded', 'unidentified') for v in phase[k])
            if stopped:
                stops.append({**identity, 'summary': summary})
            counts['budgetStoppedTargets'] += stopped
            counts['depthStops'] += phase['depth']
            counts['otherStops'] += phase['other']
            # load/resolve で止まった未着手は測定したゼロに含めない。
            if target['stage'] == 'typecheck':
                for key in ('operations', 'peakItems', 'savedItems', 'maxBodyOperations', 'maxBodyItems'):
                    maximum(key, summary[key], identity)
            bodies = []
            for body in target['observed']:
                if body.get('kind') == 'whole':
                    assert int(body['after']['operations']) == summary['operations']
                    assert int(body['after']['peak']) == summary['peakItems']
                    continue
                info = {**identity, 'definition': body['definition']}
                occurrences = body['occurrences']
                tree_complete = bool(occurrences) and occurrences[0]['end'] is not None
                item = {**info, 'usage': body['usage'], 'contextBudget': body['contextBudget'],
                        'coverage': body['coverage'], 'expandedTreeNodes': len(occurrences),
                        'next': body['next'], 'treeComplete': tree_complete,
                        'constantReferences': sum(o['form'] == 'Const' for o in occurrences),
                        'embeddedBody': '%body:' in body['definition'],
                        'independentInputs': len(body['independent']),
                        'parentCandidates': len(body['candidates']),
                        'independentCandidates': sum(len(i['candidates']) for i in body['independent'])}
                assert int(body['next']) == len(occurrences), info
                counts['bodies'] += 1
                counts['embeddedBodies'] += item['embeddedBody']
                counts['constantReferences'] += item['constantReferences']
                counts['numberedNodes'] += len(occurrences)
                counts['independentInputs'] += item['independentInputs']
                counts['parentCandidates'] += item['parentCandidates']
                counts['independentCandidates'] += item['independentCandidates']
                if tree_complete:
                    maximum('expandedTreeNodes', len(occurrences), info)
                else:
                    incomplete_trees.append(info)
                for field in ('operations', 'peak'):
                    maximum('body.' + field, int(body['usage'][field]), info)
                bodies.append(item)
                all_bodies.append(item)
            targets.append({**identity, 'accepted': target['accepted'], 'stage': target['stage'],
                            'errors': target['errors'], 'summary': summary,
                            'bodies': len(bodies)})
        compact.append({'id': row['id'], 'group': group, 'targets': targets})
    name = subset or mode
    write(HERE / (name + '-summary.json'), {'manifestSha256': MANIFEST_SHA,
          'entries': len(records), 'categories': categories, 'maxima': maxima,
          'budgetStoppedTargets': stops, 'incompleteTrees': incomplete_trees,
          'standardBodies': 'excluded; not analyzed; consumption unacquired'})
    for offset in range(0, len(compact), 150):
        write(HERE / f'{name}-inputs-{offset // 150:02}.json', compact[offset:offset + 150])
    with gzip.open(RECORDS / (name + '-bodies.jsonl.gz'), 'wt') as output:
        for body in all_bodies:
            output.write(json.dumps(body, ensure_ascii=False) + '\n')
    if mode == 'all' and subset is None:
        normal = [r for r in rows if r['id'] != EXISTING_BUDGET]
        special = [r for r in rows if r['id'] == EXISTING_BUDGET]
        assert len(normal) == 1216 and len(special) == 1
        evidence = ROOT / EXISTING_BUDGET.replace('.bnt', '.diag.json')
        expected = [json.loads(line) for line in evidence.read_text().splitlines()]
        assert any(d['code'] == 'E0435' and '67108864' in d['message'] for d in expected)
        write(HERE / 'classification.json', {'normalEntries': len(normal),
              'existingDedicatedBudget': special, 'evidence': str(evidence.relative_to(ROOT)),
              'evidenceSha256': sha(evidence.read_bytes()),
              'intent': 'existing constant-evaluation 64 MiB budget overflow; interval body budget also reached',
              'inputRewrites': []})
        summarize(mode, normal, 'normal')
        summarize(mode, special, 'existing-dedicated')


if __name__ == '__main__':
    if sys.argv[1] == 'summarize':
        summarize('all', inputs())
    else:
        collect(sys.argv[1])
