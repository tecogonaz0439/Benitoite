"""六入口と独立評価の報告から件数と除外理由を保存する。"""
from collections import Counter
import json
from pathlib import Path
import runpy

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]


def compact(value):
    if isinstance(value, list):
        return dict(length=len(value))
    if isinstance(value, dict):
        return {key: compact(child) for key, child in value.items()}
    return value


def main():
    output = ROOT/'target/desugar-diff/x05a-k1-run3-20261027'
    legacy = {path.relative_to(output).as_posix(): compact(json.loads(path.read_text()))
              for path in sorted(output.glob('*report.json'))}
    for name in ('coverage/report.json', 'surface-check/report.json'):
        legacy[name] = compact(json.loads((output/name).read_text()))
    comparison = ROOT/'target/interval-diff/x05a-k1-run3-20261027/comparison'
    evaluated = {}
    for profile in ('base', 'flow', 'width', 'range', 'domain'):
        report = json.loads((comparison/(profile+'-eval.report.json')).read_text())
        reasons, excluded = Counter(), []
        for inp in report['inputs']:
            for body in inp['bodies']:
                if body['comparisonEligible']:
                    continue
                reason = body['actual']['excluded']
                reasons[reason] += 1
                excluded.append(dict(input=inp['name'], definition=body['definition'], reason=reason))
            for body in inp['embeddedExcluded']:
                reasons[body['reason']] += 1
                excluded.append(dict(input=inp['name'], **body))
        assert sum(reasons.values()) == int(report['excludedCount'])
        evaluated[profile] = dict(compared=report['comparedCount'], excluded=report['excludedCount'],
                                  reasons=dict(reasons), definitions=excluded)
    redact = runpy.run_path(str(HERE/'run.py'))['redact']
    value = dict(legacy=legacy, independentEvaluation=evaluated)
    (HERE/'legacy-and-eval-summary.json').write_text(redact(json.dumps(value, ensure_ascii=False, indent=2))+'\n')
    print(json.dumps(dict(legacyReports=len(legacy), evaluation={k:{a:b for a,b in v.items() if a!='definitions'} for k,v in evaluated.items()})))


if __name__ == '__main__':
    main()
