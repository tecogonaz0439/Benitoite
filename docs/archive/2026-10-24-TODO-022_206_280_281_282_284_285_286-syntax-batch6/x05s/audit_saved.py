"""保存済みの二回のK1を読み、負例の選択と全件の固定前提を点検する。"""
from collections import Counter
import hashlib
import json
from pathlib import Path
import re
import sys
import zipfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(ROOT/'formal/tests'))
import interval_source_compare as compare
sys.path.insert(0, str(ROOT/'scripts/check'))
import formal_interval as whole

RUN = 'x05a-k1-run2-20261027'
TARGET = ROOT/'target/x05s-records'


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024*1024), b''):
            h.update(block)
    return h.hexdigest()


def inputs(path):
    # 全件manifestの本文を一度に保持せず、同じ入力順で照合する。
    with path.open() as stream:
        decoder, buffer = json.JSONDecoder(), ''
        while True:
            block = stream.read(1024*1024)
            assert block, ('inputs missing', path.name)
            buffer += block
            match = re.search(r'"inputs"\s*:\s*\[', buffer)
            if match:
                buffer = buffer[match.end():]
                break
        while True:
            buffer = buffer.lstrip()
            if buffer.startswith(']'):
                return
            if buffer.startswith(','):
                buffer = buffer[1:].lstrip()
            try:
                value, end = decoder.raw_decode(buffer)
            except json.JSONDecodeError:
                block = stream.read(1024*1024)
                assert block, ('truncated inputs', path.name)
                buffer += block
                continue
            buffer = buffer[end:]
            yield value


def scan(directory, reports=None):
    observations = inputs(directory/'interval-observations.json')
    materials = inputs(directory/'interval-material.json')
    totals, first, selections, selected = Counter(), {}, {}, []
    names, index = [], 0
    for manifest in inputs(directory/'interval-manifest.json'):
        totals['manifestInputs'] += 1
        names.append((manifest['group'], manifest['name']))
        if manifest['checker'] != 'succeeded':
            totals['checkerFailed'] += 1
            continue
        observation, material = next(observations), next(materials)
        name = manifest['input']
        assert observation['name'] == material['name'] == name, 'source order differs'
        assert manifest['enumerationComplete']
        assert material['limits'] == dict(body=dict(operations='100000', items='100000'),
                                         whole=dict(operations='1000000', items='1000000'))
        totals['succeeded'] += 1
        totals.update({k: int(v) for k, v in manifest['counts'].items()})
        excluded = compare.exclusions(manifest, observation)
        entries = compare.correspondence(manifest)
        bodies = compare.unique([b for b in observation['bodies'] if b.get('kind') != 'whole'], 'definition')
        assert sum(b.get('kind') == 'whole' for b in observation['bodies']) == 1
        assert manifest['manifest'] == [n for d in manifest['definitions'] for n in d['manifest']]
        assert len(manifest['manifest']) == len(set(manifest['manifest'])) == int(manifest['counts']['allBodies'])
        roots = [d for m in material['modules'] for d in m['definitions']]
        excluded_names = {e['definition'] for e in excluded}
        assert [d['name'] for d in roots] == [d['source']['name'] for d in manifest['definitions']
                                            if d['source']['name'] not in excluded_names]
        assert len(roots)+len(excluded) == int(manifest['counts']['inputDefinitions'])
        assert [b['definition'] for b in manifest['bodies']] == manifest['manifest']
        assert set(bodies) <= set(manifest['manifest'])
        assert len(bodies) == int(manifest['counts']['analyzedBodies'])
        assert len(bodies)+int(manifest['counts']['notAnalyzedBodies']) == len(manifest['manifest'])
        for field, flag in [('topBodies', 'top'), ('bottomBodies', 'bottom'),
                            ('informativeBodies', 'informative'), ('depthBodies', 'depth')]:
            assert sum(b[flag] is True for b in manifest['bodies']) == int(manifest['counts'][field])
        standards = {s['declaration']: s['name'] for s in material['standards']}
        wanted = []
        for body_name, body in bodies.items():
            if body_name not in entries:
                continue
            expectation = compare.expectation(body, entries[body_name], standards)
            for field in ['integer', 'after', 'context', 'next', 'warnings', 'independent']:
                eligible = (field != 'warnings' or expectation['warnings']) and (
                    field != 'independent' or any(c['warnings'] for c in expectation['independent']))
                if eligible and field not in selections:
                    selections[field] = dict(input=name, definition=body_name)
                    wanted.append(field)
        codes = [w['code'] for w in observation['warnings']]
        relevant = compare.compared_warnings(observation)
        for label, eligible in [('anyWarning', codes), ('userWarnings', relevant),
                                ('irrelevantOnly', codes and not relevant),
                                ('mixed', relevant and len(relevant) < len(codes)), ('externalType', excluded)]:
            if eligible:
                totals[label+'Inputs'] += 1
                if label not in first:
                    first[label] = dict(input=name, index=index, codes=codes)
                    wanted.append(label)
        for phase in manifest['whole']['phases']:
            for field in ['entry', 'discovery', 'queue']:
                if isinstance(phase[field], dict):
                    totals['stop-'+field] += 1
                    if field not in first:
                        first[field] = dict(input=name, definition=phase['definition'])
                        wanted.append(field)
            if phase['embeddedStop'] is not None:
                totals['stop-embedded'] += 1
        if reports is not None:
            report_path = reports/('source-analysis-'+str(index)+'.report.json')
            report = json.loads(report_path.read_text())
            assert report['matched'] and report['excludedCount'] == report['phaseDepthCount'] == '0'
            assert int(report['comparedCount']) == len(bodies)-int(manifest['counts'].get('excludedBodies', '0'))
            assert report['informativeCount'] == manifest['counts']['informativeBodies']
            compare.compare_structure(report['inputs'][0], manifest, bodies, entries)
            compare.compare_warnings(report['inputs'][0], observation, manifest, entries)
        if wanted:
            selected.append(dict(input=name, index=index, reasons=wanted))
        index += 1
    assert next(observations, None) is None and next(materials, None) is None
    assert len(names) == len(set(names))
    return dict(totals=dict(totals), first=first, selections=selections, selected=selected,
                inputOrderSha256=hashlib.sha256(json.dumps(names).encode()).hexdigest())


def archives():
    result = []
    for number, archive, index_path in [
        (1, HERE.parent/'x05a/k1-records.zip', HERE.parent/'x05a/k1-records-index.json'),
        (2, ROOT/'work/m012/records/x05a-run2-k1-records.zip', HERE.parent/'x05a/run2/k1-records-index.json')]:
        index = json.loads(index_path.read_text())
        sha = digest(archive)
        assert sha == index['zipSha256']
        rows = {r['path']: r for r in index['files'] if r['persisted']}
        with zipfile.ZipFile(archive) as saved:
            assert set(saved.namelist()) == set(rows)
            # 本文を省いた項目は索引に残す。ZIPにある本文は全てハッシュを読む。
            for name, row in rows.items():
                assert hashlib.sha256(saved.read(name)).hexdigest() == row['sha256'], name
            shapes = []
            for directory in whole.SOURCE_DIRS[1:]:
                manifest = json.loads(saved.read('interval/'+directory+'/interval-manifest.json'))
                observation = json.loads(saved.read('interval/'+directory+'/interval-observations.json'))
                successful = [m for m in manifest['inputs'] if m['checker'] == 'succeeded']
                assert [m['input'] for m in successful] == [o['name'] for o in observation['inputs']]
                shapes.append(dict(directory=directory, inputs=len(manifest['inputs']),
                    succeeded=len(successful), outside=sum(len([d for d in m['definitions'] if d['outside']]) for m in successful),
                    warningCodes=sorted({w['code'] for o in observation['inputs'] for w in o['warnings']})))
        result.append(dict(run=number, archive=archive.relative_to(ROOT).as_posix(), sha256=sha,
                           persisted=len(rows), omitted=[r['path'] for r in index['files'] if not r['persisted']],
                           shapes=shapes))
    return result


def main():
    TARGET.mkdir(parents=True, exist_ok=True)
    summary = dict(archives=archives(), sources=[])
    for name in whole.SOURCE_DIRS:
        if name == 'programs':
            directories = [ROOT/'target/desugar-diff'/RUN/(stem+'-interval')
                           for stem in ['named-programs', 'independent-program']]
        else:
            directories = [ROOT/'target/interval-diff'/RUN/name]
        for directory in directories:
            reports = ROOT/'target/interval-diff'/RUN/'comparison/real-source-0' if directory == directories[0] and name == 'programs' else None
            result = scan(directory, reports)
            summary['sources'].append(dict(directory=directory.relative_to(ROOT).as_posix(), **result))
            print(json.dumps(dict(directory=name, totals=result['totals'], first=result['first']), ensure_ascii=False), flush=True)
    (HERE/'saved-audit-details.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2)+'\n')


if __name__ == '__main__':
    main()
