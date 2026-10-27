"""成功済みの局所報告を読み戻す。配列読者の修正後にLeanを再起動しない。"""
import json
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(ROOT/'formal/tests'))
import interval_source_compare as source


def main():
    target = ROOT/'target/x05s-records/probes'
    audit = json.loads((HERE/'saved-audit-details.json').read_text())
    cases = []
    for field in ['integer', 'after', 'context', 'next', 'warnings', 'independent']:
        report = source.read(target/'saved-negatives'/('source-mismatch-'+field+'.report.json'))
        assert not report['matched']
        bad = [b for b in report['inputs'][0]['bodies'] if b['mismatches']]
        assert len(bad) == 1 and bad[0]['mismatches'] == ['context' if field == 'next' else field]
        cases.append(field)
    reproduction = source.read(HERE/'reproduction.json')
    cases.extend(reproduction['correctedNegativeCases'])
    # 除外の改変はPython内で完了する。保存した実入力へ同じ負例を読み戻して適用する。
    manifests = source.read(target/'source-1/interval-manifest.json')['inputs']
    observations = source.unique(source.read(target/'source-1/interval-observations.json')['inputs'], 'name')
    excluded = source.negative_cases(None, dict(inputs=[]), [], manifests, observations)
    assert excluded == ['externalType-candidates', 'externalType-integer', 'externalType-width', 'externalType-independent']
    cases.extend(excluded)
    result = dict(savedNegatives=dict(cases=cases, leanCalls=6), sources=[])
    for number, row in enumerate(audit['sources'][2:]):
        summary = source.read(target/('source-'+str(number))/'comparison/source-analysis-summary.json')
        assert summary['rustLeanMatched'] and summary['depthExcluded'] == summary['phaseDepth'] == '0'
        result['sources'].append(dict(directory=row['directory'], **summary))
    result['profiles'] = source.read(target/'profiles/profile-manifest.json')
    result['fuel'] = source.read(target/'profiles/fuel-selection.json')
    (HERE/'probe-details.json').write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n')
    print('saved negative reports, nine source subsets and five profiles agree')


if __name__ == '__main__':
    main()
