"""元の Surface の閉じた算術・フローを、標識付きソースの実 CLI と比較する。"""
import copy
import json
import os
import subprocess
from pathlib import Path

import interval_source_compare as source


def concrete(kind, value):
    return {('integer' if kind == 'Integer' else 'boolean' if kind == 'Boolean' else kind):
            value if kind == 'Boolean' else str(value)}


# 値・失敗・到達順は手計算。キーは元ソースの式の位置から選ぶ。
# 組は (元の式の字面, 正常に得た引数, 正常値または失敗種)。
SPECS = {
    'addition': (10, [('8 + 2', [8, 2], 10)]),
    'overflow': ('overflow', [('9223372036854775807 + 1', [2**63-1, 1], 'overflow')]),
    'division': ('zeroDivisor', [('8 div 0', [8, 0], 'zeroDivisor')]),
    'remainder': ('zeroDivisor', [('8 mod 0', [8, 0], 'zeroDivisor')]),
    'subtraction': (-10, [('-7 - 3', [-7, 3], -10)]),
    'multiply': (-21, [('-7 * 3', [-7, 3], -21)]),
    'negation': ('overflow', [('-minimum', [-2**63], 'overflow')]),
    'divisionOverflow': ('overflow', [('-9223372036854775808 div -1', [-2**63, -1], 'overflow')]),
    'moduloMinimum': (0, [('-9223372036854775808 mod -1', [-2**63, -1], 0)]),
    'childFailure': ('overflow', [('9223372036854775807 + 1', [2**63-1, 1], 'overflow')]),
    'rightFailure': ('zeroDivisor', [('1 + 1', [1, 1], 2), ('8 div 0', [8, 0], 'zeroDivisor')]),
    'shortAnd': (False, []), 'shortOr': (True, []),
    'longAnd': (True, [('8 div 2', [8, 2], 4), ('8 div 2 = 4', [4, 4], True)]),
    'longOr': (True, [('8 div 2', [8, 2], 4), ('8 div 2 = 4', [4, 4], True)]),
    'branch': (10, [('2 < 3', [2, 3], True), ('9 + 1', [9, 1], 10)]),
    'shadowed': (5, [('value + 4', [3, 4], 7), ('value - 2', [7, 2], 5)]),
    'guarded': (6, [('n * 2', [3, 2], 6)]),
    'returned': (9, [('7 + 2', [7, 2], 9)]),
    'signed8': ('overflow', [('127s8 + 1s8', [127, 1], 'overflow')]),
    'signed16': ('overflow', [('-32768s16 - 1s16', [-32768, 1], 'overflow')]),
    'signed32': ('overflow', [('-value', [-2**31], 'overflow')]),
    'unsigned16': ('overflow', [('65535u16 * 2u16', [65535, 2], 'overflow')]),
    'unsigned32': ('overflow', [('0u32 - 1u32', [0, 1], 'overflow')]),
    'unsigned64': ('overflow', [('18446744073709551615u64 * 2u64', [2**64-1, 2], 'overflow')]),
    'widthValue': (2**63-1, [('18446744073709551615u64 div 2u64', [2**64-1, 2], 2**63-1)]),
}


for label, suffix in [('integer', ''), ('s8', 's8'), ('s16', 's16'), ('s32', 's32'),
                      ('u16', 'u16'), ('u32', 'u32'), ('u64', 'u64')]:
    addition = f'6{suffix} + 2{suffix}'
    product = f'({addition}) * 3{suffix}'
    difference = f'{product} - 4{suffix}'
    quotient = f'({difference}) div 2{suffix}'
    SPECS['matrix'+label] = (1, [(addition, [6, 2], 8), (product, [8, 3], 24),
                               (difference, [24, 4], 20), (quotient, [20, 2], 10),
                               (quotient+f' mod 3{suffix}', [10, 3], 1)])
for label, op, result in [('equal', '=', False), ('unequal', '<>', True), ('less', '<', True),
                          ('lessEqual', '<=', True), ('greater', '>', False), ('greaterEqual', '>=', False)]:
    SPECS['compare'+label] = (result, [(f'2 {op} 3', [2, 3], result)])


def evaluation(definition, sites, text):
    name = definition['name']
    answer, events = SPECS[name[1:]]
    kind = definition['type']['base']['name']
    outcome = {'failed': answer} if isinstance(answer, str) else {'returned': concrete(kind, answer)}
    trace = []
    for fragment, arguments, result in events:
        matches = [s for s in sites if s['key'][0] == name and text[s['span'][1]:s['span'][2]] == fragment]
        assert len(matches) == 1, (name, fragment, matches)
        site = matches[0]
        expr = site['expression']
        ty = expr['binary']['operand'] if 'binary' in expr else expr['neg']['operand']
        operation = dict(binary=expr['binary']['op'], type=ty) if 'binary' in expr else dict(neg=ty)
        own = ty['base']['name']
        result_kind = 'Boolean' if isinstance(result, bool) else own
        trace.append(dict(key=site['key'], operation=operation,
            arguments=[concrete(own, n) for n in arguments],
            result={'failed': result} if isinstance(result, str) else {'normal': concrete(result_kind, result)}))
    return dict(outcome=outcome, trace=trace)


def marker(expr):
    if not isinstance(expr, dict) or 'call' not in expr:
        return None
    call = expr['call']
    if call['callee'] != {'primName': dict(name='Benitoite.IO.Console.writeLine', tys=[], effs=[])}:
        return None
    assert call['positions'] == [0] and call['labels'] == [None]
    return call['args'][0]['literal']['value']['string']['value']


def normalize(value, env=()):
    """追加した束縛だけを代入して除き、元の束縛・分岐・演算の構造を照合する。"""
    if isinstance(value, list):
        return [normalize(v, env) for v in value]
    if not isinstance(value, dict):
        return value
    if 'local' in value:
        return env[-1-value['local']['index']]
    if 'paren' in value:
        return normalize(value['paren']['inner'], env)
    if 'block' in value:
        block, local, bound = value['block']['body'], list(env), []
        while isinstance(block, dict) and 'bind' in block:
            b = block['bind']
            bound.append(normalize(b['expr'], local))
            local.append(bound[-1])
            block = b['rest']
        if isinstance(block, dict) and 'seq' in block and marker(block['seq']['expr']):
            # 比較専用blockの正規形。通常のbindを誤って除かない。
            assert len(bound) in (1, 2, 3) and set(block['seq']['rest']) == {'last'}
            op = block['seq']['rest']['last']['expr']
            operands = (op['call']['args'] if 'call' in op else
                        [op['binary']['lhs'], op['binary']['rhs']] if 'binary' in op else [op['neg']['inner']])
            assert operands == [{'local': {'index': n}} for n in reversed(range(len(bound)))]
            return normalize(op, local)
    if 'bind' in value:
        b = value['bind']
        return {'bind': dict(b, expr=normalize(b['expr'], env),
            rest=normalize(b['rest'], (*env, {'bound': len(env)})))}
    if 'mk' in value and 'alts' in value['mk']:
        arm = value['mk']
        sizes = {len(alt['slots']) for alt in arm['alts']}
        assert len(sizes) == 1
        local = (*env, *({'bound': len(env)+n} for n in range(next(iter(sizes)))))
        return {'mk': dict(arm, guard=normalize(arm['guard'], local), body=normalize(arm['body'], local))}
    return {k: normalize(v, env) for k, v in value.items()}


def connect_sites(sites, marked_manifest, marked_text):
    entries = source.correspondence(marked_manifest)
    result = []
    for site in sites:
        name, key = site['key']
        rows = entries[name]
        calls = [r for r in rows if marker(r['expression']) == site['marker']]
        assert len(calls) == 1
        call = calls[0]
        operations = [r for r in rows if r['span'] is not None and
                      marked_text[r['span'][1]:r['span'][2]] == site['operationText']]
        assert len(operations) == 1
        op = operations[0]
        assert int(call['preorder']) < int(op['preorder']) and key != op['preorder']
        result.append(dict(site, instrumentedKey=[name, op['preorder']], operationSpan=op['span'], markerSpan=call['span']))
    return result


def require_closed(entries, standards=(), api_at=(), fixed_domain=False):
    """未評価の枝も含め、具体規則を持つ今回の小さい対象だけを受け入れる。"""
    leaves = {'integer', 'integer8', 'integer16', 'integer32', 'unsignedInteger16',
              'unsignedInteger32', 'unsignedInteger64', 'boolean'}
    forms = {'block', 'returnE', 'local', 'paren', 'neg', 'negInt', 'negInteger8',
             'negInteger16', 'negInteger32', 'literal', 'binary', 'and', 'or', 'not',
             'ite', 'elseIf', 'ifOnly', 'matchE'}
    registered = {s['declaration']: s for s in standards
                  if set(s['rule']) <= ({'rangeCheck', 'rangeValue', 'fixedDomain'} if fixed_domain
                                        else {'rangeCheck', 'rangeValue'})}
    calls = {s['key'][1]: s['declaration'] for s in api_at}
    for entry in entries:
        expr = entry['expression']
        if isinstance(expr, dict) and 'call' in expr:
            declaration = calls.get(entry['preorder'])
            assert declaration in registered, ('unknown call', expr)
            head = expr['call']['callee']
            allowed = ('funName', 'primName') if 'fixedDomain' in registered[declaration]['rule'] else ('funName',)
            assert any(head == {tag: dict(name=declaration, tys=[], effs=[])} for tag in allowed)
            continue
        if isinstance(expr, dict) and set(expr) <= {'funName', 'primName'}:
            parent = entries[int(entry['parent'])]
            assert 'call' in parent['expression'] and parent['preorder'] in calls, ('unknown syntax', expr)
            assert parent['expression']['call']['callee'] == expr
            continue
        assert isinstance(expr, dict) and len(expr) == 1 and set(expr) <= forms, ('unknown syntax', expr)
        if 'literal' in expr:
            assert set(expr['literal']['value']) <= leaves, ('unknown literal', expr)
        if 'binary' in expr:
            binary = expr['binary']
            assert binary['op'] in {'add', 'sub', 'mul', 'intDiv', 'mod', 'eq', 'ne', 'lt', 'le', 'gt', 'ge'}
            assert binary['operand']['base']['name'] in source.KINDS
        if 'neg' in expr:
            assert expr['neg']['operand']['base']['name'] in {'Integer', 'Integer8', 'Integer16', 'Integer32'}


class MarkerFailure(Exception):
    pass


def compare_run(process, expected, sites, rendered=None):
    diagnostics = [json.loads(line) for line in process.stderr.splitlines()]
    errors = [d for d in diagnostics if d['severity'] == 'error']
    lines = process.stdout.splitlines()
    reached = ['REACH:'+e['key'][0]+':'+e['key'][1] for e in expected['trace']]
    if errors:
        assert len(errors) == 1
        error = errors[0]
        if error['kind'] == 'runtime' and error['code'] == 'R0201':
            assert process.returncode == 1
            raise MarkerFailure(error['code'])
        span = error['primary']
        position = [span['start']['offset'], span['end']['offset']]
        if any(position == s['markerSpan'][1:] for s in sites):
            raise MarkerFailure(error['code'])
        assert error['kind'] == 'runtime'
        failure = {'R0101': 'zeroDivisor', 'R0102': 'overflow', 'R0701': 'outsideDomain'}[error['code']]
        assert expected['outcome'] == {'failed': failure}
        assert process.returncode == 1 and lines == reached, (lines, reached)
        final = expected['trace'][-1]
        site = next(s for s in sites if s['key'] == final['key'])
        assert position == site['operationSpan'][1:], (position, site)
    else:
        assert process.returncode == 0 and 'failed' not in expected['outcome']
        if rendered is None:
            value = next(iter(expected['outcome'].get('returned', expected['outcome'].get('normal')).values()))
            rendered = str(value).lower() if isinstance(value, bool) else value
        assert lines == reached+['VALUE:'+rendered], (lines, reached, rendered)
    return dict(reached=reached, exit=process.returncode, errors=[d['code'] for d in errors])


def exercise(runner, directory, cli):
    directory, cli = Path(directory).resolve(), Path(cli).resolve()
    original = source.read(directory/'original/interval-material.json')['inputs'][0]
    manifest = source.read(directory/'original/interval-manifest.json')['inputs'][0]
    observed = source.read(directory/'original/interval-observations.json')['inputs'][0]
    marked = source.read(directory/'instrumented/interval-material.json')['inputs'][0]
    marked_manifest = source.read(directory/'instrumented/interval-manifest.json')['inputs'][0]
    text, marked_text = (directory/'original.bnt').read_text(), (directory/'instrumented.bnt').read_text()
    sites = source.read(directory/'vm-sites.json')['sites']
    sites = connect_sites(sites, marked_manifest, marked_text)
    definitions = source.unique([d for m in original['modules'] for d in m['definitions']], 'name')
    marked_defs = source.unique([d for m in marked['modules'] for d in m['definitions']], 'name')
    assert set(definitions) == set(marked_defs) == {'.'+name for name in SPECS}
    entries = source.correspondence(manifest)
    obs = source.unique([b for b in observed['bodies'] if b.get('kind') != 'whole'], 'definition')
    for name, definition in definitions.items():
        require_closed(entries[name])
        assert normalize(definition['body']) == normalize(marked_defs[name]['body']), (name, 'instrumentation structure')
        assert obs[name]['coverage'] == 'Prepared' and not obs[name]['unsupported'], (name, 'unknown excluded')
        definition['expected'] = source.expectation(obs[name], entries[name], {})
        definition['evaluation'] = evaluation(definition, sites, text)
        # 実ソースの関数本体は Unit で検査され、return が宣言の戻り値を返す。
        # 既存の材料は宣言の戻り型を根に置く。評価専用の包みだけを、本体の型へ戻す。
        # 本文・子の型・元キーは保ち、解析の比較用の材料は書き換えない。
        unit = {'base': {'name': 'Unit'}}
        tail = definition['body']
        while 'bind' in tail:
            tail = tail['bind']['rest']
        assert tail['last']['expr']['returnE']['ret'] == unit
        assert any(e['expression'] == tail['last']['expr'] and e['type'] == unit for e in entries[name])
        definition['type'] = unit
        definition['types'][0]['type'] = unit
    for site in sites:
        row = entries[site['key'][0]][int(site['key'][1])]
        assert row['span'] == site['span'] and row['expression'] == site['expression'] and row['acquired']
    corpus = dict(kind='interval-corpus', version=1, surfaceVersion=14, traversalVersion=1,
                  profile='domain', inputs=[original])
    report = runner.invoke('vm-closed', 'eval', corpus, 0)
    assert report['comparedCount'] == str(len(SPECS)) and report['excludedCount'] == '0'
    rows = source.unique(report['inputs'][0]['bodies'], 'definition')
    runs = []
    for name, definition in definitions.items():
        assert rows[name]['comparisonEligible'] and rows[name]['matched']
        main = f'\nfunction main() -> Unit uses Console.Write\n Console.writeLine("VALUE:${{{name[1:]}()}}")\nend function\n'
        path = runner.directory/(name[1:]+'.bnt')
        path.write_text(marked_text+main)
        command = [str(cli), 'run', '--diagnostics=json', '--allow-effects=Console.Write', str(path)]
        process = subprocess.run(command, capture_output=True, text=True, timeout=30)
        (runner.directory/(name[1:]+'.stdout')).write_text(process.stdout)
        (runner.directory/(name[1:]+'.stderr')).write_text(process.stderr.replace(str(runner.directory), '<tmp>'))
        result = compare_run(process, rows[name]['actual'], sites)
        runs.append(dict(definition=name, **result))
    # 実際に閉じたpipeへ書き、標識出力の失敗を算術の失敗と数えない。
    read_fd, write_fd = os.pipe()
    os.close(read_fd)
    try:
        process = subprocess.run([str(cli), 'run', '--diagnostics=json', str(runner.directory/'addition.bnt')],
                                 stdout=write_fd, stderr=subprocess.PIPE, text=True, timeout=30)
    finally:
        os.close(write_fd)
    process.stdout = ''
    (runner.directory/'marker-failure.stderr').write_text(process.stderr.replace(str(runner.directory), '<tmp>'))
    try:
        compare_run(process, definitions['.addition']['evaluation'], sites)
    except MarkerFailure as error:
        marker_failure = str(error)
    else:
        raise AssertionError('Console.Write failure accepted')
    # 正しいVM観測の標識・失敗位置・最終値だけを壊し、比較の拒否を確かめる。
    negatives = []
    changed = copy.deepcopy(marked_defs['.addition']['body'])
    def corrupt(value):
        if isinstance(value, dict):
            if 'binary' in value:
                value['binary']['op'] = 'sub'
                return True
            return any(corrupt(child) for child in value.values())
        return any(corrupt(child) for child in value) if isinstance(value, list) else False
    assert corrupt(changed)
    assert normalize(changed) != normalize(definitions['.addition']['body'])
    negatives.append('instrumentationStructure')
    changed = copy.deepcopy(entries['.shortAnd'])
    changed[-1]['expression'] = {'funName': dict(name='unmodeled', tys=[], effs=[])}
    try:
        require_closed(changed)
    except AssertionError as error:
        assert 'unknown syntax' in str(error)
        negatives.append('unknownInSkippedBranch')
    else:
        raise AssertionError('unknown in skipped branch accepted')
    for field in ['reach', 'value', 'failurePosition']:
        name = '.addition' if field != 'failurePosition' else '.childFailure'
        stderr = (runner.directory/(name[1:]+'.stderr')).read_text()
        stdout = (runner.directory/(name[1:]+'.stdout')).read_text()
        if field == 'reach': stdout = stdout.replace('REACH:', 'BROKEN:', 1)
        if field == 'value': stdout = stdout.replace('VALUE:10', 'VALUE:11')
        if field == 'failurePosition':
            diagnostics = [json.loads(l) for l in stderr.splitlines()]
            next(d for d in diagnostics if d['severity'] == 'error')['primary']['start']['offset'] += 1
            stderr = '\n'.join(json.dumps(d) for d in diagnostics)
        broken = subprocess.CompletedProcess([], 0 if name == '.addition' else 1, stdout, stderr)
        try: compare_run(broken, definitions[name]['evaluation'], sites)
        except AssertionError: negatives.append(field)
        else: raise AssertionError(('bad observation accepted', field))
    summary = dict(kind='interval-vm-comparison', compared=len(runs), excluded=0,
                   operations=len(sites), runs=runs, markerFailureExcluded=marker_failure, negativeCases=negatives,
                   sites=sites)
    (runner.directory/'vm-summary.json').write_text(json.dumps(summary, indent=2)+'\n')
    return summary
