"""生成済みの manifest・観測・報告だけで理由付き除外を照合する。"""
import json
from pathlib import Path
import runpy
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
sys.path.insert(0, str(ROOT/'scripts/check'))
from interval_artifacts import read, exclusions, no_information


def main():
    directory = ROOT/'target/interval-diff/x05a-k1-run3-20261027'
    source = directory/'programs'
    comparison = directory/'comparison/real-source-0'
    manifests = read(source/'interval-manifest.json')['inputs']
    selected = {m['input']: m for m in manifests if m.get('excluded')}
    observed = {o['name']: o for o in read(source/'interval-observations.json')['inputs']
                if o['name'] in selected}
    reports = {}
    for path in comparison.glob('source-analysis-*.report.json'):
        suffix = path.name.removeprefix('source-analysis-').removesuffix('.report.json')
        if not suffix.isdigit():
            continue
        report = read(path)
        name = report['inputs'][0]['name']
        if name in selected:
            reports[name] = report
    details = []
    for name, manifest in selected.items():
        observation, report = observed[name], reports[name]
        accepted = exclusions(manifest, observation)
        names = {b for e in accepted for b in e['bodies']}
        bodies = [b for b in observation['bodies'] if b['definition'] in names]
        assert report['matched'] and report['inputs'][0]['excluded'] == accepted
        assert int(report['excludedDefinitions']) == len(accepted)
        assert int(report['excludedBodies']) == len(names) == len(bodies)
        parent = sum(len(b['candidates']) for b in bodies)
        informative = sum(not no_information(b['value']) for b in bodies)
        independent = sum(len(c['candidates']) for b in bodies for c in b['independent'])
        assert parent == informative == independent == 0
        details.append(dict(input=name, excluded=accepted, bodies=bodies,
                            parentCandidates=parent, informativeIntervals=informative,
                            independentCandidates=independent, manifestAndReportAgree=True))
    result = dict(inputs=len(details), definitions=sum(len(d['excluded']) for d in details),
                  bodies=sum(len(d['bodies']) for d in details), details=details)
    assert result['inputs'] == 4 and result['definitions'] == 12 and result['bodies'] == 16
    # 他の9系統にも除外があれば、最終 manifest の各系統の報告に残っている。
    final = read(directory/'manifest-comparison.json')
    result['allSourceExclusions'] = [dict(directory=s['directory'], excluded=s['excluded'])
                                    for s in final['realSources']]
    totals = {}
    for manifest in manifests:
        for key, value in manifest['counts'].items():
            totals[key] = totals.get(key, 0)+int(value)
    result['sourceCounts'] = totals
    width = next(m for m in manifests if m['name'] == 'testdata/warnings/local-width-intervals.bnt')
    result['widthInput'] = dict(input=width['input'], counts=width['counts'],
                               enumerationComplete=width['enumerationComplete'])
    redact = runpy.run_path(str(HERE/'run.py'))['redact']
    (HERE/'exclusion-details.json').write_text(redact(json.dumps(result, ensure_ascii=False, indent=2))+'\n')
    print(json.dumps({k: v for k, v in result.items() if k != 'details'}, ensure_ascii=False))


if __name__ == '__main__':
    main()
