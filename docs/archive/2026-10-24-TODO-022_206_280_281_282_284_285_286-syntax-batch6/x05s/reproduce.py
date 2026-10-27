"""2回目の実交換で、修正前の停止と修正後の負例を比較する。Lean は起動しない。"""
import copy
import json
from pathlib import Path
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(ROOT/'formal/tests'))
import interval_source_compare as current


def main():
    details = json.loads((HERE.parent/'x05a/run2/diagnosis-details.json').read_text())
    reports, manifests, observations = [], [], {}
    for trial in details['trials']:
        report = json.loads((ROOT/trial['report']).read_text())
        reports.append(report)
        manifests.append(trial['manifest'])
        observations[trial['input']] = trial['observation']
    old_text = subprocess.check_output(['git', 'show',
        '51dc0fefe2fc7a75df915a19640afb436d051e9e:formal/tests/interval_source_compare.py'],
        cwd=ROOT, text=True)
    old = dict(__file__=str(ROOT/'formal/tests/interval_source_compare.py'))
    exec(compile(old_text, '<baseline-interval-source-compare>', 'exec'), old)
    empty = dict(inputs=[])
    try:
        old['negative_cases'](None, empty, reports, manifests, observations)
    except AssertionError as error:
        assert str(error) == 'missing user warning accepted', error
        baseline = str(error)
    else:
        raise AssertionError('baseline did not reproduce the reported failure')
    cases = current.negative_cases(None, empty, reports, manifests, observations)
    assert cases == ['userWarnings'], cases
    first, relevant = [observations[m['input']] for m in manifests]
    assert not current.compared_warnings(first)
    assert current.compared_warnings(relevant)
    trials = []
    # 実観測二つを並べた退行と、実診断を混在させた対照を同じ境界で検査する。
    for label, observation in [('irrelevantOnly', first), ('targetOnly', relevant),
                               ('mixed', dict(relevant, warnings=relevant['warnings']+first['warnings']))]:
        index = 0 if label == 'irrelevantOnly' else 1
        lean, manifest = reports[index]['inputs'][0], manifests[index]
        entries = current.correspondence(manifest)
        before = current.compare_warnings(lean, observation, manifest, entries)
        changed = copy.deepcopy(observation)
        changed['warnings'] = [w for w in changed['warnings'] if w['code'] not in current.WARNING_CODES]
        rejected = False
        try:
            current.compare_warnings(lean, changed, manifest, entries)
        except AssertionError as error:
            assert 'user warnings' in str(error)
            rejected = True
        assert rejected == bool(before)
        trials.append(dict(label=label, input=observation['name'], targetWarnings=before,
                           remainingCodes=[w['code'] for w in changed['warnings']], rejected=rejected))
    result = dict(baselineFailure=baseline, correctedNegativeCases=cases,
                  selected=manifests[1]['input'], skipped=manifests[0]['input'], trials=trials)
    (HERE/'reproduction.json').write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n')
    print(json.dumps(result, ensure_ascii=False))


if __name__ == '__main__':
    main()
