"""保存済み出力で不足する負例の前提だけを、小さい部分集合で実行する。"""
import gzip
import json
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(HERE))
import audit_saved as audit
sys.path.insert(0, str(ROOT/'formal/tests'))
import interval_source_compare as source
import test_interval_exchange as exchange


def main():
    saved = json.loads((HERE/'saved-audit-details.json').read_text())
    output = ROOT/'target/x05s-records/probes'
    output.mkdir(parents=True)
    executable = ROOT/'formal/.lake/build/bin/intervalDiff'
    result = dict(sources=[], savedNegatives=None)
    # 全件を再解析せず、保存済みの正の報告を使って選ばれた負例だけを起動する。
    record = saved['sources'][0]
    indices = {s['index'] for s in record['selected']}
    old_output = ROOT/'target/interval-diff'/audit.RUN/'comparison/real-source-0'
    reports, manifests, observations, corpus_inputs = [], [], {}, []
    directory = ROOT/record['directory']
    obs = audit.inputs(directory/'interval-observations.json')
    index = 0
    for manifest in audit.inputs(directory/'interval-manifest.json'):
        if manifest['checker'] != 'succeeded':
            continue
        observation = next(obs)
        if index in indices:
            manifests.append(manifest)
            observations[manifest['input']] = observation
            reports.append(json.loads((old_output/('source-analysis-'+str(index)+'.report.json')).read_text()))
            path = old_output/('source-analysis-'+str(index)+'.json.gz')
            if path.exists():
                with gzip.open(path, 'rt') as stream:
                    corpus = json.load(stream)
                corpus_inputs.extend(corpus['inputs'])
        index += 1
    corpus['inputs'] = corpus_inputs
    negative_output = output/'saved-negatives'
    negative_output.mkdir()
    runner = exchange.Runner(negative_output, executable)
    cases = source.negative_cases(runner, corpus, reports, manifests, observations)
    assert set(cases) == {'integer', 'after', 'context', 'next', 'warnings', 'independent', 'userWarnings',
                          'externalType-candidates', 'externalType-integer', 'externalType-width', 'externalType-independent'}
    result['savedNegatives'] = dict(cases=cases, calls=runner.calls,
                                    inputs=[m['input'] for m in manifests])
    # 残る9系統は、各負例の最初の対象と全Top拒否を満たす最小限の実入力を選ぶ。
    for number, record in enumerate(saved['sources'][2:]):
        directory = ROOT/record['directory']
        selected = {s['input'] for s in record['selected']}
        manifest = source.read(directory/'interval-manifest.json')
        informative = next(m['input'] for m in manifest['inputs']
                           if m['checker'] == 'succeeded' and int(m['counts']['informativeBodies']) > 0)
        selected.add(informative)
        selected.update(m['input'] for m in manifest['inputs']
                        if m['checker'] == 'succeeded' and m['name'] == 'nonintegerMatch')
        subset = output/('source-'+str(number))
        subset.mkdir()
        chosen = []
        for filename, key in [('interval-manifest.json', 'input'), ('interval-material.json', 'name'),
                              ('interval-observations.json', 'name')]:
            doc = source.read(directory/filename)
            doc['inputs'] = [i for i in doc['inputs'] if i.get(key) in selected]
            (subset/filename).write_text(json.dumps(doc, ensure_ascii=False, separators=(',', ':'))+'\n')
            if key == 'input':
                chosen = [i['input'] for i in doc['inputs']]
        comparison = subset/'comparison'
        comparison.mkdir()
        runner = exchange.Runner(comparison, executable)
        summary = source.exercise(runner, subset)
        result['sources'].append(dict(directory=record['directory'], selected=chosen, calls=runner.calls, **summary))
        print(json.dumps(dict(directory=record['directory'], cases=summary['negativeCases'],
                              compared=summary['comparedBodies']), ensure_ascii=False), flush=True)
    # 五profileの固定例・負例は小さい独立入力であり、全件Rust比較は起動しない。
    profiles = output/'profiles'
    profiles.mkdir()
    exchange.exercise(profiles, executable)
    result['profiles'] = source.read(profiles/'profile-manifest.json')
    result['fuel'] = source.read(profiles/'fuel-selection.json')
    (HERE/'probe-details.json').write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n')


if __name__ == '__main__':
    main()
