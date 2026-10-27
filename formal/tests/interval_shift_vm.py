"""シフトの域外だけを評価関係と厳密比較し、残りは独立したVM期待値で照合する。"""
import json
import subprocess
from pathlib import Path

import interval_source_compare as source
import interval_vm_compare as vm


def specifications():
    # Rust の生成器・解析結果・evalClosed の出力を期待値に転用しない。
    # 左端の -1 / 全ビット1 と、0 / w-1 のビット列から手計算する。
    modules = [('Integer', 'Integer', 64), ('Integer64', 'Integer', 64),
               ('Integer8', 'Integer8', 8), ('Integer16', 'Integer16', 16),
               ('Integer32', 'Integer32', 32), ('UnsignedInteger', 'UnsignedInteger64', 64),
               ('UnsignedInteger64', 'UnsignedInteger64', 64),
               ('UnsignedInteger16', 'UnsignedInteger16', 16),
               ('UnsignedInteger32', 'UnsignedInteger32', 32),
               ('Byte', 'Byte', 8), ('UnsignedInteger8', 'Byte', 8)]
    specs = {}
    for module, kind, width in modules:
        signed = module.startswith('Integer')
        operand = -1 if signed else 2**width-1
        for direction in (['Left', 'Right', 'RightUnsigned'] if signed else ['Left', 'Right']):
            for label, amount in [('negative', -1), ('width', width), ('zero', 0), ('last', width-1)]:
                outside = label in ('negative', 'width')
                if outside:
                    result = None
                elif amount == 0:
                    result = operand
                elif direction == 'Left':
                    result = -(2**(width-1)) if signed else 2**(width-1)
                else:
                    result = -1 if direction == 'Right' and signed else 1
                reason = ('notClosedOrFuel' if kind == 'Byte' else
                          'unknownFailure' if not outside else None)
                specs['.shift'+module+direction+label] = dict(module=module, kind=kind, width=width,
                    standardName='Benitoite.'+module+'.shift'+direction, operand=operand, amount=amount,
                    outside=outside, result=result, evaluationExcluded=reason)
    assert len(specs) == 108
    return specs


def expected_evaluation(spec, site):
    if spec['evaluationExcluded']:
        return {'excluded': spec['evaluationExcluded']}
    outcome = {'failed': 'outsideDomain'}
    return dict(outcome=outcome, trace=[dict(key=site['key'], operation={'standard': spec['declaration']},
        arguments=[vm.concrete(spec['kind'], spec['operand']), {'integer': str(spec['amount'])}], result=outcome)])


def compare_run(process, spec, site, path):
    # 域内は評価関係が具体的な値を定めない。独立期待値だけへ照合する。
    expected = (dict(outcome={'failed': 'outsideDomain'}, trace=[dict(key=site['key'])]) if spec['outside']
                else dict(outcome={'returned': {'integer': str(spec['result'])}}, trace=[dict(key=site['key'])]))
    result = vm.compare_run(process, expected, [site], str(spec['result']))
    errors = [json.loads(line) for line in process.stderr.splitlines()
              if json.loads(line)['severity'] == 'error']
    if spec['outside']:
        error, = errors
        assert error['code'] == 'R0701' and error['primary']['file'] == str(path), error
        # 包みの関数は末尾で別の組み込みを呼ぶ。文言はその組み込み、位置は元call。
        module, direction = spec['standardName'].removeprefix('Benitoite.').split('.')
        target = {'Integer64': 'Integer', 'UnsignedInteger': 'UnsignedInteger64',
                  'UnsignedInteger8': 'Byte'}.get(module, module)
        assert error['message'] == f'argument 2 of `{target}.{direction}` is out of range', error
        result['failureLocation'] = dict(file=path.name, start=error['primary']['start']['offset'],
                                        end=error['primary']['end']['offset'], kind='sourceCall',
                                        message=error['message'])
    return result


def exercise(runner, directory, cli):
    directory, cli = Path(directory).resolve(), Path(cli).resolve()
    original = source.read(directory/'original/interval-material.json')['inputs'][0]
    manifest = source.read(directory/'original/interval-manifest.json')['inputs'][0]
    observed = source.read(directory/'original/interval-observations.json')['inputs'][0]
    marked = source.read(directory/'instrumented/interval-material.json')['inputs'][0]
    marked_manifest = source.read(directory/'instrumented/interval-manifest.json')['inputs'][0]
    text, marked_text = (directory/'original.bnt').read_text(), (directory/'instrumented.bnt').read_text()
    sites = vm.connect_sites(source.read(directory/'vm-sites.json')['sites'], marked_manifest, marked_text)
    definitions = source.unique([d for m in original['modules'] for d in m['definitions']], 'name')
    marked_defs = source.unique([d for m in marked['modules'] for d in m['definitions']], 'name')
    obs = source.unique([b for b in observed['bodies'] if b.get('kind') != 'whole'], 'definition')
    entries = source.correspondence(manifest)
    specs = specifications()
    assert len(original['modules']) == 1 and set(definitions) == set(marked_defs) == set(specs)
    assert len(sites) == len(specs)
    for name, definition in definitions.items():
        spec = specs[name]
        site, = [s for s in sites if s['key'][0] == name]
        row = entries[name][int(site['key'][1])]
        assert row['span'] == site['span'] and row['expression'] == site['expression'] and row['acquired']
        assert vm.normalize(definition['body']) == vm.normalize(marked_defs[name]['body']), name
        binding, = [s for s in original['standards'] if s['name'] == spec['standardName']]
        spec['declaration'] = binding['declaration']
        assert binding['rule']['fixedDomain']['operand'] == {'base': {'name': spec['kind']}}
        at = [s for s in original['apiAt'] if s['key'][0] == name]
        assert at == [dict(key=site['key'], declaration=spec['declaration'])], at
        if spec['kind'] != 'Byte':
            vm.require_closed(entries[name], original['standards'], at, fixed_domain=True)
            assert obs[name]['coverage'] == 'Prepared' and not obs[name]['unsupported']
        definition['expected'] = source.expectation(obs[name], entries[name],
                                                    {s['declaration']: s['name'] for s in original['standards']})
        definition['evaluation'] = expected_evaluation(spec, site)
        # 元の本体の型を確認し、評価専用の根だけ Unit に戻す。
        unit = {'base': {'name': 'Unit'}}
        tail = definition['body']['last']['expr']
        assert tail['returnE']['ret'] == unit
        assert any(e['expression'] == tail and e['type'] == unit for e in entries[name])
        definition['type'] = unit
        definition['types'][0]['type'] = unit
    corpus = dict(kind='interval-corpus', version=1, surfaceVersion=14, traversalVersion=1,
                  profile='domain', inputs=[original])
    report = runner.invoke('shifts-closed', 'eval', corpus, 0)
    assert report['comparedCount'] == '46' and report['excludedCount'] == '62'
    rows = source.unique(report['inputs'][0]['bodies'], 'definition')
    runs = []
    for name, spec in specs.items():
        row = rows[name]
        assert row['matched'] and row['comparisonEligible'] == (spec['evaluationExcluded'] is None), row
        site, = [s for s in sites if s['key'][0] == name]
        if spec['evaluationExcluded'] is None:
            assert row['actual'] == expected_evaluation(spec, site)
        main = f'\nfunction main() -> Unit uses Console.Write\n Console.writeLine("VALUE:${{{name[1:]}()}}")\nend function\n'
        path = runner.directory/(name[1:]+'.bnt')
        path.write_text(marked_text+main)
        process = subprocess.run([str(cli), 'run', '--diagnostics=json', '--allow-effects=Console.Write', str(path)],
                                 capture_output=True, text=True, timeout=30)
        (runner.directory/(name[1:]+'.stdout')).write_text(process.stdout)
        (runner.directory/(name[1:]+'.stderr')).write_text(process.stderr.replace(str(runner.directory), '<tmp>'))
        runs.append(dict(definition=name, **spec, **compare_run(process, spec, site, path)))
    # 正しい観測の値・到達・コード・ファイル・位置を壊し、誤った一致を拒否する。
    negatives = []
    for field in ['value', 'reach', 'failureCode', 'failureFile', 'failurePosition', 'wrapperPosition']:
        name = '.shiftIntegerLeftzero' if field == 'value' else (
            '.shiftInteger64Leftwidth' if field == 'wrapperPosition' else '.shiftIntegerLeftwidth')
        path = runner.directory/(name[1:]+'.bnt')
        stdout = path.with_suffix('.stdout').read_text()
        stderr = path.with_suffix('.stderr').read_text().replace('<tmp>', str(runner.directory))
        diagnostics = [json.loads(line) for line in stderr.splitlines()]
        if field == 'value': stdout = stdout.replace('VALUE:-1', 'VALUE:0')
        elif field == 'reach': stdout = stdout.replace('REACH:', 'BROKEN:', 1)
        else:
            error, = [d for d in diagnostics if d['severity'] == 'error']
            if field == 'failureCode': error['code'] = 'R0102'
            elif field == 'failureFile': error['primary']['file'] = 'stdlib/Integer.bnt'
            else: error['primary']['start']['offset'] += 1
            stderr = '\n'.join(json.dumps(d) for d in diagnostics)
        process = subprocess.CompletedProcess([], 0 if field == 'value' else 1, stdout, stderr)
        site, = [s for s in sites if s['key'][0] == name]
        try:
            compare_run(process, specs[name], site, path)
        except AssertionError:
            negatives.append(field)
        else:
            raise AssertionError(('bad shift observation accepted', field))
    # 未同定の標準callを、字面だけで閉じた比較へ通さない。
    try:
        vm.require_closed(entries['.shiftIntegerLeftwidth'], original['standards'], [], fixed_domain=True)
    except AssertionError as error:
        assert 'unknown call' in str(error)
        negatives.append('unidentifiedShift')
    else:
        raise AssertionError('unidentified shift accepted')
    summary = dict(kind='interval-shift-vm-comparison', declarations=27, vmRuns=len(runs),
                   compared=46, independentOnly=62, evaluationExcluded=dict(unknownFailure=46, notClosedOrFuel=16),
                   wrapperDeclarations=7, wrapperOutsideRuns=14, operations=len(sites), runs=runs,
                   sites=sites, negativeCases=negatives)
    (runner.directory/'shift-vm-summary.json').write_text(json.dumps(summary, indent=2)+'\n')
    return summary
