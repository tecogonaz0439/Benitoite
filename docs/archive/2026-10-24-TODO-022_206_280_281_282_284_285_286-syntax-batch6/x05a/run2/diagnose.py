"""保存済み出力だけで負例の選択と理由付き除外を調べる。Lean は起動しない。"""
import copy
import json
from pathlib import Path
import re
import runpy
import sys
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
redact = runpy.run_path(str(HERE/'run.py'))['redact']
inputs = runpy.run_path(str(HERE.parent/'diagnose.py'))['inputs']
sys.path.insert(0,str(ROOT/'formal/tests'))
import interval_source_compare as compare


def main():
    source = ROOT/'target/desugar-diff/x05a-k1-run2-20261027/named-programs-interval'
    output = ROOT/'target/interval-diff/x05a-k1-run2-20261027/comparison/real-source-0'
    reports = {}
    totals = dict(reports=0,comparedBodies=0,informativeBodies=0,depthExcluded=0,phaseDepth=0)
    for p in sorted(output.glob('source-analysis-*.report.json')):
        if not re.fullmatch(r'source-analysis-[0-9]+\.report\.json',p.name): continue
        report = json.loads(p.read_text())
        assert report['matched']
        for a,b in [('comparedBodies','comparedCount'),('informativeBodies','informativeCount'),('depthExcluded','excludedCount'),('phaseDepth','phaseDepthCount')]:
            totals[a]+=int(report[b])
        totals['reports']+=1
        reports[report['inputs'][0]['name']]=p
    observed,first = {}, None
    relevant_codes = {'Some(W0401)','Some(W0402)','Some(W0404)'}
    for row in inputs(source/'interval-observations.json'):
        if first is None and row['warnings']:
            first=row['name']; observed[first]=row
        if any(w['code'] in relevant_codes for w in row['warnings']) and 'relevant' not in observed:
            observed['relevant']=row
        if first and 'relevant' in observed: break
    selected = {first:observed[first],observed['relevant']['name']:observed['relevant']}
    excluded = {}
    source_totals = {}
    for m in inputs(source/'interval-manifest.json'):
        for key,value in m['counts'].items(): source_totals[key]=source_totals.get(key,0)+int(value)
        if m.get('excluded'): excluded[m['input']]=m
        if m.get('input') in selected: selected[m['input']]=dict(observation=selected[m['input']],manifest=m)
    trials=[]
    for name,record in selected.items():
        report=json.loads(reports[name].read_text()); lean=report['inputs'][0]
        original=record['observation']; manifest=record['manifest']; entries=compare.correspondence(manifest)
        actual=compare.compare_warnings(lean,original,manifest,entries)
        changed=copy.deepcopy(original); changed['warnings']=[]
        rejection=None
        try: altered=compare.compare_warnings(lean,changed,manifest,entries)
        except AssertionError as error: rejection=str(error); altered=None
        trials.append(dict(input=name,report=reports[name].relative_to(ROOT).as_posix(),
            warnings=original['warnings'],targetWarnings=actual,emptyWarningsResult=altered,
            rejected=rejection is not None,rejection=rejection,selectedByOriginalNegative=name==first,
            manifest=manifest,observation=original))
    excluded_checks=[]
    for row in inputs(source/'interval-observations.json'):
        if row['name'] not in excluded: continue
        manifest=excluded[row['name']]
        confirmed=compare.exclusions(manifest,row)
        names={b for e in confirmed for b in e['bodies']}
        bodies=[b for b in row['bodies'] if b['definition'] in names]
        report=json.loads(reports[row['name']].read_text())
        assert report['inputs'][0]['excluded']==confirmed
        assert int(report['excludedDefinitions'])==len(confirmed)
        assert int(report['excludedBodies'])==len(names)
        excluded_checks.append(dict(input=row['name'],excluded=confirmed,
            report=reports[row['name']].relative_to(ROOT).as_posix(),bodies=bodies,
            parentCandidates=sum(len(b['candidates']) for b in bodies),
            informativeIntervals=sum(not compare.exclusions.__globals__['no_information'](b['value']) for b in bodies),
            independentCandidates=sum(len(c['candidates']) for b in bodies for c in b['independent']),
            observationAndDiscoveryVerified=True,manifestAndReportAgree=True))
    result=dict(firstSelectedInput=first,trials=trials,excluded=excluded_checks,
                comparedSource=totals,sourceCounts=source_totals)
    (HERE/'diagnosis-details.json').write_text(redact(json.dumps(result,ensure_ascii=False,indent=2))+'\n')
    print(json.dumps(dict(firstSelectedInput=first,trials=[dict(input=t['input'],codes=[w['code'] for w in t['warnings']],targetWarnings=t['targetWarnings'],rejected=t['rejected']) for t in trials],
        excludedInputs=len(excluded_checks),excludedDefinitions=sum(len(c['excluded']) for c in excluded_checks),
        excludedBodies=sum(len(c['bodies']) for c in excluded_checks),comparedSource=totals),ensure_ascii=False))

if __name__ == '__main__': main()
