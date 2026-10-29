"""独立した拒否入力を Rust の診断と Lean の二つの検査入口へ対応付ける。

交換と期待値は手書きであり、Rust の出力も Lean の出力も生成元にしない。
必須判定の cover と、効果上限の型付けの拒否は別々に照合する。
"""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import re
import runpy
import subprocess
import time


def require(ok, message):
    if not ok:
        raise AssertionError(message)


ROOT = Path(__file__).resolve().parents[2]
HELPERS = runpy.run_path(str(Path(__file__).with_name('test_range_exchange.py')))
BIN = ROOT/'formal/.lake/build/bin'
TOP = 'top'
TREE = {'path': {'tree': ['data']}}
EXACT = {'path': {'exact': ['data', 'a']}}
ROOT_TREE = {'path': {'tree': []}}
BACKUP = {'path': {'tree': ['backup']}}
EP = {'endpoint': {'host': {'name': {'exact': ['api', 'example', 'com']}}, 'ports': {'lo': 443, 'hi': 443}}}
EP_WIDE = {'endpoint': {'host': {'name': {'many': ['example', 'com']}}, 'ports': {'lo': 80, 'hi': 443}}}
UNIT = HELPERS['UNIT']
STR = HELPERS['STR']
KEY = {'definition': 'fn:901', 'surfacePreorder': 0}
UNIT_CORE = {'ret': {'value': {'const': {'value': 'unit'}}}}


def atom(name, range_):
    return HELPERS['atom'](name, range_)


def path_case(contract, dynamic=False):
    return HELPERS['check_path_def']('fn:901', HELPERS['local'](1) if dynamic else '/data/**',
        [contract], ('pattern', 'raw') if dynamic else ('raw',), (STR, STR) if dynamic else (STR,))


def widen_case(source, target):
    opaque = HELPERS['opaque']
    ty = opaque(HELPERS['REQUEST_IN'], target)
    call = HELPERS['prim_call']('Http.widenRequestIn', [source, target], ['request'], [HELPERS['local'](0)])
    body = {'bind': {'shadow': False, 'ty': ty, 'expr': call, 'rest': {'last': {'expr': 'unit'}}}}
    bound = HELPERS['let_chain']([HELPERS['core_var'](0)], HELPERS['core_app']('Http.widenRequestIn', [source, target], 1))
    core = {'letIn': {'bound': bound, 'body': copy.deepcopy(UNIT_CORE)}}
    return HELPERS['definition']('fn:901', HELPERS['header'](['value'], [opaque(HELPERS['REQUEST_IN'], source)], UNIT), body, core)


def effect_case(need, upper, effect='File.Read'):
    callee = HELPERS['definition']('fn:900', HELPERS['header']([], [], UNIT, [atom(effect, need)]),
        {'last': {'expr': 'unit'}}, copy.deepcopy(UNIT_CORE))
    call = {'call': {'callee': {'funName': {'name': 'fn:900', 'tys': [], 'effs': []}},
                    'labels': [], 'positions': [], 'args': []}}
    core = {'app': {'callee': {'fnRef': {'name': 'fn:900', 'tys': [], 'effs': []}}, 'args': []}}
    sample = HELPERS['definition']('fn:901', HELPERS['header']([], [], UNIT, [atom(effect, r) for r in upper]),
        {'last': {'expr': call}}, core)
    return [callee, sample]


# 期待する非Top件数は表層・コアの型の添字と呼び出しの範囲の列を手で数えた値である。
# scopeAcceptance の pattern/host の定義や候補の一覧は、この件数へ混ぜない。
EXPECTATIONS = {
    'required-not-covered': {'comparison': 'required', 'reason': 'notCovered', 'index': TREE, 'contract': EXACT,
                             'definitions': 1, 'nonTopRanges': 3},
    'required-unknown': {'comparison': 'required', 'reason': 'unknownSource', 'index': TOP, 'contract': TREE,
                         'definitions': 1, 'nonTopRanges': 3},
    'request-widen-rejected': {'comparison': 'required', 'reason': 'unknownSource', 'index': TOP, 'contract': EP,
                              'definitions': 1, 'nonTopRanges': 7},
    'effect-not-covered': {'comparison': 'typing', 'rustReason': 'notCovered', 'definitions': 2, 'nonTopRanges': 4},
    'effect-atomic': {'comparison': 'typing', 'rustReason': 'atomicCoverOnly', 'definitions': 2, 'nonTopRanges': 6},
    'effect-top': {'comparison': 'typing', 'rustReason': 'unknownSource', 'definitions': 2, 'nonTopRanges': 2,
                   'atomReasonExpected': 'unknownSource'},
    'effect-top-exceeded': {'comparison': 'typing', 'rustReason': 'unknownSource', 'definitions': 2, 'nonTopRanges': 2,
                            'atomReasonExpected': 'budgetExceeded'},
    'required-not-covered-accepted': {'comparison': 'accepted', 'definitions': 1, 'nonTopRanges': 3},
    'required-unknown-accepted': {'comparison': 'accepted', 'definitions': 1, 'nonTopRanges': 0},
    'request-widen-rejected-accepted': {'comparison': 'accepted', 'definitions': 1, 'nonTopRanges': 0},
    'effect-not-covered-accepted': {'comparison': 'accepted', 'definitions': 2, 'nonTopRanges': 4},
    'effect-atomic-accepted': {'comparison': 'accepted', 'definitions': 2, 'nonTopRanges': 4},
    'effect-top-accepted': {'comparison': 'accepted', 'definitions': 2, 'nonTopRanges': 0},
    'atomic-union-rejected': {'comparison': 'typing', 'definitions': 2, 'nonTopRanges': 6,
                             'meaning': '0..9 を0..4と5..9の和で受理しない'},
    'atomic-left-accepted': {'comparison': 'accepted', 'definitions': 2, 'nonTopRanges': 6},
    'atomic-right-accepted': {'comparison': 'accepted', 'definitions': 2, 'nonTopRanges': 6},
}


def fixtures():
    ep = lambda lo, hi: {'endpoint': {'host': copy.deepcopy(EP['endpoint']['host']), 'ports': {'lo': lo, 'hi': hi}}}
    defs = {
        'required-not-covered': [path_case(EXACT)],
        'required-unknown': [path_case(TREE, True)],
        'request-widen-rejected': [widen_case(EP, EP_WIDE)],
        'effect-not-covered': effect_case(ROOT_TREE, [TREE]),
        'effect-atomic': effect_case(ROOT_TREE, [BACKUP, TREE]),
        'effect-top': effect_case(TOP, [ROOT_TREE]),
        'effect-top-exceeded': effect_case(TOP, [ROOT_TREE]),
        'required-not-covered-accepted': [path_case(TREE)],
        'required-unknown-accepted': [path_case(TOP, True)],
        'request-widen-rejected-accepted': [widen_case(TOP, TOP)],
        'effect-not-covered-accepted': effect_case(ROOT_TREE, [ROOT_TREE]),
        'effect-atomic-accepted': effect_case(ROOT_TREE, [ROOT_TREE]),
        'effect-top-accepted': effect_case(TOP, [TOP]),
        'atomic-union-rejected': effect_case(ep(0, 9), [ep(0, 4), ep(5, 9)], 'Http.Connect'),
        'atomic-left-accepted': effect_case(ep(0, 4), [ep(0, 4), ep(5, 9)], 'Http.Connect'),
        'atomic-right-accepted': effect_case(ep(5, 9), [ep(0, 4), ep(5, 9)], 'Http.Connect'),
    }
    inputs, tables, stdlib = [], [], []
    for name, definitions in defs.items():
        input_ = HELPERS['corpus_input'](name, {}, HELPERS['WIDE'])
        input_['definitions'] = definitions
        if name == 'effect-top-exceeded':
            input_['scopeAcceptance']['limits'] = copy.deepcopy(input_['scopeAcceptance']['limits'])
            input_['scopeAcceptance']['limits']['body']['operations'] = 0
        table = HELPERS['builtin_input'](name)
        table['prims'].append(HELPERS['prim']('Http.widenRequestIn', ['request'],
            [HELPERS['opaque_var'](HELPERS['REQUEST_IN'])], HELPERS['opaque_var'](HELPERS['REQUEST_IN'], 1),
            [], 'pure', None, ['endpoint', 'endpoint'], 'untargeted'))
        table['admitsR'].append({'name': 'Http.widenRequestIn', 'rule': {'covers': {'inner': 0, 'outer': 1}}})
        table['effKinds'].append({'name': 'File.Read', 'kind': 'path'})
        table['effects'].extend([{'name': 'File.Read', 'ops': []}, {'name': 'Http.Connect', 'ops': []}])
        inputs.append(input_)
        tables.append(table)
        stdlib.append({'group': 'golden', 'name': name, 'functions': [], 'impls': []})
    return {'corpus': {'version': 15, 'operators': [], 'annotations': {'tailMatch': [0, 0]}, 'inputs': inputs},
            'builtins': {'version': 7, 'inputs': tables}, 'stdlib': {'version': 7, 'inputs': stdlib}}


def write_inputs(directory):
    directory = Path(directory)
    directory.mkdir(parents=True, exist_ok=True)
    paths = {}
    for name, value in {**fixtures(), 'expected': EXPECTATIONS}.items():
        path = directory/(name+'.json')
        encoded = json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2)+'\n'
        if path.exists():
            require(path.read_text() == encoded, ('frozen input differs', name))
        else:
            path.write_text(encoded)
        paths[name] = path
    rows = [{'path': p.name, 'bytes': p.stat().st_size, 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()}
            for p in paths.values()]
    (directory/'manifest.json').write_text(json.dumps({'basis': '比較前に独立に手書き。出力から生成しない',
        'keyCorrespondence': {'fn:901': 'sample', 'surfacePreorder': 0}, 'artifacts': rows}, ensure_ascii=False, indent=2)+'\n')
    return paths


def invoke(tool, paths, output, name, selected=False):
    report = output/(name+'-'+tool+'.json')
    args = [str(paths['corpus'])]
    if tool in ('builtinCheck', 'surfaceCheck', 'surfaceCheckAll'):
        args.append(str(paths['builtins']))
    if tool in ('surfaceCheck', 'surfaceCheckAll'):
        args.append(str(paths['stdlib']))
    if tool == 'surfaceCheck':
        args.extend(['golden', name])
    args.append(str(report))
    if selected:
        args.append('fn:901')
    start = time.monotonic()
    process = subprocess.run([str(BIN/tool), *args], text=True, capture_output=True, timeout=30)
    elapsed = time.monotonic()-start
    (output/(name+'-'+tool+'.log')).write_text((process.stdout+process.stderr).replace(str(ROOT), '<wt>').replace(str(Path.home()), '<home>'))
    require(report.exists(), (tool, name, process.returncode, process.stderr))
    return process.returncode, json.loads(report.read_text()), elapsed


def one_input(paths, name, output):
    directory = output/'inputs'/name
    directory.mkdir(parents=True, exist_ok=True)
    result = {}
    for field in ('corpus', 'builtins', 'stdlib'):
        value = json.loads(paths[field].read_text())
        value['inputs'] = [x for x in value['inputs'] if x['name'] == name]
        require(len(value['inputs']) == 1, 'test_range_rejections.py:171: requirement failed')
        target = directory/(field+'.json')
        target.write_text(json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2)+'\n')
        result[field] = target
    return result


def compare_contract_counterparts(exports, output):
    """独立交換と実ソースの実行に関わる全欄を、明示の対応で照合する。"""
    sources = ROOT/'crates/benitoite/tests/desugar_export/range-sources'
    expected = json.loads((sources/'contract-counterparts/expected.json').read_text())
    results = []
    for case in expected['cases']:
        name = case['name']
        original = (sources/(name+'.bnt')).read_text()
        for before, after in case['changes']:
            require(original.count(before) == 1, (name, 'ambiguous contract edit'))
            original = original.replace(before, after)
        source = sources/'contract-counterparts'/case['file']
        require(source.read_text() == original and hashlib.sha256(source.read_bytes()).hexdigest() == case['sha256'],
                (name, 'counterpart changed outside its declared contract edits'))
        directory = Path(exports)/'contract-counterparts'/name
        corpus = json.loads((directory/'named-programs-corpus.json').read_text())
        table = json.loads((directory/'named-programs-builtins.json').read_text())['inputs'][0]
        require(len(corpus['inputs']) == 1 and len(corpus['inputs'][0]['definitions']) == 1, name)
        actual = corpus['inputs'][0]['definitions'][0]['scope']['inScope']
        independent = next(i for i in fixtures()['corpus']['inputs'] if i['name'] == name)
        hand = independent['definitions'][0]['scope']['inScope']
        # 型の番号は固定せず同じ表の宣言名で対応付ける。
        type_names = {entry['name']: entry['typeName'] for entry in table['dataDecls']}
        kinds = {entry['name']: entry['kind'] for entry in table['valKinds']}
        opaque_names = {'path': HELPERS['PATH_IN'], 'endpoint': HELPERS['REQUEST_IN']}
        names = {key: opaque_names[kind] for key, kind in kinds.items()}

        def normalize(value):
            if isinstance(value, list):
                return [normalize(v) for v in value]
            if not isinstance(value, dict):
                return value
            # 独立交換ではScopeErrorを抽象型として置く。同じ標準の宣言へ対応させる。
            if value.get('opaque', {}).get('name') == HELPERS['SCOPE_ERROR_T']:
                return {'declaredType': 'ScopeError'}
            if 'data' in value:
                ty = value['data']
                label = type_names.get(ty['name'], ty['name'])
                if label == 'ScopeError':
                    require(ty['args'] == [], (name, 'ScopeError type arguments'))
                    return {'declaredType': label}
                return {'data': {**ty, 'name': label, 'args': normalize(ty['args'])}}
            if 'lastBind' in value:
                return normalize({'bind': {**value['lastBind'], 'rest': {'last': {'expr': 'unit'}}}})
            result = {}
            for key, child in value.items():
                if key == 'ix':
                    require(isinstance(child, dict) and set(child) == {'fixed'}, (name, 'unexpected range variable'))
                    result[key] = {'fixed': '<contract>'}
                elif key == 'ranges':
                    result[key] = ['<contract>']*len(child)
                elif key == 'name' and child in names:
                    result[key] = names[child]
                else:
                    result[key] = normalize(child)
            return result

        # packageとcoverageViewは独立交換と実ソースで異なる環境のメタデータ。
        # 契約・宣言名の対応・lastBindのUnit展開以外は本体と型の全欄を比較する。
        fields = {'surface': ('header', 'body', 'dictParams', 'implementation', 'method', 'supers'),
                  'core': ('header', 'body', 'lambdaEffects', 'supers')}
        projected = lambda definition: {part: {field: normalize(definition[part][field])
                                               for field in wanted} for part, wanted in fields.items()}
        a, b = projected(actual), projected(hand)
        require(a == b, (name, 'contract-independent structure differs', a, b))
        (output/(name+'-contract-structure.json')).write_text(json.dumps(a, ensure_ascii=False, indent=2)+'\n')
        results.append(dict(name=name, matched=True, fields=fields, sourceSha256=case['sha256'],
            rustDefinition=corpus['inputs'][0]['definitions'][0]['name'], independentDefinition='fn:901'))
    return dict(status='passed', cases=results, comparisons=len(results),
        scope='型と本体の全欄。契約・宣言同一性・lastBindのUnit展開を正規化。package/coverageViewは環境メタデータとして対象外')


def run_rejections(exports, output):
    output = Path(output)
    output.mkdir(parents=True, exist_ok=True)
    counterparts = compare_contract_counterparts(exports, output)
    paths = write_inputs(output/'independent')
    observed = json.loads((Path(exports)/'rust-observed.json').read_text())
    if isinstance(observed, dict):
        observed = observed.get('inputs', observed.get('cases'))
    rust = {row['name']: row for row in observed}
    source_only = []
    source_expected = json.loads((ROOT/'crates/benitoite/tests/desugar_export/range-sources/expected.json').read_text())
    for case in source_expected['cases']:
        if case.get('comparison') != 'source-only-required':
            continue
        actual = rust[case['name']]
        require(actual['accepted'] is False and len(actual['diagnostics']) == 1, (case['name'], actual))
        diagnostic = actual['diagnostics'][0]
        require(diagnostic['code'] == 'E0519' and 'reason: '+case['reason'] in diagnostic['notes'], (case['name'], diagnostic))
        require('knownUpperBound: Top (all targets)' in diagnostic['notes'], (case['name'], diagnostic))
        source_only.append(dict(name=case['name'], rustCode='E0519', rustReason=case['reason'], requiredIndex='top', comparison='Rust実ソースの手書き拒否期待'))
    outcomes = []
    for name, expected in EXPECTATIONS.items():
        current = one_input(paths, name, output)
        exit_, dd, elapsed_dd = invoke('desugarDiff', current, output, name)
        count = expected['definitions']
        require(exit_ == 0, (name, dd))
        require(dd['golden']['definitions'] == dict(matched=count, mismatched=0, outside=0, excluded=0), (name, dd))
        require(dd['nonTopRanges'] == expected['nonTopRanges'], (name, 'desugar ranges', dd['nonTopRanges']))
        exit_, sa, elapsed_sa = invoke('surfaceCheckAll', current, output, name)
        rejected = expected['comparison'] != 'accepted'
        require(exit_ == int(rejected), (name, sa))
        require(sa['nonTopRanges'] == expected['nonTopRanges'], (name, 'surface ranges', sa['nonTopRanges']))
        counts = sa['counts']
        require(counts['matched'] == count-int(rejected) and counts['mismatched'] == int(rejected), (name, counts))
        require(all(counts[k] == 0 for k in ('q11', 'outOfScope', 'lazyRestriction', 'preparationFailure')), (name, counts))
        exit_, sc, elapsed_sc = invoke('surfaceCheck', current, output, name, True)
        require(exit_ == int(rejected), (name, sc))
        actual = sc['result']
        if not rejected:
            require(actual == {'ok': True}, (name, actual))
        elif expected['comparison'] == 'required':
            require(actual == {'ok': False, 'cover': {'key': KEY, 'reason': expected['reason']}}, (name, actual))
            outcome = next(o for o in sa['outcomes'] if o['category'] == 'mismatched')
            text = json.dumps(outcome)
            require('required check is not covered:' in text and expected['reason'] in text, (name, outcome))
        else:
            require('cover' not in actual and actual['ok'] is False, (name, actual))
            require(actual['error']['reason'] == 'effect exceeds the allowed effect', (name, actual))
            require('effect exceeds the allowed effect' in json.dumps(sa['outcomes']), (name, sa))
        row = {'name': name, 'comparison': expected['comparison'], 'lean': actual,
               'definitions': count, 'nonTopRanges': expected['nonTopRanges'],
               'seconds': {'desugarDiff': elapsed_dd, 'surfaceCheckAll': elapsed_sa, 'surfaceCheck': elapsed_sc}}
        if name in rust:
            r = rust[name]
            require(r['accepted'] is False, (name, r))
            diagnostics = [d for d in r['diagnostics'] if 'E0519' in str(d['code'])]
            require(len(diagnostics) == 1, (name, diagnostics))
            diagnostic = diagnostics[0]
            reason = expected.get('reason', expected.get('rustReason'))
            require('reason: '+reason in diagnostic['notes'], (name, reason, diagnostic))
            row['rustReason'] = reason
            row['rustCode'] = 'E0519'
            if expected['comparison'] == 'required':
                notes = '\n'.join(str(n) for n in diagnostic['notes'])
                match = re.search(r'scope call: \.sample at surface preorder ([0-9]+)', notes)
                require(match and int(match.group(1)) == KEY['surfacePreorder'], (name, notes))
                # 必須判定の添字は拒否時にも knownUpperBound に残る。単なる同理由の一致で済ませない。
                known = [n.removeprefix('knownUpperBound: ') for n in diagnostic['notes']
                         if n.startswith('knownUpperBound: ')]
                require(len(known) == 1, (name, known))
                if known[0] == 'Top (all targets)':
                    observed_index = TOP
                else:
                    texts = json.loads(known[0])
                    require(len(texts) == 1 and texts[0].startswith('/'), (name, texts))
                    text = texts[0]
                    tree = text.endswith('/**')
                    observed_index = {'path': {'tree' if tree else 'exact':
                        (text[:-3] if tree else text).strip('/').split('/')}}
                require(observed_index == expected['index'], (name, observed_index, expected['index']))
                row['sourceKey'] = {'definition': 'sample', 'surfacePreorder': int(match.group(1))}
                row['requiredIndex'] = observed_index
                row['contract'] = expected['contract']
            else:
                row['reasonComparison'] = 'E0519と型付け拒否の一致。cover理由の直接一致とは数えない'
                if name in ('effect-top', 'effect-top-exceeded'):
                    row['leanAtomReasonExpected'] = expected['atomReasonExpected']
                    row['leanAtomReasonObserved'] = None
                    row['reasonNote'] = '入口はtypingだけを報告する。原子の理由をcoverへ変換しない'
        if name == 'effect-top-exceeded':
            provenance = json.loads((Path(exports)/'effect-top-exceeded-provenance.json').read_text())
            require(provenance['numberingComplete'] and provenance['lastRunExceeded'], provenance)
            row['rustProvenance'] = provenance
            row['leanProvenance'] = {'bodyOperationsLimit': 0, 'lastRunExceededByDefinition': True,
                'atomFailureByDefinition': 'budgetExceeded', 'atomFailureObserved': None}
        outcomes.append(row)
    require(sum(o['comparison'] == 'required' for o in outcomes) == 3, 'test_range_rejections.py:256: requirement failed')
    require(sum(o['comparison'] == 'typing' for o in outcomes) == 5, 'test_range_rejections.py:257: requirement failed')
    main = [o for o in outcomes if o['name'] in rust]
    require(len(main) == 7, 'test_range_rejections.py:259: requirement failed')
    summary = {'status': 'passed', 'contractCounterparts': counterparts, 'groups': len(outcomes), 'sourceRejections': 7+len(source_only), 'sourceOnlyRejections': source_only,
        'requiredIndependentExpectationComparisons': 3, 'requiredSameInputDirectComparisons': 0, 'typingRejectionComparisons': 4,
        'independentAtomicUnionRejections': 1, 'acceptedCounterparts': 8,
        'definitions': sum(o['definitions'] for o in outcomes), 'nonTopRanges': sum(o['nonTopRanges'] for o in outcomes),
        'outcomes': outcomes}
    (output/'summary.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2)+'\n')
    return summary


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--freeze', type=Path)
    parser.add_argument('--exports', type=Path)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    if args.freeze:
        write_inputs(args.freeze)
    else:
        require(args.exports and args.output, 'test_range_rejections.py:278: requirement failed')
        print(json.dumps(run_rejections(args.exports, args.output), ensure_ascii=False))


if __name__ == '__main__':
    main()
