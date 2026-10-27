"""全体上限の未着手・embedded停止・複数モジュールを小さい部分集合で確かめる。"""
import json
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(ROOT/'formal/tests'))
import interval_source_compare as source
import test_interval_exchange as exchange


def main():
    directory = ROOT/'target/interval-diff/x05a-k1-run2-20261027/manifest/manifest-interval'
    output = ROOT/'target/x05s-records/stops'
    output.mkdir()
    selected = {'manifest:empty', 'manifest:otherTop', 'manifest:modules',
                'interval-budget:wholeBudget', 'golden:testdata/warnings/local-width-intervals.bnt'}
    for filename, key in [('interval-manifest.json', 'input'), ('interval-material.json', 'name'),
                          ('interval-observations.json', 'name'), ('interval-manifest-corpus.json', 'name')]:
        doc = source.read(directory/filename)
        doc['inputs'] = [i for i in doc['inputs'] if i.get(key) in selected]
        assert len(doc['inputs']) == len(selected)
        (output/filename).write_text(json.dumps(doc, ensure_ascii=False, separators=(',', ':'))+'\n')
    comparison = output/'comparison'
    comparison.mkdir()
    runner = exchange.Runner(comparison, ROOT/'formal/.lake/build/bin/intervalDiff')
    result = source.exercise(runner, output)
    assert {p['phase'] for p in result['phaseStops']} == {'whole', 'discovery', 'queue', 'embedded'}
    assert len(result['notStartedDefinitions']) == 6
    assert len(result['unproducedBodies']) == 6
    (HERE/'stop-probe-details.json').write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n')
    print(json.dumps(dict(compared=result['comparedBodies'], phases=result['phaseStops'],
                         negativeCases=result['negativeCases']), ensure_ascii=False))


if __name__ == '__main__':
    main()
