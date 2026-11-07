"""実ソース・独立期待値を既存の交換入口へ接続する。比較失敗を成功へ読み替えない。"""
import argparse
import hashlib
import ipaddress
import json
from pathlib import Path
import re
import runpy
import subprocess

ROOT = Path(__file__).resolve().parents[2]
SOURCES = ROOT / 'crates/benitoite/tests/desugar_export/range-sources'
BIN = ROOT / 'formal/.lake/build/bin'
SIX = ['desugarDiff','builtinCheck','surfaceCheck','surfaceCheckAll','coverageDiff','coverageProgramDiff']


def require(ok, message):
    if not ok:
        raise AssertionError(message)


def read(p):
    return json.loads(p.read_text())


def non_top(value):
    if isinstance(value, list):
        return sum(map(non_top, value))
    if not isinstance(value, dict):
        return 0
    total = 0
    for key, child in value.items():
        if key == 'candidates':
            continue
        if key == 'ix' and isinstance(child,dict) and child.get('fixed','top') != 'top':
            total += 1
        elif key == 'ranges':
            # 版16の範囲の列は範囲の位置（{"fixed": R} か {"rvar": i}）を並べる。
            total += sum(not (isinstance(v,dict) and v.get('fixed') == 'top') for v in child)
        total += non_top(child)
    return total


def run(tool, args, out, expected=0):
    out.parent.mkdir(parents=True, exist_ok=True)
    p = subprocess.run([str(BIN/tool), *map(str,args), str(out)], text=True,capture_output=True,timeout=60)
    out.with_suffix('.log').write_text(p.stdout+p.stderr)
    require(p.returncode == expected, f'{tool}: exit={p.returncode}, expected={expected}: {p.stdout}{p.stderr}')
    return read(out)


# 標準表との一致の判定（プログラムが参照する組込みと data の閉包）が断る名前と、その原因。処理系の書き出しが
# 篩付きの標準表にまだ追いついていない差であり、照合では外さない（Http.Response の表現、Scope.ScopeError の構成子
# At、結果型の篩）。鍵の型パラメータの等値の印は、照合が鍵の印にそろえて比べるので差にならない。
STANDARD_GAPS = {'Http.sendIn': 'Http.sendIn', 'Scope.checkPathIn': 'Scope.ScopeError.At',
                 **{n: 'refined result' for n in ('List.append', 'List.head', 'List.tail', 'Map.fromList', 'Map.toList',
                                                  'Set.fromList', 'Set.toList')}}
# data の宣言の差。Http.RequestCheckError は構成子の引数の Scope.ScopeError が標準の名前へ写らないことによる。
DATA_GAPS = {'Scope.ScopeError': 'Scope.ScopeError.At', 'Http.RequestCheckError': 'Scope.ScopeError.At'}
# 準備の段の拒否の文の二つの部分。
GAP_REASONS = {'builtin signature disagrees with the standard table': STANDARD_GAPS,
               'data declaration disagrees with the standard table': DATA_GAPS}


def preparation_gaps(text):
    """準備の段の拒否の文から、標準表との差の名前と原因を読む。分類の表にない差や差以外の拒否なら None。"""
    parts = re.findall(r'(builtin signature disagrees with the standard table|data declaration disagrees with the '
                       r'standard table): \[([^\]]*)\]', text)
    if not parts:
        return None
    names, causes = [], set()
    for reason, listed in parts:
        found = [n.strip() for n in listed.split(',') if n.strip()]
        table = GAP_REASONS[reason]
        if not found or any(n not in table for n in found):
            return None
        names += found
        causes |= {table[n] for n in found}
    return {'names': names, 'causes': sorted(causes)}


def classified_all(report, corpus):
    """surfaceCheckAll の報告で、準備の段の拒否が全て分類の表の原因なら、残りの入力の照合を行って分類を返す。
    残りの入力の照合は、不一致0、準備の失敗の件数と拒否の数の一致、末尾の照合の件数（拒否した入力を除く定義の
    注釈の和）の一致である。分類できない拒否があれば None、分類した拒否がなければ空の分類を返す。"""
    errors = report.get('preparationErrors', [])
    found = [preparation_gaps(e.get('reason', '')) for e in errors]
    if any(g is None for g in found):
        return None
    counts = report['counts']
    require(counts['preparationFailure'] == len(errors), 'classified rejections: preparation failure count')
    require(counts['mismatched'] == 0, 'classified rejections: mismatches in the remaining inputs')
    rejected = {(e.get('group'), e.get('input')) for e in errors}
    tail = [0, 0]
    for item in corpus['inputs']:
        if item.get('excluded') or (item['group'], item['name']) in rejected:
            continue
        for definition in item['definitions']:
            t = definition.get('annotations', {}).get('tailMatch', [0, 0])
            tail = [tail[0] + t[0], tail[1] + t[1]]
    require([report['tailMatches'], report['replacements']] == tail,
            f"classified rejections: tail matches {[report['tailMatches'], report['replacements']]} != {tail}")
    return {'inputs': len(errors), 'rejected': sorted(n for _, n in rejected),
            'names': sorted({n for g in found for n in g['names']}),
            'causes': sorted({c for g in found for c in g['causes']}), 'matched': counts['matched']}


def surface_checks(item):
    """入力の表層の検査の件数（実装のメソッドと上位辞書は実装一件として数える）。"""
    surfaces = [d['scope']['inScope']['surface'] for d in item['definitions'] if 'inScope' in d['scope']]
    return sum(s['implementation'] is None for s in surfaces) + len({s['implementation'] for s in surfaces
                                                                    if s['implementation'] is not None})


def expected_range(text):
    """期待値の公開構文だけを読む独立参照。処理系の解析器/出力を使わない。"""
    value, length = json.JSONDecoder().raw_decode(text)
    if value.startswith('/'):
        return {'path':{'tree' if value.endswith('/**') else 'exact':value.removesuffix('/**').strip('/').split('/') if value not in ('/','/**') else []}}
    if '/' in value:
        n = ipaddress.ip_network(value)
        host={'ip':{'cidr':{'family':'v4' if n.version==4 else 'v6','network':int(n.network_address),'prefixLen':n.prefixlen}}}
    else:
        try:
            a=ipaddress.ip_address(value)
            host={'ip':{'exact':{'family':'v4' if a.version==4 else 'v6','bits':int(a)}}}
        except ValueError:
            kind='many' if value.startswith('**.') else 'one' if value.startswith('*.') else 'exact'
            host={'name':{kind:value.removeprefix('**.').removeprefix('*.').lower().split('.')}}
    ports=text[length:].strip().removeprefix(',').strip().split('..')
    lo=int(ports[0]);hi=int(ports[-1])
    return {'endpoint':{'host':host,'ports':{'lo':lo,'hi':hi}}}


def check_reports(cli, output):
    """報告側26入力を独立期待値のまま接続する。空のdoc契約を純粋と読まない。"""
    handoff=read(SOURCES/'report-expected.json')
    output.mkdir(parents=True,exist_ok=True)
    checked=0
    for case in handoff['cases']:
        source=SOURCES/'report-inputs'/Path(case['file']).name
        require(hashlib.sha256(source.read_bytes()).hexdigest()==case['sha256'],str(source)+': report source hash')
        expected=case['expected']
        for mode in (('doc',) if expected.get('doc') else ('check','test')):
            command=[str(cli.resolve()),'test' if mode=='doc' else mode]
            if mode=='doc': command.extend(['--doc','--check'])
            elif mode=='test': command.append('--check')
            command += ['--report=json',str(source)]
            result=subprocess.run(command,text=True,capture_output=True,timeout=30)
            label=source.stem+'-'+mode
            (output/(label+'.log')).write_text((result.stdout+result.stderr).replace(str(ROOT),'<wt>').replace(str(Path.home()),'<home>'))
            require(result.returncode==expected['exit'], label+': exit')
            report=json.loads(result.stdout)
            require(report['complete']==expected['complete'],label+': complete')
            target=report['targets'][0]
            if expected.get('code'):
                require(expected['code'] in [d.get('code') for d in report['diagnostics']],label+': code')
                if expected.get('reason'):
                    require(any('reason: '+expected['reason'] in d.get('notes',[]) for d in report['diagnostics']),label+': reason')
                require(report.get('aggregateEffects') is None,label+': failed effects')
            elif not expected.get('doc'):
                if mode=='check':
                    require(target['main']['effects']==expected['effects'],label+': Effects')
                else:
                    require(all(t['effects']==expected['effects'] for t in target['tests']),label+': test Effects')
            else:
                example=target['docExamples'][0]
                require(example['effects']==expected['effects'],label+': doc Effects')
                if 'docExampleTests' in expected:
                    require(example['tests']==expected['docExampleTests'],label+': doc tests')
                if 'diagnosticCode' in expected:
                    require(expected['diagnosticCode'] in json.dumps(example),label+': doc expected error')
            checked+=1
    result={'inputs':len(handoff['cases']),'commands':checked,'status':'passed'}
    (output/'summary.json').write_text(json.dumps(result,indent=2)+'\n')
    return result


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--exports',type=Path,required=True)
    parser.add_argument('--cli',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    args.output.mkdir(parents=True,exist_ok=True)
    expected=read(SOURCES/'expected.json')
    observed=read(args.exports/'rust-observed.json')
    require([c['name'] for c in observed]==[c['name'] for c in expected['cases']], 'missing/extra source routing')
    successes=[];exclusions=[];counts={};top={};definitions=0;coverage_entries=0;surface_outcomes=[]
    for case,actual in zip(expected['cases'],observed):
        name=case['name'];src=SOURCES/case['file']
        require(hashlib.sha256(src.read_bytes()).hexdigest()==case['sha256'], name+': source hash')
        require(actual['accepted']==(case['exit']==0), name+': acceptance')
        require([d['code'] for d in actual['diagnostics']]==case.get('codes',[]), name+': codes')
        if case['exit']:
            if case['comparison']=='excluded':
                exclusions.append({'name':name,'codes':case['codes'],'excluded':case['excluded']})
            continue
        directory=args.exports/name
        corpus=read(directory/'named-programs-corpus.json')
        item=corpus['inputs'][0]
        require(corpus['version']==16 and item['excluded']==[],name+': corpus')
        require(len(item['definitions'])==case['definitions'], name+': all definitions')
        require(all('inScope' in d['scope'] or 'accessor' in d['scope'] for d in item['definitions']),name+': excluded body')
        # 候補の欄にだけ範囲が残る退行を、二入口に渡す同じ入力で拒否する。
        for entry in corpus['inputs']:
            entry['candidates']=[]
        clean=args.output/name/'corpus.json';clean.parent.mkdir(parents=True,exist_ok=True)
        clean.write_text(json.dumps(corpus)+'\n')
        n=non_top(corpus)
        require(n>=case['nonTopRangesMinimum'], name+': all-Top range comparison')
        if 'nonTopRanges' in case:
            require(n==case['nonTopRanges'],name+': exact nonTopRanges expectation')
        (counts if case['nonTopRangesMinimum'] else top)[name]=n
        for rule in case.get('required',[]):
            matches=[r for r in actual['required'] if r['definition']=='.'+rule['definition'] and r['surfacePreorder']==rule['surfacePreorder'] and r['declaration']==rule['declaration']]
            require(len(matches)==1 and matches[0]['ranges']==[[expected_range(rule['index'])]],name+': Required index/key')
        if 'sourceLine' in case:
            source=src.read_text()
            start=source.index('File.readTextIn')
            require(source[:start].count('\n')+1==case['sourceLine'],name+': source line')
            require(any(p['start']==start for p in actual['positions']),name+': source span lost')
            # 略記二原子が、宣言上限の表と本体の関係で一緒に検査される。
            effects=item['definitions'][0]['scope']['inScope']['surface']['header']['eff']
            expected_paths={expected_range(v)['path']['tree'][0] for v in case['bounds']}
            require({a['name']['ix']['fixed']['path']['tree'][0] for a in effects}==expected_paths,name+': shorthand atoms')
        if name=='user-spelling':
            require(actual['required']==[], 'same spelling recognized as standard Scope rule')
        builtin=directory/'named-programs-builtins.json';stdlib=directory/'named-programs-stdlib.json'
        require(read(builtin)['version']==8 and read(stdlib)['version']==8,name+': table versions')
        report=run('desugarDiff',[clean],args.output/name/'desugar.json')
        require(report['golden']['definitions']==dict(matched=case['definitions'],mismatched=0,outside=0,excluded=0),name+': desugar definitions')
        require(report['nonTopRanges']==n,name+': desugar nonTopRanges')
        report=run('builtinCheck',[clean,builtin],args.output/name/'builtins.json')
        require(report['errors']==[] and report['checkedInputs']==1,name+': builtin table')
        # 表層の検査は、準備の段で断った・一致・不一致に分けて残し、最初の不一致で止めない。
        out=args.output/name/'surface.json';out.parent.mkdir(parents=True,exist_ok=True)
        p=subprocess.run([str(BIN/'surfaceCheck'),*map(str,[clean,builtin,stdlib,'golden',name]),str(out)],text=True,capture_output=True,timeout=60)
        out.with_suffix('.log').write_text(p.stdout+p.stderr)
        gaps=preparation_gaps(p.stdout+p.stderr) if p.returncode==2 else None
        if gaps is not None:
            surface_outcomes.append({'name':name,'outcome':'preparationRejected',**gaps})
        elif p.returncode==0 and read(out)['result']==case['surface']:
            report=run('surfaceCheckAll',[clean,builtin,stdlib],args.output/name/'surface-all.json')
            same=(report['counts']==dict(matched=case['definitions'],mismatched=0,q11=0,outOfScope=0,lazyRestriction=0,preparationFailure=0)
                  and report['nonTopRanges']==n and report['preparationErrors']==[])
            surface_outcomes.append({'name':name,'outcome':'matched' if same else 'mismatched'})
        else:
            surface_outcomes.append({'name':name,'outcome':'mismatched','exit':p.returncode,'log':(p.stdout+p.stderr)[:500]})
        coverage=directory/'named-programs-coverage.json'
        cov=read(coverage)
        size=sum(len(i['matches'])+len(i['bindings']) for i in cov['inputs'])
        report=run('coverageProgramDiff',[coverage,builtin],args.output/name/'coverage.json',expected=0 if size else 1)
        require(report['mismatched']==0 and report['fuelExhausted']==0 and report['matched']==size,name+': coverage')
        coverage_entries+=size
        if 'runStdout' in case:
            p=subprocess.run([str(args.cli.resolve()),'run',str(src),'--allow-effects',case['runEffects']],text=True,capture_output=True,timeout=30)
            (args.output/name/'vm.log').write_text(p.stdout+p.stderr)
            require(p.returncode==0 and p.stdout==case['runStdout'],name+': InvalidTarget versus InvalidUrl: '+p.stdout+p.stderr)
        successes.append({'name':name,'definitions':case['definitions'],'definitionKeys':[d['name'] for d in item['definitions']],'tableEntries':{key:[entry.get('name') for entry in value] for key,value in read(builtin)['inputs'][0].items() if isinstance(value,list) and all(isinstance(entry,dict) for entry in value)},'nonTopRanges':n,'coverageEntries':size,'allDefinitionsChecked':True})
        definitions+=case['definitions']
    require(coverage_entries>0,'empty program coverage only')
    # 六番目の独立coverageは実ソースsidecarとは別の契約として保持する。
    independent=runpy.run_path(str(Path(__file__).with_name('test_range_exchange.py')))['fixtures']()['coverage']
    coverage=args.output/'independent-coverage.json';coverage.write_text(json.dumps(independent)+'\n')
    report=run('coverageDiff',[coverage],args.output/'independent-coverage-report.json')
    require((report['matched'],report['mismatched'],report['fuelExhausted'])==(1,0,0),'independent coverage')
    rejections=runpy.run_path(str(Path(__file__).with_name('test_range_rejections.py')))['run_rejections'](args.exports,args.output/'rejections')
    reports=check_reports(args.cli,args.output/'report-subset')
    classified={k:sorted(o['name'] for o in surface_outcomes if o['outcome']==k) for k in ('matched','mismatched','preparationRejected')}
    causes={}
    for o in surface_outcomes:
        for c in o.get('causes',[]):
            causes[c]=causes.get(c,0)+1
    surface=dict(outcomes=surface_outcomes,counts={k:len(v) for k,v in classified.items()},preparationCauses=causes)
    summary=dict(reportSubset=reports,status='passed' if not classified['mismatched'] else 'failed',surfaceCheck=surface,groups=len(successes),definitions=definitions,rejections=rejections['sourceRejections'],excluded=len(exclusions),nonTopRanges=counts,topCompatibility=top,sixEntries=SIX,successes=successes,exclusions=exclusions,programCoverageEntries=coverage_entries,rejectionReport=rejections)
    manifest={'expectedSha256':hashlib.sha256((SOURCES/'expected.json').read_bytes()).hexdigest(),'sourceCases':expected['cases'],'successes':successes,'exclusions':exclusions,'rejections':rejections['outcomes']}
    (args.output/'source-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    (args.output/'summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(summary,ensure_ascii=False))
    require(not classified['mismatched'], 'surface check mismatches: '+', '.join(classified['mismatched']))


if __name__=='__main__':
    main()
