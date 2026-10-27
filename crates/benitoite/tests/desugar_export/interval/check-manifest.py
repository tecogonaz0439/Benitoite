#!/usr/bin/env python3
"""独立期待値と実ソースを分け、関係定義の全列挙を Lean の実入口と照合する。

実ソースの通常解析の値・消費・警告の一致は X02b、VM は X03 が扱う。
この検査の操作上限0の読者入力を解析比較の成功に数えない。
"""
import argparse
from collections import Counter
import json
from pathlib import Path
import subprocess
import time
import gzip
import shutil
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[5]/"scripts/check"))
from interval_artifacts import read, exclusions


def unique(rows, key):
    keys = [row[key] for row in rows]
    assert len(keys) == len(set(keys)), ('duplicate', key)
    return {row[key]: row for row in rows}


def check_source(directory, output, executable, legacy=None, supplemental=()):
    manifests = read(directory/'interval-manifest.json')['inputs']
    materials = unique(read(directory/'interval-material.json')['inputs'], 'name')
    observations = unique(read(directory/'interval-observations.json')['inputs'], 'name')
    succeeded = [row for row in manifests if row['checker'] == 'succeeded']
    assert succeeded, 'empty source manifest'
    assert all(row['enumerationComplete'] for row in succeeded), 'source enumeration incomplete; report exclusions'
    assert len({(row['group'], row['name']) for row in manifests}) == len(manifests)
    if legacy is not None:
        before = read(legacy)['inputs']
        mirrored = [row for row in manifests if row['group'] not in supplemental]
        assert [(row['group'], row['name']) for row in before] == [(row['group'], row['name']) for row in mirrored], 'legacy input manifest differs'
    counts = Counter()
    for row in manifests:
        counts.update({key: int(value) for key, value in row['counts'].items()})
    # 未解析と他の型の Bottom を、非 Top の正常値へ数えない。
    assert counts['informativeBodies'] > 0, 'allTop source observations'
    for row in succeeded:
        material = materials[row['input']]
        excluded = exclusions(row, observations[row['input']])
        excluded_names = {e['definition'] for e in excluded}
        excluded_bodies = {b for e in excluded for b in e['bodies']}
        roots = [definition for module in material['modules'] for definition in module['definitions']]
        assert [r['name'] for r in roots] == [r['source']['name'] for r in row['definitions'] if r['source']['name'] not in excluded_names]
        assert int(row['counts']['inputDefinitions']) == len(roots)+len(excluded)
        assert row['manifest'] == [body for definition in row['definitions'] for body in definition['manifest']], 'source body manifest order'
        assert len(row['manifest']) == len(set(row['manifest'])) == int(row['counts']['allBodies'])
        assert [body['definition'] for body in row['bodies']] == row['manifest']
        observed = observations[row['input']]['bodies']
        assert len([body for body in observed if body.get('kind') == 'whole']) == 1
        actual = unique([body for body in observed if body.get('kind') != 'whole'], 'definition')
        assert set(actual).issubset(row['manifest'])
        assert sum(body['analyzed'] for body in row['bodies']) == int(row['counts']['analyzedBodies'])
        assert int(row['counts']['notAnalyzedBodies']) + len(actual) == len(row['manifest'])
        for field, flag in [('topBodies', 'top'), ('bottomBodies', 'bottom'),
                            ('informativeBodies', 'informative'), ('depthBodies', 'depth')]:
            assert sum(body[flag] is True for body in row['bodies']) == int(row['counts'][field]), (row['name'], field)
        for body in row['bodies']:
            if body['definition'] in excluded_bodies:
                continue
            assert body['analyzed'] == (body['definition'] in actual)
            if body['valueAvailable']:
                assert body['top'] is not None
            else:
                assert not body['informative']
            if not body['analyzed']:
                owner = body['definition'].split('%body:')[0]
                whole = row['whole']
                phase = next((p for p in whole['phases'] if p['definition'] == owner), None)
                remaining = whole['remainingDefinitions'] + [d for module in whole['remainingModules'] for d in module]
                assert owner in remaining or phase is not None and (
                    phase['entry'] != 'complete' or phase['discovery'] != 'complete'
                    or phase['queue'] != 'complete' or phase['embeddedStop'] is not None
                    or body['definition'] in phase['pending']), ('missing body without stop', body['definition'])
    # 複数定義・空モジュール・全別本体を含む同じ入力順の manifest を比較する。
    report_path = output/'source-manifest.report.json'
    source_path = directory/'interval-manifest-corpus.json'
    with source_path.open() as stream:
        indexed = stream.read(40).startswith('{"kind":"interval-source-index"')
    if indexed:
        source_path = output/'source-manifest.input.json'
        source_path.write_text(json.dumps(read(directory/'interval-manifest-corpus.json'),
                                         ensure_ascii=False, separators=(',', ':')))
    command = [str(executable), 'analyze', str(source_path), str(report_path)]
    started = time.monotonic()
    process = subprocess.run(command, capture_output=True, text=True, timeout=60)
    report = read(report_path)
    if indexed:
        with source_path.open('rb') as raw, source_path.with_suffix('.json.gz').open('wb') as target:
            with gzip.GzipFile(filename='', mode='wb', fileobj=target, mtime=0) as saved:
                shutil.copyfileobj(raw, saved)
        source_path.unlink()
    assert process.returncode == 1 and report['matched'] and not report['accepted'], report
    assert report['comparedCount'] == '0' and report['informativeCount'] == '0'
    assert report['acceptanceReasons'] == ['emptyComparison', 'allTop']
    assert report['excludedCount'] == '0' and report['phaseDepthCount'] == '0'
    assert [row['name'] for row in report['inputs']] == [row['input'] for row in succeeded]
    for wanted, actual in zip(succeeded, report['inputs']):
        excluded_bodies = {b for e in wanted.get('excluded', []) for b in e['bodies']}
        expected_manifest = [b for b in wanted['manifest'] if b not in excluded_bodies]
        assert expected_manifest == actual['manifest'], (wanted['name'], actual['manifest'])
        assert actual['bodies'] == []
        assert [body['definition'] for body in actual['unproducedBodies']] == expected_manifest
        assert all(not body['mismatches'] for body in actual['unproducedBodies'])
        assert int(actual['counts']['inputDefinitions']) == int(wanted['counts']['inputDefinitions'])-len(wanted.get('excluded', []))
    return dict(inputs=len(manifests), excluded=[dict(input=m['input'], **e) for m in succeeded for e in m.get('excluded', [])], counts=dict(counts), manifestMatched=True,
                readerExit=process.returncode, seconds=round(time.monotonic()-started, 3),
                legacyInputCount=len(before) if legacy is not None else None,
                supplementalSourceCount=sum(row['group'] in supplemental for row in manifests),
                legacyInputsPreserved=True if legacy is not None else None,
                rustAnalysisCompared=False, vmCompared=False)


def check_independent(directory):
    results = []
    for selection in read(directory/'fuel-selection.json'):
        profile = selection['profile']
        attempt = len(selection['attempts'])-1
        label = profile+'-analyze-'+str(attempt)
        input_name = label+'.input.json'
        if profile == 'flow-containers':
            label, input_name = 'fuel-selected', 'fuel-selected.json'
        corpus = read(directory/input_name)
        report = read(directory/(label+'.report.json'))
        assert report['matched'] and report['accepted'] and int(report['informativeCount']) > 0
        assert report['excludedCount'] == '0' and report['phaseDepthCount'] == '0'
        roots = bodies = 0
        for source, actual in zip(corpus['inputs'], report['inputs']):
            expected = [d['name'] for module in source['modules'] for d in module['definitions']]
            expected += [body['definition'] for body in source.get('expectedBodies', [])]
            assert len(expected) == len(set(expected))
            assert set(expected) == set(actual['manifest']), (profile, source['name'])
            roots += sum(len(module['definitions']) for module in source['modules'])
            bodies += len(expected)
        assert len(corpus['inputs']) == len(report['inputs'])
        assert str(roots) == report['profileManifest']['definitionCount']
        assert str(bodies) == report['profileManifest']['bodyCount'] == report['comparedCount']
        results.append(dict(profile=report['profile'], label=profile, inputs=len(corpus['inputs']), definitions=roots,
                            bodies=bodies, informative=int(report['informativeCount']), manifestMatched=True))
    assert {row['profile'] for row in results} == {'base', 'flow', 'width', 'range', 'domain'}
    return results


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-dir', required=True, type=Path)
    parser.add_argument('--independent-dir', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--legacy-corpus', type=Path)
    parser.add_argument('--supplemental-group', action='append', default=[])
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    executable = Path(__file__).resolve().parents[5]/'formal'/'.lake'/'build'/'bin'/'intervalDiff'
    result = dict(realSource=check_source(args.source_dir, args.output, executable, args.legacy_corpus, args.supplemental_group),
                  independent=check_independent(args.independent_dir))
    (args.output/'manifest-comparison.json').write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n')
    print(json.dumps(result, ensure_ascii=False))


if __name__ == '__main__':
    main()
