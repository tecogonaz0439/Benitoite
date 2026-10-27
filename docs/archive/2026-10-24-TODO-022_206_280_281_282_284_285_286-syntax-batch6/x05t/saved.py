"""3回目 K1 の保存物を読み、変更した照合と負例だけを適用する。"""
from collections import Counter
import copy
import json
from pathlib import Path
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(ROOT/'scripts/check'))
import formal_interval as whole
from interval_artifacts import input_rows, comparison_evidence, no_information
sys.path.insert(0, str(ROOT/'formal/tests'))
import interval_source_compare as source
import test_interval_exchange as exchange

RUN = 'x05a-k1-run3-20261027'
OUTPUT = ROOT/'target/x05t-check'/('saved-'+sys.argv[1] if len(sys.argv) > 1 else 'saved')


def write(name, value):
    (HERE/name).write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n')


def prepare_input(material, manifest, observation):
    inp = copy.deepcopy(material)
    entries = source.correspondence(manifest)
    obs = source.unique([b for b in observation['bodies'] if b.get('kind') != 'whole'], 'definition')
    declarations = {s['declaration'] for s in inp['apiAt']}
    sites = {s['declaration']: s['name'] for s in inp['standards'] if s['declaration'] in declarations}
    def expected(name):
        return (source.expectation(obs[name], entries[name], sites) if name in obs else
                dict(notAnalyzed=source.unproduced(name, manifest['whole'])))
    for module in inp['modules']:
        for definition in module['definitions']:
            definition['expected'] = expected(definition['name'])
    inp['expectedBodies'] = [dict(definition=name, expected=expected(name))
                            for name in manifest['manifest'] if '%body:' in name and name in entries]
    inp['expected'] = dict(after=dict(body=copy.deepcopy(exchange.ZERO['body']), whole=manifest['whole']['after']),
                          counts={k: manifest['counts'][k] for k in source.COUNT_FIELDS})
    return inp


def main():
    OUTPUT.mkdir(parents=True)
    roots = {name: ROOT/'target'/(name+'-diff')/RUN for name in ('interval', 'desugar', 'coverage')}
    original = whole.read(roots['interval']/'manifest.json')
    assert original['artifacts'] == whole.inventory(roots), 'original artifacts differ before audit'
    archive = ROOT/'work/m012/records/x05a-run3-k1-records.zip'
    archive_sha = whole.digest(archive)
    assert archive_sha == '6986e19acfa40abad5507cca1583c7240f417ee96504b58b4ddd4da0e8e4aa9e'
    whole.verify_inputs(roots)
    current = whole.counts(roots)
    assert {k: v for k, v in current.items() if k != 'sourceEvidence'} == original['counts']
    write('counts.json', current['sourceEvidence'])
    records = []
    old_text = subprocess.check_output(['git', 'show',
        'd3f7c3e5327b7e97c57d959c46ce62997bf9f009:formal/tests/interval_source_compare.py'], cwd=ROOT, text=True)
    old = dict(__file__=str(ROOT/'formal/tests/interval_source_compare.py'))
    exec(compile(old_text, '<B_WORK interval_source_compare>', 'exec'), old)
    legacy_probe = None
    for index, name in enumerate(whole.SOURCE_DIRS):
        directory = roots['interval']/name
        reports_dir = roots['interval']/'comparison'/('real-source-'+str(index))
        observations = input_rows(directory/'interval-observations.json')
        materials = input_rows(directory/'interval-material.json')
        totals, eligible, selected = Counter(), {}, []
        manifests, reports, chosen_observations, inputs = [], [], {}, []
        excluded_detail = []
        number = 0
        for manifest in input_rows(directory/'interval-manifest.json'):
            if manifest['checker'] != 'succeeded':
                continue
            observation, material = next(observations), next(materials)
            assert observation['name'] == material['name'] == manifest['input']
            report = whole.read(reports_dir/('source-analysis-'+str(number)+'.report.json'))
            lean = report['inputs'][0]
            entries = source.correspondence(manifest)
            obs = source.unique([b for b in observation['bodies'] if b.get('kind') != 'whole'], 'definition')
            source.exclusions(manifest, observation)
            source.compare_structure(lean, manifest, obs, entries)
            warnings = source.compare_warnings(lean, observation, manifest, entries)
            totals['legacyIdentities'] += len(manifest['whole']['legacyWarnings']['identities'])
            totals['legacyDiagnostics'] += len(manifest['whole']['legacyWarnings']['diagnostics'])
            totals.update(comparison_evidence(manifest, report, observation))
            # 全入力を調べ、負例の形がない系統の免除を確認する。
            shapes = set()
            roots_in_input = {d['name'] for m in material['modules'] for d in m['definitions']}
            if not manifest.get('excluded'):
                for body in lean['bodies']:
                    if body['definition'] not in roots_in_input:
                        continue
                    shapes.update(['integer', 'after', 'context', 'next'])
                    if body['actual']['warnings']:
                        shapes.add('warnings')
                    if any(c['warnings'] for c in body['actual']['independent']):
                        shapes.add('independent')
            if warnings:
                shapes.add('userWarnings')
            if any(p['phase'] == 'discovery' for p in lean['phaseStops']):
                shapes.add('phasePosition')
            if manifest.get('excluded'):
                shapes.update(whole.NEGATIVE_EXTERNAL)
                for exclusion in manifest['excluded']:
                    for body_name in exclusion['bodies']:
                        body = obs[body_name]
                        value = body['value']
                        bottom = (value is not None and value['integer'] == 'bottom' and
                                  all(v == 'bottom' for v in value['widths'].values()) and
                                  value['boolean'] == [False, False] and not value['nonIntegerOther'])
                        children = body['independent']
                        closed = sum(not no_information(c['value']) for c in children)
                        excluded_detail.append(dict(input=manifest['input'], definition=body_name,
                            bottom=bottom, independentInputs=len(children), informativeIndependentInputs=closed,
                            parentCandidates=len(body['candidates']),
                            independentCandidates=sum(len(c['candidates']) for c in children)))
            reasons = sorted(shapes-set(eligible))
            for shape in shapes:
                eligible.setdefault(shape, dict(input=manifest['input'], number=number))
            if reasons:
                selected.append(dict(input=manifest['input'], number=number, reasons=reasons))
                manifests.append(manifest)
                reports.append(report)
                chosen_observations[manifest['input']] = observation
                inputs.append(prepare_input(material, manifest, observation))
            # 診断のない旧採用済みの組により、新候補が両側から消える退行を再現する。
            if legacy_probe is None:
                wanted = source.warning_projection(lean, entries)
                seen = {(w['node'], w['cause'], tuple(w['primary']))
                        for w in manifest['whole']['legacyWarnings']['identities']}
                fresh = [(identity, diagnostic) for identity, diagnostic in wanted.items() if identity not in seen]
                if fresh:
                    (node, cause, primary), (code, _) = fresh[0]
                    changed_m, changed_o = copy.deepcopy(manifest), copy.deepcopy(observation)
                    changed_m['whole']['legacyWarnings']['identities'].append(
                        dict(node=node, cause=cause, primary=list(primary)))
                    removed = False
                    for n, warning in enumerate(changed_o['warnings']):
                        if warning['code'] == 'Some('+code+')' and tuple(warning['primary']) == primary:
                            del changed_o['warnings'][n]
                            removed = True
                            break
                    assert removed
                    old['compare_warnings'](lean, changed_o, changed_m, entries)
                    try:
                        source.compare_warnings(lean, changed_o, changed_m, entries)
                    except AssertionError as error:
                        assert 'legacy warning identity without diagnostic' in str(error)
                    else:
                        raise AssertionError('phantom legacy identity accepted')
                    legacy_probe = dict(input=manifest['input'], node=node, cause=cause, primary=primary,
                        before='accepted', after='legacy warning identity without diagnostic')
            number += 1
        assert next(observations, None) is None and next(materials, None) is None
        assert whole.NEGATIVE_ALL-set(eligible) == whole.NEGATIVE_ABSENT[name], (name, eligible)
        output = OUTPUT/str(index)
        output.mkdir()
        runner = exchange.Runner(output, ROOT/'formal/.lake/build/bin/intervalDiff')
        # 除外のある入力を先頭に置き、直接 invoke する負例の選択から外れることも確認する。
        inputs.sort(key=lambda inp: not any(m['input'] == inp['name'] and m.get('excluded') for m in manifests))
        corpus = dict(kind='interval-corpus', version=1, surfaceVersion=14, traversalVersion=1,
                      profile='domain', inputs=inputs)
        cases = source.negative_cases(runner, corpus, reports, manifests, chosen_observations)
        assert set(cases) == whole.NEGATIVE_ALL-whole.NEGATIVE_ABSENT[name]
        records.append(dict(directory=name, inputs=number, totals=dict(totals), eligible=eligible,
            absent=sorted(whole.NEGATIVE_ABSENT[name]), selected=selected, negativeCases=cases,
            calls=runner.calls, excluded=excluded_detail))
        print(name+': saved warnings, evidence, shapes and negatives agree', flush=True)
    write('saved-details.json', dict(sources=records, legacyProbe=legacy_probe,
                                    originalArchiveSha256=archive_sha))
    assert whole.inventory(roots) == original['artifacts'], 'original artifacts changed'
    assert whole.digest(archive) == archive_sha, 'original archive changed'
    write('original-preserved.json', dict(artifacts=len(original['artifacts']), archiveSha256=archive_sha,
                                         beforeAndAfterEqual=True))


if __name__ == '__main__':
    main()
