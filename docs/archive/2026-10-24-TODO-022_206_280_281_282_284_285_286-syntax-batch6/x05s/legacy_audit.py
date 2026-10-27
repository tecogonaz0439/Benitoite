"""既存六入口の固定表・全件順序を読み、負例だけを小さい実入力で試す。"""
from collections import Counter
import json
from pathlib import Path
import runpy
import shutil
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(HERE))
import audit_saved as audit


def main():
    tools = runpy.run_path(str(ROOT/'crates/benitoite/tests/desugar_export/check_named.py'))
    manifest = tools['read'](tools['MANIFEST'])
    directory = ROOT/'target/desugar-diff'/audit.RUN
    coverage = ROOT/'target/coverage-diff'/audit.RUN
    tools['check_routing'](directory, manifest)
    tools['check_coverage_exports'](coverage, manifest['coverageExports'])
    expected = {(i['group'], i['name']): i for i in manifest['programs']}
    names, active, selected, definitions, surfaces = [], [], [], 0, 0
    wanted_suffixes = ['named_partials.bnt', 'named_methods.bnt', 'named_operations.bnt']
    for item in audit.inputs(directory/'named-programs-corpus.json'):
        key = item['group'], item['name']
        names.append(key)
        entry = expected[key]
        assert item['excluded'] == entry.get('excluded', [])
        if item['excluded']:
            assert not item['definitions']
            continue
        active.append(key)
        assert len(item['definitions']) == entry['definitions']
        scopes = Counter(next(iter(d['scope'])) for d in item['definitions'])
        assert dict(scopes) == entry.get('scopes', {'inScope': entry['definitions']})
        inputs = [d['scope']['inScope']['surface'] for d in item['definitions'] if 'inScope' in d['scope']]
        implementations = {s['implementation'] for s in inputs if s['implementation'] is not None}
        count = sum(s['implementation'] is None for s in inputs)+len(implementations)
        assert len(implementations) == entry.get('implementations', 0)
        assert count == entry.get('surfaceChecks', scopes.get('inScope', 0))
        definitions += len(item['definitions'])
        surfaces += count
        if any(item['name'].endswith(suffix) for suffix in wanted_suffixes):
            selected.append(item)
    assert len(names) == len(set(names)) == len(expected) and set(names) == set(expected)
    assert definitions == manifest['programReports']['definitions']
    assert surfaces == manifest['programReports']['surfaceChecks']
    assert sum(manifest['programReports']['surfaceCounts'].values()) == surfaces
    selected_keys = {(i['group'], i['name']) for i in selected}
    assert len(selected_keys) == 3
    tables = {}
    for filename in ['named-programs-builtins.json', 'named-programs-stdlib.json']:
        keys, chosen = [], []
        for row in audit.inputs(directory/filename):
            key = row['group'], row['name']
            keys.append(key)
            if key in selected_keys:
                chosen.append(row)
        assert keys == active, filename
        doc = dict(version=6, inputs=chosen)
        tables[directory/filename] = (doc, tools['keyed'](chosen))
    matches, covered = 0, []
    for row in audit.inputs(directory/'named-programs-coverage.json'):
        key = row['group'], row['name']
        covered.append(key)
        for kind, count in expected[key]['coverage'].items():
            assert len(row[kind]) == count
            matches += count
    assert covered == active and matches == manifest['programReports']['coverageEntries']
    independent = tools['read'](directory/'independent-program-corpus.json')
    assert not set(names) & {(i['group'], i['name']) for i in independent['inputs']}
    output = ROOT/'target/x05s-records/legacy-probe-v2'
    output.mkdir()
    # version/operatorsは配列の後ろにもある。全文からヘッダを保ち、
    # 部分集合の注釈の総数は残した各定義の記録を合計する。
    corpus = tools['read'](directory/'named-programs-corpus.json')
    corpus['inputs'] = selected
    annotations = {}
    for item in selected:
        for definition in item['definitions']:
            for kind, counts in definition['annotations'].items():
                total = annotations.setdefault(kind, [0, 0])
                for index, value in enumerate(counts):
                    total[index] += value
    corpus['annotations'] = annotations
    tools['check_special_rejections'](output, corpus, tables)
    tools['check_program_rejections'](output, corpus, tables)
    # 小さい固定入力の六つの呼出し契約・外部型viewの負例も本物の入口で検査する。
    for stem in ['named-calls', 'named-static-calls', 'extensible-package']:
        for path in directory.glob(stem+'-*.json'):
            shutil.copy2(path, output/path.name)
    ordinary = tools['read'](output/'named-calls-corpus.json')
    static = tools['read'](output/'named-static-calls-corpus.json')
    tools['check_rejections'](output,
        (ordinary, output/'named-calls-builtins.json', output/'named-calls-stdlib.json'),
        (static, output/'named-static-calls-builtins.json', output/'named-static-calls-stdlib.json'))
    tools['check_extensible_package'](output)
    result = dict(inputs=len(names), definitions=definitions, surfaceChecks=surfaces,
        coverageEntries=matches, inputOrderVerified=True, tablesOrderVerified=True,
        selected=[i['name'] for i in selected],
        negatives=dict(special=3, programHolePipe=6, namedCall=6, packageView=5),
        allSixEntriesCompared=False)
    (HERE/'legacy-audit-details.json').write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n')
    print(json.dumps(result, ensure_ascii=False))


if __name__ == '__main__':
    main()
