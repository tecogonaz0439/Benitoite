"""N29 の基準から、Legacy の削除による版だけの移動を厳密に導く。"""
import argparse
import collections
import copy
import json
from pathlib import Path
import sys

BASE = Path(__file__).resolve().parents[1]
ROOT = BASE.parents[1]
sys.path.insert(0, str(ROOT / 'crates/benitoite/tests/desugar_export'))
import check_named as check


def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('directory', type=Path)
    args = parser.parse_args()
    directory = args.directory
    destination = BASE / 'n33'
    manifest = check.read(BASE / 'n29/exchange-manifest.json')
    previous = check.keyed(check.read(BASE / 'n29/routing-manifest.json'))
    actual = check.routing_entries(directory)
    current = check.keyed(actual)
    assert current.keys() == previous.keys()
    changes = []
    for key, before in previous.items():
        after = current[key]
        if before == after:
            continue
        expected = copy.deepcopy(before)
        expected['version'] = 8
        assert before['version'] == 7 and before['excluded'] == []
        assert after == expected, (key, before, after)
        changes.append(dict(before=before, after=after, version_only=True))
    moved = {(c['after']['group'], c['after']['name']) for c in changes}
    assert all(group == 'golden' for group, _ in moved)
    old_programs = check.keyed(manifest['programs'])
    coverage = check.keyed(check.read(directory / 'named-programs-coverage.json')['inputs'])
    corpus = check.read(directory / 'named-programs-corpus.json')
    programs = []
    totals = collections.Counter()
    cov_totals = collections.Counter()
    for item in corpus['inputs']:
        key = item['group'], item['name']
        scopes = collections.Counter(next(iter(d['scope'])) for d in item['definitions'])
        surfaces = [d['scope']['inScope']['surface'] for d in item['definitions'] if 'inScope' in d['scope']]
        implementations = {s['implementation'] for s in surfaces if s['implementation'] is not None}
        checks = sum(s['implementation'] is None for s in surfaces) + len(implementations)
        cov = {kind: len(coverage[key][kind]) for kind in ('matches', 'bindings')}
        entry = dict(group=key[0], name=key[1], definitions=len(item['definitions']), scopes=dict(scopes), coverage=cov,
                     implementations=len(implementations), surfaceChecks=checks)
        if key in old_programs:
            old = old_programs[key]
            assert set(old) - set(entry) <= {"singleSurfaceFailure"}
            assert all(entry[k] == v for k, v in old.items() if k in entry), (key, old, entry)
            programs.append(old)
        else:
            assert key in moved
            assert set(scopes) <= {'inScope', 'accessor'}
            programs.append(entry)
            totals.update(inputs=1, definitions=len(item['definitions']), checks=checks, implementations=len(implementations))
            cov_totals.update(cov)
    assert len(programs) == len(old_programs) + len(moved)
    manifest['programs'] = programs
    manifest['routingManifest'] = 'routing-manifest.json'
    manifest['legacy']['golden'] -= totals['inputs']
    # 元の単一検査の入力も新形式へ移ったため、残る旧形式の独立入力を使う。
    old_single = manifest['legacy']['singleSurfaceInput']
    assert ('golden', old_single) in moved
    manifest['legacy']['singleSurfaceInput'] = 'testdata/effects/c11-lazy-pure.bnt'
    remaining = current['golden', manifest['legacy']['singleSurfaceInput']]
    assert remaining['version'] == 7 and remaining['excluded'] == []
    legacy = manifest['legacyReports']
    legacy['desugar']['golden']['programs']['matched'] -= totals['inputs']
    legacy['desugar']['golden']['definitions']['matched'] -= totals['definitions']
    legacy['builtin']['checkedInputs'] -= totals['inputs']
    pc = legacy['programCoverage']
    pc['inputs'] -= totals['inputs']
    for kind, value in cov_totals.items():
        for field in ('cases', 'matched'):
            pc[kind][field] -= value
    for field in ('cases', 'matched'):
        pc[field] -= sum(cov_totals.values())
    surface = legacy['surface']
    for field in ('inputs', 'fullyCheckedInputs'):
        surface[field] -= totals['inputs']
    surface['implementations'] -= totals['implementations']
    surface['counts']['matched'] -= totals['checks']
    pr = manifest['programReports']
    pr['desugarDefinitions']['matched'] += totals['definitions']
    pr['surfaceCounts']['matched'] += totals['checks']
    pr['coverage']['matched'] += sum(cov_totals.values())
    pr['definitions'] += totals['definitions']
    pr['surfaceChecks'] += totals['checks']
    pr['coverageEntries'] += sum(cov_totals.values())
    write(destination / 'routing-manifest.json', actual)
    write(destination / 'routing-changes.json', changes)
    write(destination / 'exchange-manifest.json', manifest)
    summary = dict(inputs=len(actual), moved=dict(totals), moved_coverage=dict(cov_totals),
                   named_inputs=len(programs), legacy_inputs=manifest['legacy'],
                   identifiers_unchanged=True, classifications_unchanged=True,
                   old_single_surface_input=old_single)
    write(destination / 'exchange-derivation.json', summary)
    print(json.dumps(summary, ensure_ascii=False))


if __name__ == '__main__':
    main()
