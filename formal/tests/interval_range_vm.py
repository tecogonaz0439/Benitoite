"""Range の実ソースを、独立期待値・閉じた評価・標識付き実 CLI で比較する。"""
import json
import subprocess
from pathlib import Path

import interval_source_compare as source
import interval_vm_compare as vm


def con(owner, name, args, types=()):
    return {'con': dict(owner=owner, name=name, args=args, types=list(types))}


def integer(n):
    return {'integer': str(n)}


def payload(names, arguments):
    return con(names['owner'], names['checkedConstructor'], list(map(integer, arguments)))


def check_result(names, arguments, types):
    lo, hi, n = map(int, arguments)
    if hi < lo or not lo <= n <= hi:
        kind = 'invalidBounds' if hi < lo else 'outOfRange'
        args = arguments[:2] if hi < lo else arguments
        error = {kind: list(map(str, args))}
        value = {'rangeError': dict(owner=names['error'], name=names[kind], error=error)}
        return con(names['result'], names['err'], [value], types), {'failed': error}
    value = payload(names, arguments)
    return con(names['result'], names['ok'], [value], types), {'normal': value}


def render_result(arguments):
    lo, hi, n = map(int, arguments)
    if hi < lo:
        return f'InvalidBounds:{lo}:{hi}'
    if not lo <= n <= hi:
        return f'OutOfRange:{lo}:{hi}:{n}'
    return f'Ok:{lo}:{hi}:{n}'


def result_main(name):
    # minimum/maximum は観察用。評価関係の具体規則には追加しない。
    return f'''
function main() -> Unit uses Console.Write
  match {name}() with
    case Result.Ok(checked) -> Console.writeLine("VALUE:Ok:${{R.minimum(checked)}}:${{R.maximum(checked)}}:${{R.value(checked)}}")
    case Result.Error(R.RangeError.InvalidBounds(lo, hi)) -> Console.writeLine("VALUE:InvalidBounds:${{lo}}:${{hi}}")
    case Result.Error(R.RangeError.OutOfRange(lo, hi, n)) -> Console.writeLine("VALUE:OutOfRange:${{lo}}:${{hi}}:${{n}}")
  end match
end function
'''


def specifications(cases):
    specs = {}
    for case in cases:
        if case['input'] != 'range' or case['id'] == 'unrelated':
            continue
        arguments = case.get('arguments')
        if 'raw' in case:
            recorded = case['result']
            expected = ('Ok:'+':'.join(recorded['Ok']) if 'Ok' in recorded else
                        recorded['Error']['constructor']+':'+':'.join(recorded['Error']['arguments']))
            assert render_result(arguments) == expected, (case['id'], 'independent Result expectation')
            for field in ['raw', 'projection', 'onlyOk']:
                if field in case:
                    specs[case[field]] = dict(checks=[arguments], raw=field == 'raw',
                                              value=case['value'])
        else:
            checks = [arguments] if arguments else [[0, 10, 5], [100, 110, 105]]
            for field in ['projection', 'onlyOk']:
                specs[case[field]] = dict(checks=checks, raw=False, value=case['value'],
                                         failure=case.get('failure'),
                                         outer=case['id'] == 'nested-outer')
    specs['savedResult'] = dict(checks=[[0, 10, 5]], raw=False, value='5')
    specs['importedAlias'] = dict(checks=[[0, 10, 5]], raw=False, value='5')
    # 字面・引数・結果・順序は手計算。実行器の出力から期待値を作らない。
    specs['argumentOrder'] = dict(checks=[[0, 10, 5]], raw=True, arithmetic=[
        ('2 + 3', [2, 3], 5), ('9 + 1', [9, 1], 10), ('1 - 1', [1, 1], 0)])
    specs['firstArgumentFailure'] = dict(checks=[], raw=True, failure='zeroDivisor',
                                        arithmetic=[('8 div 0', [8, 0], 'zeroDivisor')])
    specs['secondArgumentFailure'] = dict(checks=[], raw=True, failure='zeroDivisor',
        arithmetic=[('2 + 3', [2, 3], 5), ('8 div 0', [8, 0], 'zeroDivisor')])
    specs['argumentReturn'] = dict(checks=[], raw=False, value='42')
    return specs


def evaluation(definition, spec, sites, text, names, declarations):
    own = [s for s in sites if s['key'][0] == definition['name']]
    trace = []
    def event(site, arguments, result, operation):
        trace.append(dict(key=site['key'], operation=operation, arguments=arguments, result=result))
    for fragment, args, result in spec.get('arithmetic', []):
        site, = [s for s in own if text[s['span'][1]:s['span'][2]] == fragment]
        expr = site['expression']['binary']
        event(site, list(map(integer, args)), {'failed': result} if isinstance(result, str) else {'normal': integer(result)},
              dict(binary=expr['op'], type=expr['operand']))
    checks = sorted([s for s in own if 'call' in s['expression'] and
                     s['expression']['call']['callee']['funName']['name'] == declarations['check']],
                    key=lambda s: int(s['key'][1]))
    assert len(spec['checks']) <= len(checks)
    result = None
    for site, args in zip(checks, spec['checks']):
        call_type = next(t['type'] for t in definition['types'] if t['key'] == site['key'])
        result, operation_result = check_result(names, args, call_type['data']['args'])
        event(site, list(map(integer, args)), operation_result, {'standard': declarations['check']})
    if not spec['raw'] and spec['checks']:
        projections = [s for s in own if 'call' in s['expression'] and
                       s['expression']['call']['callee']['funName']['name'] == declarations['value']]
        if result['con']['name'] == names['ok']:
            site, = projections
            args = spec['checks'][0 if spec.get('outer') else -1]
            event(site, [payload(names, args)], {'normal': integer(args[2])}, {'standard': declarations['value']})
            if spec.get('failure') == 'overflow' or definition['name'].startswith('.increment'):
                site, = [s for s in own if 'binary' in s['expression']]
                expr = site['expression']['binary']
                event(site, [integer(args[2]), integer(1)],
                      {'failed': 'overflow'} if spec.get('failure') else {'normal': integer(10)},
                      dict(binary=expr['op'], type=expr['operand']))
    outcome = ({'failed': spec['failure']} if spec.get('failure') else
               {'returned': result if spec['raw'] else integer(spec['value'])})
    return dict(outcome=outcome, trace=trace)


def exercise(runner, directory, cli):
    directory, cli = Path(directory).resolve(), Path(cli).resolve()
    original = source.read(directory/'original/interval-material.json')['inputs'][0]
    manifest = source.read(directory/'original/interval-manifest.json')['inputs'][0]
    marked = source.read(directory/'instrumented/interval-material.json')['inputs'][0]
    marked_manifest = source.read(directory/'instrumented/interval-manifest.json')['inputs'][0]
    observed = source.read(directory/'original/interval-observations.json')['inputs'][0]
    text, marked_text = (directory/'original.bnt').read_text(), (directory/'instrumented.bnt').read_text()
    sites = vm.connect_sites(source.read(directory/'vm-sites.json')['sites'], marked_manifest, marked_text)
    entries = source.correspondence(manifest)
    definitions = source.unique([d for m in original['modules'] for d in m['definitions']], 'name')
    marked_defs = source.unique([d for m in marked['modules'] for d in m['definitions']], 'name')
    obs = source.unique([b for b in observed['bodies'] if b.get('kind') != 'whole'], 'definition')
    check, = [s for s in original['standards'] if 'rangeCheck' in s['rule']]
    value, = [s for s in original['standards'] if 'rangeValue' in s['rule']]
    names = check['rule']['rangeCheck']
    declarations = dict(check=check['declaration'], value=value['declaration'])
    fixture = Path(__file__).resolve().parents[2]/'crates/benitoite/tests/desugar_export/interval/range-expectations.json'
    cases = source.read(fixture)['cases']
    specs = specifications(cases)
    assert len(original['modules']) == 1
    assert set(definitions) == set(marked_defs)
    for name in definitions:
        # 観察専用の本体も標識除去後の構造を照合する。
        env = tuple({'parameter': i} for i in range(len(definitions[name]['params'])))
        assert vm.normalize(definitions[name]['body'], env) == vm.normalize(marked_defs[name]['body'], env)
    selected = []
    for name, spec in specs.items():
        definition = definitions['.'+name]
        vm.require_closed(entries['.'+name], original['standards'],
                          [s for s in original['apiAt'] if s['key'][0] == '.'+name])
        assert obs['.'+name]['coverage'] == 'Prepared' and not obs['.'+name]['unsupported']
        definition['expected'] = source.expectation(obs['.'+name], entries['.'+name], {})
        definition['evaluation'] = evaluation(definition, spec, sites, text, names, declarations)
        unit = {'base': {'name': 'Unit'}}
        tail = definition['body']
        while any(tag in tail for tag in ['bind', 'discard', 'seq']):
            tail = next(iter(tail.values()))['rest']
        assert tail['last']['expr']['returnE']['ret'] == unit
        assert any(e['expression'] == tail['last']['expr'] and e['type'] == unit for e in entries['.'+name])
        definition['type'] = unit
        definition['types'][0]['type'] = unit
        selected.append(definition)
    for site in sites:
        row = entries[site['key'][0]][int(site['key'][1])]
        assert row['span'] == site['span'] and row['expression'] == site['expression'] and row['acquired']
    excluded = [dict(definition=name, reason='observationOnly' if name.endswith('Fields') or name == '.threeFields'
                     else 'parameterOrGeneralCall') for name in definitions if name[1:] not in specs]
    original['modules'][0]['definitions'] = selected
    original['apiAt'] = [s for s in original['apiAt'] if s['key'][0][1:] in specs]
    corpus = dict(kind='interval-corpus', version=1, surfaceVersion=15, traversalVersion=1,
                  profile='domain', inputs=[original])
    report = runner.invoke('range-closed', 'eval', corpus, 0)
    assert report['comparedCount'] == str(len(specs)) and report['excludedCount'] == '0'
    rows = source.unique(report['inputs'][0]['bodies'], 'definition')
    runs = []
    for name, spec in specs.items():
        row = rows['.'+name]
        assert row['comparisonEligible'] and row['matched']
        main = result_main(name) if spec['raw'] else f'''
function main() -> Unit uses Console.Write
  Console.writeLine("VALUE:${{{name}()}}")
end function
'''
        path = runner.directory/(name+'.bnt')
        path.write_text(marked_text+main)
        process = subprocess.run([str(cli), 'run', '--diagnostics=json', '--allow-effects=Console.Write', str(path)],
                                 capture_output=True, text=True, timeout=30)
        (runner.directory/(name+'.stdout')).write_text(process.stdout)
        (runner.directory/(name+'.stderr')).write_text(process.stderr.replace(str(runner.directory), '<tmp>'))
        rendered = render_result(spec['checks'][0]) if spec['raw'] and spec['checks'] else spec.get('value')
        runs.append(dict(definition='.'+name, **vm.compare_run(process, row['actual'], sites, rendered)))
    # 元の別関数の引数へ由来を渡さず、VM の105だけを独立に観察する。
    name = 'unrelatedCaller'
    path = runner.directory/(name+'.bnt')
    path.write_text(marked_text+f'\nfunction main() -> Unit uses Console.Write\n Console.writeLine("VALUE:${{{name}()}}")\nend function\n')
    process = subprocess.run([str(cli), 'run', '--diagnostics=json', str(path)], capture_output=True, text=True, timeout=30)
    (runner.directory/(name+'.stdout')).write_text(process.stdout)
    (runner.directory/(name+'.stderr')).write_text(process.stderr.replace(str(runner.directory), '<tmp>'))
    expected_sites = []
    for owner, role in [('.unrelatedCaller', 'check'), ('.unrelated', 'check'), ('.unrelated', 'value')]:
        site, = [s for s in sites if s['key'][0] == owner and
                  s['expression'].get('call', {}).get('callee', {}).get('funName', {}).get('name') == declarations[role]]
        expected_sites.append(site['marker'])
    assert process.returncode == 0 and process.stdout.splitlines() == expected_sites+['VALUE:105']
    assert not any(json.loads(l)['severity'] == 'error' for l in process.stderr.splitlines())
    negatives = []
    original_entries = entries['.lower']
    try:
        vm.require_closed(original_entries, original['standards'], [])
    except AssertionError as error:
        assert 'unknown call' in str(error)
        negatives.append('unidentifiedRangeCall')
    else:
        raise AssertionError('unidentified Range call accepted')
    for field in ['resultConstructor', 'minimum', 'maximum', 'value', 'reversedPriority']:
        name = 'reversedOutside' if field == 'reversedPriority' else 'lower'
        stdout = (runner.directory/(name+'.stdout')).read_text()
        old = 'InvalidBounds:10:0' if name == 'reversedOutside' else 'Ok:0:10:0'
        new = {'resultConstructor': 'Error:0:10:0', 'minimum': 'Ok:1:10:0',
               'maximum': 'Ok:0:9:0', 'value': 'Ok:0:10:1', 'reversedPriority': 'OutOfRange:10:0:15'}[field]
        broken = subprocess.CompletedProcess([], 0, stdout.replace(old, new), '')
        try:
            vm.compare_run(broken, rows['.'+name]['actual'], sites, old)
        except AssertionError:
            negatives.append(field)
        else:
            raise AssertionError(('bad Range observation accepted', field))
    summary = dict(kind='interval-range-vm-comparison', compared=len(runs), evaluationExcluded=0,
                   selectedOut=excluded, operations=len(sites),
                   selectedOperations=sum(s['key'][0][1:] in specs for s in sites), runs=runs, sites=sites,
                   independentObservations=[dict(definition='.unrelatedCaller', value='105')], negativeCases=negatives)
    (runner.directory/'range-vm-summary.json').write_text(json.dumps(summary, indent=2)+'\n')
    return summary
