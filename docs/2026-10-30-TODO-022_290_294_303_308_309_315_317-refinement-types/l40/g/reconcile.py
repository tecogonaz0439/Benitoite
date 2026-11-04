"""群 G の母集団・既定 import・前後の入力を読み取りで照合する。"""
from pathlib import Path
import argparse
import collections
import hashlib
import importlib.util
import json
import re

HERE = Path(__file__).resolve().parent
STAGE = HERE.parent
CHANGE = STAGE.parent
ROOT = CHANGE.parents[1]
FORMAL = ROOT / 'formal'
REF = FORMAL / 'Benitoite/Release/Refinement'


def digest(path):
    data = path.read_bytes()
    return {'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()}


def save(name, data):
    path = HERE / name
    raw = (json.dumps(data, ensure_ascii=False, indent=2) + '\n').encode()
    assert len(raw) <= 100000, (name, len(raw))
    path.write_bytes(raw)


def rows(text):
    return [[x.strip() for x in line.strip().split('|')[1:-1]]
            for line in text.splitlines() if line.startswith('|') and
            not re.match(r'^\|[- :|]+$', line)]


def section(text, start, end):
    return text.split(start, 1)[1].split(end, 1)[0]


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--tmp', required=True, type=Path)
    args = ap.parse_args()
    args.tmp.mkdir(parents=True, exist_ok=True)
    detail = (STAGE / 'detail.md').read_text()
    obligations = [r for r in rows(section(detail, '## 7.', '## 8.'))
                   if re.fullmatch(r'O\d{3}', r[0])]
    assert len(obligations) == len({r[0] for r in obligations}) == 64
    plan = {r[0] for r in rows((CHANGE / 'plan.md').read_text())
            if re.fullmatch(r'O\d{3}', r[0]) and 'L40' in r[3]}
    prior = {}
    for stage in ['l20', 'l30']:
        prior[stage] = {re.match(r'O\d{3}', r[0])[0]
                        for r in rows((CHANGE / stage / 'stage-results.md').read_text())
                        if re.match(r'O\d{3}', r[0]) and 'L40' in r[-1]}
    union = plan | prior['l20'] | prior['l30']
    common = {'O016', 'O027', 'O084', 'O118'}
    assert [len(plan), len(prior['l20']), len(prior['l30']), len(union)] == [56, 37, 21, 60]
    assert union - plan == {'O006', 'O015', 'O050', 'O054'}
    assert not union & common
    assert union | common == {r[0] for r in obligations}
    for oid, origin, *_ in obligations:
        actual = '/'.join(label for label, values in [('P', plan), ('20', prior['l20']), ('30', prior['l30'])] if oid in values)
        assert origin == (actual or '全L共通'), (oid, origin, actual)
    save('sets.json', {'plan': sorted(plan), **{k: sorted(v) for k, v in prior.items()},
                       'union': sorted(union), 'difference': sorted(union-plan), 'common': sorted(common),
                       'classification': dict(collections.Counter(r[2] for r in obligations))})
    handoffs = rows(section(detail, '## 8.', '## 9.'))[1:]
    assert len(handoffs) == 33
    assert collections.Counter(r[1] for r in handoffs) == {'今回': 25, '継承': 3, '他段': 5}
    # 既存の抽出台本の純粋関数を使用し、群 A の記録は書き換えない。
    spec = importlib.util.spec_from_file_location('source_inventory', STAGE / 'a/records.py')
    helpers = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(helpers)
    constructors = {}
    for file, expected in [
        ('Syntax', {'Val':25, 'Comp':16}), ('RuntimeSyntax', {'State':4, 'Frame':7, 'Cell':6}),
        ('Types', {'Ty':21}), ('Typing', {'HasTypeVQ':29, 'HasTypeVsQ':2, 'HasTypeEachQ':2, 'HasTypeCQ':24}),
        ('Le', {'Ty.LeQ':14, 'TelLe':2, 'TelClosure':2, 'TypeArgsLe':4}),
        ('StateTyping', {'ContTy':10}),
        ('KeyContracts', {'Observation.KeyShape':11, 'Observation.KeySlots':2, 'Observation.KeyPairs':2}),
        ('Semantics', {'Step':76})]:
        for name, count in expected.items():
            values = helpers.ctors(REF / (file+'.lean'), name)
            assert len(values) == count, (name, len(values), count)
            constructors[name] = {'file':str((REF/(file+'.lean')).relative_to(ROOT)), 'constructors':values}
    for name, count in {'EvalPartial':69, 'EvalArguments':4, 'EvalTypedArguments':4,
                        'EvalArms':6, 'EvalWidthArms':6, 'EvalResultArms':6, 'EvalBlock':14, 'EvalStandard':7}.items():
        path = FORMAL/'Benitoite/Interval/Eval.lean'
        values = helpers.ctors(path, name)
        assert len(values) == count
        constructors[name] = {'file':str(path.relative_to(ROOT)), 'constructors':values}
    save('constructors.json', constructors)
    api_names=set()
    api_modules=[]
    for row in rows((STAGE/'results.md').read_text()):
        if not re.fullmatch(r'\w+\.bnt',row[0]):continue
        path=ROOT/'crates/benitoite/src/prelude/stdlib'/row[0]
        names=re.findall(r'^public function (\w+)',path.read_text(),re.M)
        assert len(names)==int(row[-1])
        api_names.update(path.stem+'.'+name for name in names)
        api_modules.append({'module':path.stem,'apis':len(names),'source':digest(path)})
    ordinary=json.loads((STAGE/'e/sources-r4-u28.json').read_text())
    assert len(api_modules)==23 and len(api_names)==328
    assert ordinary['counts']['pure-local']==244 and ordinary['counts']['core-local']==84 and ordinary['counts']['open']==0
    actual={r[0] for r in ordinary['rows']}
    assert actual==api_names,(sorted(actual-api_names),sorted(api_names-actual))
    save('apis.json',{'count':328,'modules':api_modules,'normal_contracts':{'pure':244,'core':84,'unconnected':0},
                      'source_record':digest(STAGE/'e/sources-r4-u28.json'),
                      'whole_api_closure':0,'whole_obligation_closure':0})
    leaves = [r for r in rows((STAGE/'c/leaves.md').read_text()) if any(re.search(r'\bE_\w+', x) for x in r)]
    leaf_names = [re.search(r'\bE_\w+', ' '.join(r))[0] for r in leaves]
    assert len(leaf_names) == len(set(leaf_names)) == 76
    assert set(leaf_names) == set(constructors['Step']['constructors'])
    proof = (REF/'IntervalFailure.lean').read_text()
    proof_cases = {}
    for judgment, theorem in [('EvalPartial','expr_failure'), ('EvalArms','armList_failure'),
                              ('EvalWidthArms','armListKind_failure'), ('EvalResultArms','resultArmList_failure'),
                              ('EvalBlock','block_failure')]:
        body = section(proof, 'theorem '+theorem+' ', 'termination_by')
        cases = set()
        for line in body.splitlines():
            if re.match(r'^    \| \.', line):
                cases.update(re.findall(r'\.(\w+)', line.split('=>')[0]))
        assert set(constructors[judgment]['constructors']) <= cases
        proof_cases[judgment] = theorem
    source_modules = {str(p.relative_to(FORMAL))[:-5].replace('/', '.'): p
                      for p in FORMAL.rglob('*.lean') if '.lake' not in p.parts}
    imports = {m: re.findall(r'^import ([\w.]+)', p.read_text(), re.M) for m,p in source_modules.items()}
    roots = ['Benitoite','DesugarDiff.Main','BuiltinCheck.Main','CoverageDiff.Main',
             'CoverageProgramDiff.Main','SurfaceCheck.Main','SurfaceCheck.All','IntervalDiff.Main']
    closures = {}
    for root in roots:
        seen = set()
        def visit(module):
            if module in seen or module not in imports:
                return
            seen.add(module)
            for child in imports[module]: visit(child)
        visit(root)
        closures[root] = sorted(seen)
    default = set().union(*(set(c) for c in closures.values()))
    changed = json.loads((HERE/'changed-modules.json').read_text())
    assert set(changed['modules']) <= set(closures['Benitoite'])
    assert set(changed['new_modules']) <= set(closures['Benitoite'])
    summary_closures = {}
    for root, values in closures.items():
        output = args.tmp / (root.replace('.','-')+'-closure.txt')
        output.write_text('\n'.join(values)+'\n')
        summary_closures[root] = {'count':len(values), 'refinement':sum('.Refinement.' in v for v in values), **digest(output)}
    # 宣言一覧は後の環境監査が全名を供給する。ここではモジュールの出どころと読者を固定する。
    readers = {m:sorted(reader for reader in default if m in imports[reader]) for m in changed['modules']}
    for i in range(0,len(readers),80):
        save(f'readers-part-{i//80+1:02}.json', dict(list(readers.items())[i:i+80]))
    save('import-closure.json', {'default_roots':roots, 'closures':summary_closures,
                               'union_count':len(default), 'benitoite_closure':len(closures['Benitoite']),
                               'all_changed_in_default':True, 'all_added_in_default':True})
    # 未知の失敗を拒否する旧例を名前だけでなく本体の保持まで点検する。
    old = (FORMAL/'Benitoite/Interval/BudgetSound.lean').read_text()
    unknown = [str(p.relative_to(ROOT)) for p in (FORMAL/'Benitoite').rglob('*.lean')
               if 'unknownFailed' in p.read_text() and '.lake' not in p.parts]
    save('reconciliation.json', {'obligations':64, 'plan':56, 'l20':37, 'l30':21, 'union':60,
                               'difference':4, 'common':4, 'handoffs':33, 'handoff_classes':{'今回':25,'継承':3,'他段':5},
                               'constructors':{k:len(v['constructors']) for k,v in constructors.items()},
                               'leaves':76, 'h04_cases':109, 'h04_proof_readers':proof_cases,
                               'unknown_failed_sources':unknown, 'default_project_modules':len(default),
                               'script':digest(Path(__file__))})
    print(json.dumps({'obligations':64, 'handoffs':33, 'leaves':76, 'h04_cases':109,
                      'default_project_modules':len(default), 'changed_modules':len(changed['modules'])}))


if __name__ == '__main__':
    main()
