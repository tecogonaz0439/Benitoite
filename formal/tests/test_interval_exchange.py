#!/usr/bin/env python3
"""独立期待値と実CLIでinterval-corpusの全profileを検査する。

先にformal/でintervalDiffをビルドする。Leanはここから起動しない。
--output DIRを指定すれば固定入力・報告・選択したfuelを保存する。
--source-dir DIRはdesugar_exportの実ソースの型・演算・元位置の交換を検査する。
この入力は全体操作上限0で未着手を期待し、解析の一致件数へ加えない。
--rust-dir DIR は全関係定義を通常予算で Rust/Lean 間比較する（複数指定可）。
--vm-dir DIR は閉じた算術・フローの元キー付き標識と実 CLI を比較する。
手計算の独立期待区間・trace・消費と、実ソースの差分比較は別に記録する。
"""
from pathlib import Path
import argparse
import copy
import json
import gzip
import shutil
import subprocess
import tempfile

FORMAL = Path(__file__).resolve().parents[1]
INTEGER = {'base': {'name': 'Integer'}}
BOOLEAN = {'base': {'name': 'Boolean'}}
ZERO = {'body': {'operations': '0', 'temporary': '0', 'saved': '0', 'peak': '0'},
        'whole': {'operations': '0', 'saved': '0', 'peak': '0'}}
LIMITS = {'body': {'operations': '100000', 'items': '100000'},
          'whole': {'operations': '1000000', 'items': '1000000'}}


def integer(n):
    return {'literal': {'value': {'integer': {'value': n}}}}


def boolean(b):
    return {'literal': {'value': {'boolean': {'value': b}}}}


def binary(op, lhs, rhs):
    return {'binary': {'op': op, 'operand': INTEGER, 'lhs': lhs, 'rhs': rhs}}


def last(expr):
    return {'last': {'expr': expr}}


def interval(lo, hi=None):
    return {'closed': [str(lo), str(lo if hi is None else hi)]}


def after(operations, saved, peak):
    return dict(body=copy.deepcopy(ZERO['body']),
                whole=dict(operations=str(operations), saved=str(saved), peak=str(peak)))


def operation(op):
    return {'neg': INTEGER} if op == 'neg' else {'binary': op, 'type': INTEGER}


def warning(name, key, op, cause):
    return dict(key=[name, str(key)], operation=operation(op), cause=cause)


def event(name, key, op, args, outcome):
    return dict(key=[name, str(key)], operation=operation(op),
                arguments=[{'integer': str(n)} for n in args], result=outcome)


def normal(n):
    return {'normal': {'integer': str(n)}}


def expected(rng, cost, warnings=(), boolean_range=(False, False), other=False,
             may_fail=False, coverage='complete'):
    return dict(integer=rng, boolean=list(boolean_range), other=other, mayFail=may_fail,
                warnings=list(warnings), coverage=coverage, after=after(*cost))


def context(name, body_ops, body_saved, body_peak, whole_ops, whole_saved, whole_peak, next_key, unsupported=False):
    return dict(budget=dict(body=dict(operations=str(body_ops), temporary='0', saved=str(body_saved), peak=str(body_peak)),
                            whole=dict(operations=str(whole_ops), saved=str(whole_saved), peak=str(whole_peak))),
                next=[name, str(next_key)], identities=[[name, str(i)] for i in range(next_key)],
                unsupported=unsupported)


def definition(label, body, types, sources, expect, evaluation):
    name = 'M.' + label
    if 'context' not in expect:
        whole = expect['after']['whole']
        ops, saved, peak = (int(whole[k]) for k in ('operations', 'saved', 'peak'))
        expect['context'] = context(name, max(0, ops-1), saved, peak, ops, 0, peak, len(types),
                                    expect['coverage'] == 'unsupported')
    return dict(name=name, kind='function', params=[], type=types[0], body=body,
                types=[dict(key=[name, str(i)], type=ty) for i, ty in enumerate(types)],
                sourceKeys=[[name, str(i)] for i in sources], expected=expect,
                evaluation=evaluation)


def input_of(d):
    return dict(name=d['name'], fuel='0', limits=copy.deepcopy(LIMITS),
                initial=copy.deepcopy(ZERO), constants=[], standards=[], apiAt=[],
                modules=[dict(name='M', definitions=[d])])


def input_expected(state, phases=(), skipped=0, definitions=1):
    return dict(after=state, phaseStops=list(phases),
                counts=dict(inputDefinitions=str(definitions), unsupportedBodies='0',
                            bodyBudgetExceeded='0', unidentifiedBodies='0', wholeBudgetSkipped=str(skipped)))


def corpus(profile, definitions):
    return dict(kind='interval-corpus', version=1, surfaceVersion=14,
                traversalVersion=1, profile=profile, inputs=[input_of(d) for d in definitions])


def fixtures():
    # 消費表はD16の単位の手計算。各inputは新しい共有状態から始まる。
    # 空引数の準備は本体2操作。N式は2N操作・N対応、Block.lastは1操作。
    # moduleの1操作をwholeへ足す。終了時はbodyが0へ戻る。
    # 保持は出力枠1、保存した対応、同時に生きる作業枠、警告だけを数える。
    base = []
    for label, n in [('point', 42), ('minimum', -(2**63)), ('maximum', 2**63-1)]:
        ex = expected(interval(n), (8, 3, 7))
        # 終了前の操作数と次番号も独立に固定し、afterのリセットで隠さない。
        ex['context'] = dict(budget=dict(body=dict(operations='7', temporary='0', saved='3', peak='7'),
                                        whole=dict(operations='8', saved='0', peak='7')),
                             next=['M.'+label, '2'],
                             identities=[['M.'+label, '0'], ['M.'+label, '1']], unsupported=False)
        base.append(definition(label, last(integer(n)), [INTEGER]*2, [], ex,
                               dict(outcome=normal(n), trace=[])))
    for label, op, a, b, rng, outcome, cause in [
        ('addition', 'add', 8, 2, interval(10), normal(10), None),
        ('overflow', 'add', 2**63-1, 1, 'bottom', {'failed': 'overflow'}, 'overflow'),
        ('division', 'intDiv', 8, 0, 'top', {'failed': 'zeroDivisor'}, 'zeroDivisor'),
        ('remainder', 'mod', 8, 0, 'top', {'failed': 'zeroDivisor'}, 'zeroDivisor')]:
        name = 'M.'+label
        warnings = [warning(name, 1, op, cause)] if cause else []
        base.append(definition(label, last(binary(op, integer(a), integer(b))), [INTEGER]*4, [1],
                               expected(rng, (12, 5+bool(cause), 10+bool(cause)), warnings, may_fail=bool(cause)),
                               dict(outcome=outcome, trace=[event(name, 1, op, [a, b], outcome)])))
    name = 'M.negation'
    base.append(definition('negation', last({'neg': {'operand': INTEGER, 'inner': integer(-(2**63))}}),
                           [INTEGER]*3, [1], expected('bottom', (10, 5, 10),
                           [warning(name, 1, 'neg', 'overflow')], may_fail=True),
                           dict(outcome={'failed': 'overflow'}, trace=[event(name, 1, 'neg', [-(2**63)], {'failed': 'overflow'})])))
    flow = []
    flow.append(definition('returned', last({'returnE': {'ret': INTEGER, 'inner': integer(7)}}),
                           [INTEGER]*3, [], expected('bottom', (10, 4, 9)),
                           dict(outcome={'returned': {'integer': '7'}}, trace=[])))
    for label, op, a, b in [('shortAnd', 'and', False, True), ('shortOr', 'or', True, False)]:
        flow.append(definition(label, last({op: dict(lhs=boolean(a), rhs=boolean(b))}), [BOOLEAN]*4, [],
                               expected('bottom', (12, 5, 11), boolean_range=(not a, a)),
                               dict(outcome={'normal': {'boolean': a}}, trace=[])))
    flow.append(definition('branch', last({'ite': dict(cond=boolean(True), yes=last(integer(9)), no=last(integer(10)))}),
                           [INTEGER, INTEGER, BOOLEAN, INTEGER, INTEGER], [],
                           expected(interval(9), (16, 6, 13)), dict(outcome=normal(9), trace=[])))
    body = last(integer(99))
    for n in reversed(range(24)):
        body = {'discard': dict(expr=integer(n), rest=body)}
    # 列が24要素増えると操作は72、保存は24、最大保持は48増える。
    flow.append(definition('sequence', body, [INTEGER]*26, [],
                           expected(interval(99), (80, 27, 55)), dict(outcome=normal(99), trace=[])))
    name = 'M.order'
    body = last(binary('add', binary('add', integer(1), integer(1)),
                       binary('intDiv', integer(1), integer(0))))
    flow.append(definition('order', body, [INTEGER]*8, [1, 2, 5],
                           expected(interval(-(2**63)+2, 2**63-1), (20, 10, 16),
                                    [warning(name, 5, 'intDiv', 'zeroDivisor')], may_fail=True),
                           dict(outcome={'failed': 'zeroDivisor'}, trace=[
                               event(name, 2, 'add', [1, 1], normal(2)),
                               event(name, 5, 'intDiv', [1, 0], {'failed': 'zeroDivisor'})])))
    name = 'M.childFailure'
    flow.append(definition('childFailure', last(binary('intDiv',
                           binary('add', integer(2**63-1), integer(1)), integer(0))),
                           [INTEGER]*6, [1, 2], expected('bottom', (15, 8, 13),
                           [warning(name, 2, 'add', 'overflow')], may_fail=True),
                           dict(outcome={'failed': 'overflow'}, trace=[
                               event(name, 2, 'add', [2**63-1, 1], {'failed': 'overflow'})])))
    # 未対応の親から子の正常値・候補を戻さず、保存した各入力で比較する。
    name = 'M.independent'
    ex = expected('top', (16, 10, 16), boolean_range=(True, True), other=True,
                  may_fail=True, coverage='unsupported')
    ex['independent'] = [dict(key=[name, '2'], integer='top', boolean=[False, False], other=False,
                             warnings=[warning(name, 2, 'intDiv', 'zeroDivisor')], coverage='complete'),
                         dict(key=[name, '5'], integer=interval(9), boolean=[False, False], other=False,
                             warnings=[], coverage='complete')]
    flow.append(definition('independent', last({'pipe': dict(lhs=binary('intDiv', integer(8), integer(0)),
                                                            rhs=integer(9))}),
                           [INTEGER]*6, [2], ex, {'excluded': 'notClosedOrFuel'}))
    lazy_type = {'lazyT': {'elem': INTEGER}}
    flow.append(definition('lazy', last({'lazyE': {'body': last(integer(9))}}),
                           [lazy_type, lazy_type, INTEGER], [],
                           expected('top', (10, 4, 10), boolean_range=(True, True), other=True,
                                    may_fail=True, coverage='unsupported'), {'excluded': 'notClosedOrFuel'}))
    result = [corpus('base', base), corpus('flow', flow)]
    result[1]['inputs'][-1]['expectedBodies'] = [dict(definition='M.lazy%body:1:0',
                                                   expected=expected(interval(9), (26, 9, 13)))]
    ex = result[1]['inputs'][-1]['expectedBodies'][0]['expected']
    ex['context'] = context('M.lazy%body:1:0', 6, 3, 7, 26, 6, 13, 2)
    return result


WIDTHS = [('Integer8', -128, 127), ('Integer16', -32768, 32767),
          ('Integer32', -(2**31), 2**31-1), ('UnsignedInteger16', 0, 65535),
          ('UnsignedInteger32', 0, 2**32-1), ('UnsignedInteger64', 0, 2**64-1)]
REQUIRED_PROFILES = ['base', 'flow', 'width', 'range', 'domain']


def extended(ex, own=None, rng='bottom', unknown=False):
    ex['widths'] = {name: ('top' if unknown else rng if name == own else 'bottom') for name, _, _ in WIDTHS}
    ex['nonIntegerOther'] = unknown or ex['other'] and own is None
    for child in ex.get('independent', []):
        extended(child, unknown=child['other'] and child['integer'] == 'top')
    return ex


def typed_literal(name, value):
    return {'literal': {'value': {name[0].lower()+name[1:]: {'value': value}}}}


def typed_normal(name, value):
    return {'normal': {name: str(value)}}


def call(declaration, args, labels, positions, primitive=False):
    return {'call': dict(callee={('primName' if primitive else 'funName'):
                                dict(name=declaration, tys=[], effs=[])},
                         labels=labels, positions=positions, args=args)}


def standard_input(d, standards, sites):
    value = input_of(d)
    value['standards'] = standards
    value['apiAt'] = [dict(key=[d['name'], str(key)], declaration=declaration) for key, declaration in sites]
    return value


def extra_fixtures():
    width = []
    for name, lo, hi in WIDTHS:
        ty = {'base': {'name': name}}
        for suffix, n in [('min', lo), ('max', hi)]:
            ex = extended(expected('bottom', (8, 3, 7), other=True), name, interval(n))
            width.append(definition(name+suffix, last(typed_literal(name, n)), [ty]*2, [], ex,
                                    dict(outcome=typed_normal(name, n), trace=[])))
        for op, a, b, result, cause in [('add', hi, 1, None, 'overflow'),
                                       ('sub', lo, 1, None, 'overflow'),
                                       ('mul', hi, 0, 0, None),
                                       ('mul', hi, hi, None, 'overflow')]:
            label = name+op+('zero' if b == 0 else '')
            own_op = dict(binary=op, type=ty)
            warns = [dict(key=['M.'+label, '1'], operation=own_op, cause=cause)] if cause else []
            ex = extended(expected('bottom', (12, 5+bool(cause), 10+bool(cause)), warns,
                                   other=result is not None, may_fail=bool(cause)), name,
                          interval(result) if result is not None else 'bottom')
            outcome = {'failed': cause} if cause else typed_normal(name, result)
            width.append(definition(label, last({'binary': dict(op=op, operand=ty,
                                    lhs=typed_literal(name, a), rhs=typed_literal(name, b))}), [ty]*4, [1], ex,
                                    dict(outcome=outcome, trace=[dict(key=['M.'+label, '1'], operation=own_op,
                                         arguments=[{name: str(a)}, {name: str(b)}], result=outcome)])))
    for name, lo, _ in WIDTHS[:3]:
        ty = {'base': {'name': name}}
        label = name+'negateMinimum'
        own = {'neg': ty}
        outcome = {'failed': 'overflow'}
        ex = extended(expected('bottom', (10, 5, 10),
                      [dict(key=['M.'+label, '1'], operation=own, cause='overflow')], may_fail=True))
        width.append(definition(label, last({'neg': dict(operand=ty, inner=typed_literal(name, lo))}),
                                [ty]*3, [1], ex, dict(outcome=outcome, trace=[dict(key=['M.'+label, '1'],
                                operation=own, arguments=[{name: str(lo)}], result=outcome)])))
    for op, a, b, value in [('sub', 8, 3, 5), ('mul', -(2**63), -1, None)]:
        label = 'Integer64'+op
        cause = 'overflow' if value is None else None
        outcome = {'failed': cause} if cause else normal(value)
        width.append(definition(label, last(binary(op, integer(a), integer(b))), [INTEGER]*4, [1],
                                extended(expected('bottom' if cause else interval(value),
                                  (12, 5+bool(cause), 10+bool(cause)),
                                  [warning('M.'+label, 1, op, cause)] if cause else [], may_fail=bool(cause))),
                                dict(outcome=outcome, trace=[event('M.'+label, 1, op, [a, b], outcome)])))
    # 全てのprofileに非Topの独立期待がある。base/flowの期待は変更しない。
    width_corpus = corpus('width', width)
    domain = corpus('domain', [])
    shift_types = [('Integer', INTEGER, 64, True), ('Integer64', INTEGER, 64, False),
                    ('UnsignedInteger', {'base': {'name': 'UnsignedInteger64'}}, 64, False),
                    ('UnsignedInteger8', {'base': {'name': 'Byte'}}, 8, False)] + [
        (name, {'base': {'name': name}}, (hi+1).bit_length()-1 if lo == 0 else (hi+1).bit_length(), True)
        for name, lo, hi in WIDTHS] + [('Byte', {'base': {'name': 'Byte'}}, 8, True)]
    for module, ty, bits, primitive in shift_types:
        for direction in (['left', 'right', 'rightUnsigned'] if module.startswith('Integer') else ['left', 'right']):
            suffix_name = dict(left='shiftLeft', right='shiftRight', rightUnsigned='shiftRightUnsigned')[direction]
            declaration = 'resolved:'+module+'.'+suffix_name
            binding = dict(declaration=declaration, name='Benitoite.'+module+'.'+suffix_name, argumentTypes=[ty, INTEGER],
                           rule={'fixedDomain': dict(operand=ty, direction=direction)})
            for suffix, amount, reverse in [('negative', -1, False), ('width', bits, True),
                                            ('inside0', 0, False), ('insideLast', bits-1, False)]:
                label = module+suffix_name+suffix
                outside = amount < 0 or amount >= bits
                warns = [dict(key=['M.'+label, '1'], operation={'standard': declaration}, cause='outsideDomain')] if outside else []
                cost = (45 if reverse else 43, 6+outside, 14 if reverse else 13)
                ex = extended(expected('bottom' if outside else 'top', cost, warns,
                                       boolean_range=(not outside, not outside), other=not outside, may_fail=True), unknown=not outside)
                operand = integer(1) if ty == INTEGER else (typed_literal(ty['base']['name'], 1) if ty['base']['name'] != 'Byte'
                                                           else {'literal': {'value': {'byte': {'value': 1}}}})
                args = [integer(amount), operand] if reverse else [operand, integer(amount)]
                types = [ty, ty, {'fn': dict(names=['a', 'n'], params=[ty, INTEGER], ret=ty, eff=[])}] + ([INTEGER, ty] if reverse else [ty, INTEGER])
                source = call(declaration, args, ['n', 'a'] if reverse else [None, None], [1, 0] if reverse else [0, 1], primitive)
                outcome = {'failed': 'outsideDomain'}
                def cv():
                    if ty == INTEGER: return {'integer': '1'}
                    if ty['base']['name'] == 'Byte': return {'other': ty}
                    return {ty['base']['name']: '1'}
                ev = dict(outcome=outcome, trace=[dict(key=['M.'+label, '1'], operation={'standard': declaration},
                          arguments=[cv(), {'integer': str(amount)}], result=outcome)]) if outside else {'excluded': 'unknownFailure'}
                if ty['base']['name'] == 'Byte':
                    ex['coverage'] = 'unsupported'
                    ev = {'excluded': 'notClosedOrFuel'}
                d = definition(label, last(source), types, [1], ex, ev)
                domain['inputs'].append(standard_input(d, [binding], [(1, declaration)]))
    names = dict(owner='data:checked', checkedConstructor='con:checked:record', result='data:result', error='data:error',
                 ok='con:result:ok', err='con:result:error', invalidBounds='con:error:invalid', outOfRange='con:error:outside')
    record = dict(fields=['minimum', 'maximum', 'value'], data=names['owner'], ntys=0, args=[INTEGER]*3)
    result_ty = {'data': dict(name=names['result'], args=[{'data': dict(name=names['owner'], args=[])},
                                                       {'data': dict(name=names['error'], args=[])}])}
    check = dict(declaration='fn:check', name='Benitoite.Range.checkInteger', argumentTypes=[INTEGER]*3,
                 rule={'rangeCheck': dict(names, record=record)})
    def con(owner, name, args, types=()):
        return {'con': dict(owner=owner, types=list(types), name=name, args=args)}
    range_corpus = corpus('range', [])
    # Resultとtrace内の包む前の三欄/拒否を別々の期待として指定する。
    for label, lo, hi, n in [('rangeOk', 0, 10, 5), ('rangePoint', 7, 7, 7),
                              ('rangeReversed', 10, 0, 100), ('rangeOutside', 0, 10, 11),
                              ('rangeMinimum', -(2**63), -(2**63), -(2**63))]:
        payload = con(names['owner'], names['checkedConstructor'], [{'integer': str(x)} for x in (lo, hi, n)])
        rejection = {'invalidBounds': [str(lo), str(hi)]} if hi < lo else {'outOfRange': [str(lo), str(hi), str(n)]}
        rejected = hi < lo or n < lo or n > hi
        result = con(names['result'], names['err' if rejected else 'ok'],
                     [{'rangeError': dict(owner=names['error'], name=names['invalidBounds' if hi < lo else 'outOfRange'], error=rejection)}]
                     if rejected else [payload], result_ty['data']['args'])
        # checkIntegerを単独で解析した正常値は未知。比較の非Topは別の整数本体で確保する。
        ex = extended(expected('top', (37, 7, 15), boolean_range=(True, True), other=True, may_fail=True), unknown=True)
        source = call('fn:check', [integer(n), integer(hi), integer(lo)], ['value', 'maximum', 'minimum'], [2, 1, 0])
        d = definition(label, last(source), [result_ty, result_ty, {'fn': dict(names=['minimum', 'maximum', 'value'],
                       params=[INTEGER]*3, ret=result_ty, eff=[])}]+[INTEGER]*3, [1], ex,
                       dict(outcome={'normal': result}, trace=[dict(key=['M.'+label, '1'], operation={'standard': 'fn:check'},
                            arguments=[{'integer': str(x)} for x in (lo, hi, n)],
                            result={'failed': rejection} if rejected else {'normal': payload})]))
        range_corpus['inputs'].append(standard_input(d, [check], [(1, 'fn:check')]))
    checked_ty = {'data': dict(name=names['owner'], args=[])}
    value_binding = dict(declaration='fn:value', name='Benitoite.Range.value', argumentTypes=[checked_ty],
                         rule={'rangeValue': dict(owner=names['owner'], constructor=names['checkedConstructor'], record=record)})
    raw = call('fn:check', [integer(5), integer(10), integer(0)], ['value', 'maximum', 'minimum'], [2, 1, 0])
    project = call('fn:value', [{'local': {'index': 0}}], ['value'], [0])
    source = {'matchE': dict(ret=INTEGER, scrutinee=raw, arms=[{'mk': dict(
        alts=[dict(pat={'con': dict(name=names['ok'], args=['var'])}, slots=[0])], guard=None, body=last(project))}])}
    payload = con(names['owner'], names['checkedConstructor'], [{'integer': str(x)} for x in (0, 10, 5)])
    types = [INTEGER, INTEGER, result_ty,
             {'fn': dict(names=['minimum', 'maximum', 'value'], params=[INTEGER]*3, ret=result_ty, eff=[])},
             INTEGER, INTEGER, INTEGER, INTEGER,
             {'fn': dict(names=['value'], params=[checked_ty], ret=INTEGER, eff=[])}, checked_ty]
    d = definition('rangeProjection', last(source), types, [2, 7],
                   extended(expected(interval(0, 10), (129, 11, 24), may_fail=True)),
                   dict(outcome=normal(5), trace=[
                       dict(key=['M.rangeProjection', '2'], operation={'standard': 'fn:check'},
                            arguments=[{'integer': str(x)} for x in (0, 10, 5)], result={'normal': payload}),
                       dict(key=['M.rangeProjection', '7'], operation={'standard': 'fn:value'},
                            arguments=[payload], result=normal(5))]))
    range_corpus['inputs'].append(standard_input(d, [check, value_binding], [(2, 'fn:check'), (7, 'fn:value')]))
    sentinel = definition('rangeSentinel', last(integer(7)), [INTEGER]*2, [],
                          extended(expected(interval(7), (8, 3, 7))), dict(outcome=normal(7), trace=[]))
    range_corpus['inputs'].append(input_of(sentinel))
    return [width_corpus, range_corpus, domain]


def definition_rows(c):
    return [d for i in c['inputs'] for m in i['modules'] for d in m['definitions']]


def selected_fuel(c):
    # typesは根を含む全出現を入力として独立に列挙している。
    return 4 * sum(len(d['types']) for d in definition_rows(c)) + 32


def set_fuel(c, value):
    for i in c['inputs']:
        i['fuel'] = str(value)


class Runner:
    def __init__(self, directory, executable):
        self.directory, self.executable, self.calls = directory, executable, 0

    def invoke(self, label, mode, c, code, contains=None):
        source, report = self.directory/(label+'.json'), self.directory/(label+'.report.json')
        source.write_text(c if isinstance(c, str) else json.dumps(c, ensure_ascii=False, separators=(',', ':')))
        p = subprocess.run([str(self.executable), mode, str(source), str(report)],
                           text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=30)
        self.calls += 1
        (self.directory/(label+'.stdout')).write_text(p.stdout)
        # IO失敗のメッセージにも一時パスを残さない。
        (self.directory/(label+'.stderr')).write_text(p.stderr.replace(str(self.directory), '<tmp>'))
        assert p.returncode == code, (label, p.returncode, code, p.stdout, p.stderr)
        value = json.loads(report.read_text())
        # 実ソースの再入力は material と観測から作る複写であり、圧縮して保存する。
        # Lean へ渡す内容は変えず、再現に必要な全文も残す。
        if label.startswith('source-analysis-'):
            with source.open('rb') as raw, source.with_suffix('.json.gz').open('wb') as target:
                with gzip.GzipFile(filename='', mode='wb', fileobj=target, mtime=0) as saved:
                    shutil.copyfileobj(raw, saved)
            source.unlink()
        if contains:
            assert contains in json.dumps(value), (label, contains, value)
        return value


def tagged_nodes(value, tag):
    """容器の深い位置も含め、交換済みの構成子を探す。番号は付け直さない。"""
    if isinstance(value, dict):
        if tag in value:
            yield value[tag]
        for child in value.values():
            yield from tagged_nodes(child, tag)
    elif isinstance(value, list):
        for child in value:
            yield from tagged_nodes(child, tag)


def exercise_source(runner, directory):
    # 関門: 実Surfaceと通常解析の対応をLeanの厳密な読者まで渡す。
    # 六入口にはない標準表・元演算キー・全型表の欠落を検出する。
    # 全解析の期待値を観測から作らず、未着手と停止の独立期待だけを照合する。
    source = json.loads((directory/'reader-corpus.json').read_text())
    records = json.loads((directory/'correspondence.json').read_text())
    assert len(source['inputs']) == len(records) and records
    r = runner.invoke('source-reader', 'analyze', source, 1, 'allTop')
    assert r['matched'] and not r['accepted'] and r['comparedCount'] == '0'
    assert r['excludedCount'] == '0' and r['phaseDepthCount'] == '0'
    point = json.loads((directory/'point.json').read_text())
    accepted = runner.invoke('source-point', 'analyze', point, 0)
    assert accepted['matched'] and accepted['accepted']
    assert accepted['informativeCount'] == '1'
    assert len(r['inputs']) == len(records)
    arithmetic, declarations, heads = set(), set(), dict(primName=0, funName=0)
    target_count = occurrences = synthetic = 0
    for inp, record, report in zip(source['inputs'], records, r['inputs']):
        d = inp['modules'][0]['definitions'][0]
        assert d['name'] == record['name']
        entries = record['correspondence']
        assert report['bodies'] == [] and report['mismatches'] == []
        assert report['counts']['wholeBudgetSkipped'] == '1'
        assert report['unproducedBodies'][0]['mismatches'] == []
        assert [row['key'] for row in d['types']] == [[d['name'], e['preorder']] for e in entries]
        assert all(e['acquired'] for e in entries)
        assert entries[0]['sourceStatus'] == 'syntheticBodyRoot'
        assert entries[0]['node'] is None and entries[0]['span'] is None
        occurrences += len(entries)
        synthetic += 1
        for key in d['sourceKeys']:
            e = entries[int(key[1])]
            assert e['node'] is not None and e['span'] is not None
            expr = e['expression']
            if 'binary' in expr:
                arithmetic.add((expr['binary']['operand']['base']['name'], expr['binary']['op']))
            elif 'neg' in expr:
                arithmetic.add((expr['neg']['operand']['base']['name'], 'neg'))
            else:
                assert 'call' in expr
            target_count += 1
        if record['input'] == 'shifts':
            assert len(inp['apiAt']) == 1
            entry = entries[int(inp['apiAt'][0]['key'][1])]
            head = entry['expression']['call']['callee']
            kind = next(iter(head))
            assert kind in heads
            heads[kind] += 1
            declaration = inp['apiAt'][0]['declaration']
            assert head[kind]['name'] == declaration
            binding = next(s for s in inp['standards'] if s['declaration'] == declaration)
            declarations.add(binding['name'])
    expected_ops = {'add', 'sub', 'mul', 'intDiv', 'mod', 'eq', 'ne', 'lt', 'le', 'gt', 'ge'}
    expected_arithmetic = {(ty, op) for ty in ['Integer']+[w[0] for w in WIDTHS] for op in expected_ops}
    expected_arithmetic |= {(ty, 'neg') for ty in ['Integer', 'Integer8', 'Integer16', 'Integer32']}
    assert arithmetic == expected_arithmetic
    assert len(declarations) == 27 and heads == dict(primName=40, funName=14)
    # X01aの合成節点と多対一を、実ソースから得た対応で確かめる。
    for label, tag in [('spread', 'ListSpread'), ('interpolation', 'Interpolation'), ('with', 'With')]:
        rows = [e for rec in records if rec['input'] == label for e in rec['correspondence']]
        assert any(e['form'] == tag for e in rows)
        mapped = [e for e in rows if e['node'] is not None]
        if label == 'with':
            assert sum(e['form'] == 'With' for e in rows) == 2
        else:
            assert len({e['node'] for e in mapped}) < len(mapped), label
    operations = [e['expression'] for rec in records if rec['input'] == 'heads' for e in rec['correspondence']]
    assert any('primName' in e for e in operations) and any('opName' in e for e in operations)
    assert any('funName' in e for e in operations)
    # 通常の深さで通った同じ交換を一箇所ずつ壊す。深さ停止は負例の成功にしない。
    # 版・全型表・元キー・宣言表だけでなく、合成式と節の中の未知欄も拒否する。
    for tag in ['withE', 'interpolation', 'listSpread', 'lam', 'lazyE', 'handleE', 'matchE', 'constName']:
        changed = copy.deepcopy(source)
        node = next(tagged_nodes(changed['inputs'], tag))
        node['futureField'] = True
        runner.invoke('source-deep-'+tag, 'analyze', changed, 2, 'noncanonical Surface fields or constructor')
    for tag, child in [('interpolation', 'converters'), ('listSpread', 'concat'), ('handleE', 'clauses')]:
        changed = copy.deepcopy(source)
        node = next(tagged_nodes(changed['inputs'], tag))
        nested = (next(tagged_nodes(node[child][0]['body'], 'last'))['expr'] if tag == 'handleE'
                  else node[child][0] if isinstance(node[child], list) else node[child])
        nested.clear()
        nested['futureConstructor'] = {}
        runner.invoke('source-constructor-'+tag, 'analyze', changed, 2, 'unknown Expr constructor')
    for label, mutate, reason in [
        ('version', lambda c: c.update(traversalVersion=2), 'version'),
        ('type-duplicate', lambda c: definition_rows(c)[-1]['types'].append(copy.deepcopy(definition_rows(c)[-1]['types'][-1])), 'duplicate type key'),
        ('type-missing', lambda c: definition_rows(c)[-1]['types'].pop(), 'type correspondence'),
        ('comparison-missing', lambda c: next(d for d in definition_rows(c) if d['name'].endswith('.arithmeticeq'))['sourceKeys'].clear(), 'target correspondence'),
        ('api-missing', lambda c: next(i for i in c['inputs'] if i['name'].startswith('shifts:'))['apiAt'].clear(), 'target correspondence'),
        ('source-missing', lambda c: next(d for d in definition_rows(c) if d['sourceKeys'])['sourceKeys'].pop(), 'target correspondence'),
        ('source-duplicate', lambda c: next(d for d in definition_rows(c) if d['sourceKeys'])['sourceKeys'].append(copy.deepcopy(next(d for d in definition_rows(c) if d['sourceKeys'])['sourceKeys'][0])), 'duplicate source key'),
        ('type-number', lambda c: definition_rows(c)[-1]['types'][-1]['key'].__setitem__(1, '01'), 'decimal'),
        ('type-field', lambda c: definition_rows(c)[-1]['types'][-1].update(extra=True), 'typed key'),
    ]:
        changed = copy.deepcopy(source)
        mutate(changed)
        runner.invoke('source-invalid-'+label, 'analyze', changed, 2, reason)
    # 生のJSONで深い重複欄を渡し、dict化で失われる前に拒否させる。
    raw = json.dumps(source)
    needle = '"traversalVersion": 1'
    assert needle in raw
    runner.invoke('source-duplicate-header', 'analyze', raw.replace(needle, needle+', "traversalVersion": 1', 1), 2, 'duplicate')
    needle = '"index": 0'
    assert needle in raw
    runner.invoke('source-duplicate-deep', 'analyze', raw.replace(needle, needle+', "index": 0', 1), 2, 'duplicate')
    summary = dict(readerInputs=len(records), readerOccurrences=occurrences, sourceTargets=target_count,
                   arithmeticKinds=len(arithmetic), shiftDeclarations=len(declarations), shiftHeads=heads,
                   syntheticRoots=synthetic, analyzedProbeBodies=0, acceptedPointBodies=1)
    (runner.directory/'source-summary.json').write_text(json.dumps(summary, indent=2)+'\n')
    print(json.dumps(summary))


def exercise_profiles(runner, corpora):
    width, ranges, domain = corpora[2:]
    for label, original, mutate, mode, code, reason in [
        ('width-value', width, lambda c: definition_rows(c)[0]['expected']['widths'].update(Integer8=interval(-127)), 'analyze', 1, 'widths'),
        ('width-other', width, lambda c: definition_rows(c)[0]['expected'].update(nonIntegerOther=True), 'analyze', 1, 'nonIntegerOther'),
        ('missing-widths', width, lambda c: definition_rows(c)[0]['expected'].pop('widths'), 'analyze', 2, 'widths'),
        ('width-endpoint', width, lambda c: definition_rows(c)[0]['expected']['widths'].update(UnsignedInteger64=interval(2**64)), 'analyze', 2, 'endpoints'),
        ('width-type', width, lambda c: definition_rows(c)[0]['expected']['warnings'].append(warning('M.Integer8min', 1, 'neg', 'overflow')), 'analyze', 2, 'operation mismatch'),
        ('concrete-width', width, lambda c: definition_rows(c)[0]['evaluation']['outcome']['normal'].update(Integer8='128'), 'eval', 2, 'outside range'),
        ('record-declaration', ranges, lambda c: c['inputs'][0]['standards'][0]['rule']['rangeCheck']['record'].update(args=[INTEGER]*2), 'analyze', 2, 'record declaration'),
        ('range-deep-field', ranges, lambda c: c['inputs'][0]['standards'][0]['rule']['rangeCheck'].update(extra=True), 'analyze', 2, 'Range names'),
        ('range-identity', ranges, lambda c: c['inputs'][-2]['standards'][1]['rule']['rangeValue'].update(constructor='wrong'), 'analyze', 2, 'inconsistent Range'),
        ('range-constructor', ranges, lambda c: definition_rows(c)[0]['evaluation']['outcome']['normal']['con']['args'][0]['con'].update(name='wrong'), 'eval', 1, 'evaluation'),
        ('range-payload', ranges, lambda c: definition_rows(c)[0]['evaluation']['outcome']['normal']['con']['args'][0]['con']['args'][2].update(integer='6'), 'eval', 1, 'evaluation'),
        ('range-payload-field', ranges, lambda c: definition_rows(c)[0]['evaluation']['outcome']['normal']['con']['args'][0]['con']['args'][2].update(extra=True), 'eval', 2, 'concrete value'),
        ('range-rejection', ranges, lambda c: definition_rows(c)[2]['evaluation']['trace'][0]['result']['failed'].update(invalidBounds=['10', '01']), 'eval', 2, 'decimal'),
        ('range-precision', ranges, lambda c: definition_rows(c)[-2]['expected'].update(integer=interval(0, 9)), 'analyze', 1, 'integer'),
        ('standard-operation', domain, lambda c: c['inputs'][0]['standards'][0].update(name='Benitoite.Process.exit'), 'analyze', 2, 'false standard'),
        ('standard-http', domain, lambda c: c['inputs'][0]['standards'][0].update(rule={'httpField': dict(status='200')}), 'analyze', 2, 'standard rule'),
        ('standard-signature', domain, lambda c: c['inputs'][0]['standards'][0].update(argumentTypes=[INTEGER, BOOLEAN]), 'analyze', 2, 'argument type'),
        ('standard-duplicate', domain, lambda c: c['inputs'][0]['standards'].append(copy.deepcopy(c['inputs'][0]['standards'][0])), 'analyze', 2, 'duplicate standard'),
        ('standard-role', domain, lambda c: c['inputs'][0]['standards'].append(dict(copy.deepcopy(c['inputs'][0]['standards'][0]), declaration='another')), 'analyze', 2, 'standard role'),
        ('api-duplicate', domain, lambda c: c['inputs'][0]['apiAt'].append(copy.deepcopy(c['inputs'][0]['apiAt'][0])), 'analyze', 2, 'duplicate API'),
        ('api-absent', domain, lambda c: c['inputs'][0]['apiAt'][0].update(declaration='missing'), 'analyze', 2, 'correspondence'),
        ('api-missing', domain, lambda c: c['inputs'][0]['apiAt'].clear(), 'analyze', 2, 'correspondence'),
        ('api-extra', domain, lambda c: c['inputs'][0]['apiAt'][0].update(extra=True), 'analyze', 2, 'api occurrence'),
        ('api-key', domain, lambda c: c['inputs'][0]['apiAt'][0].update(key=['M.missing', '1']), 'analyze', 2, 'correspondence'),
        ('standard-source', domain, lambda c: definition_rows(c)[0]['sourceKeys'].clear(), 'analyze', 2, 'correspondence'),
        ('standard-warning', domain, lambda c: definition_rows(c)[0]['expected']['warnings'][0]['operation'].update(standard='missing'), 'analyze', 2, 'standard operation'),
        ('standard-trace', domain, lambda c: definition_rows(c)[0]['evaluation']['trace'][0]['arguments'].reverse(), 'eval', 1, 'evaluation'),
        ('standard-warning-mismatch', domain, lambda c: definition_rows(c)[0]['expected']['warnings'].clear(), 'analyze', 1, 'warnings'),
    ]:
        changed = copy.deepcopy(original)
        mutate(changed)
        runner.invoke('profile-'+label, mode, changed, code, reason)
    # typed/effsを持つ頭、操作の頭は、同定表のある直接callにはならない。
    for kind in ['typed', 'effectful', 'operation']:
        changed = copy.deepcopy(domain)
        head = definition_rows(changed)[0]['body']['last']['expr']['call']['callee']
        if kind == 'operation':
            value = head.pop('primName')
            head['opName'] = dict(name=value['name'], tys=[])
        else:
            head['primName']['tys' if kind == 'typed' else 'effs'] = [INTEGER] if kind == 'typed' else [{'name': {'value': 'Console.Write'}}]
        runner.invoke('profile-head-'+kind, 'analyze', changed, 2)
    # 幅付きの全域だけを返す別本体を、Integer64欄のbottomだけで非Topと数えない。
    ty = {'base': {'name': 'Integer8'}}
    lazy = {'lazyT': {'elem': ty}}
    d = definition('lazyWidthTop', last({'lazyE': {'body': last({'local': {'index': 0}})}}),
                   [lazy, lazy, ty], [], extended(expected('top', (0, 0, 0), other=True), unknown=True),
                   {'excluded': 'parameters'})
    d['params'] = [ty]
    c = corpus('width', [d])
    set_fuel(c, 128)
    # 予算・結果の未指定は意図した不一致。ここでは報告のTop分類だけを観察する。
    c['inputs'][0]['expectedBodies'] = [dict(definition='M.lazyWidthTop%body:1:0',
        expected=extended(expected('bottom', (0, 0, 0), other=True), 'Integer8', 'top'))]
    r = runner.invoke('profile-embedded-width-top', 'analyze', c, 1)
    child = r['inputs'][0]['bodies'][1]['actual']
    assert child['widths']['Integer8'] == 'top' and child['integer'] == 'bottom'
    assert r['informativeCount'] == '0' and 'allTop' in r['acceptanceReasons']
    # 独立入力の幅欄も実際の解析との比較に含む。
    independent = copy.deepcopy(corpora[1])
    independent['profile'] = 'width'
    independent['inputs'] = [independent['inputs'][7]]
    extended(definition_rows(independent)[0]['expected'], unknown=True)
    runner.invoke('profile-width-independent', 'analyze', independent, 1, 'allTop')
    # 親が全Topでも独立入力の期待との一致自体は保つ。
    value = json.loads((runner.directory/'profile-width-independent.report.json').read_text())
    assert value['matched'] and value['informativeCount'] == '0'
    definition_rows(independent)[0]['expected']['independent'][1]['widths']['Integer8'] = interval(1)
    runner.invoke('profile-width-independent-mismatch', 'analyze', independent, 1, 'independent')


def exercise_entry_modules(runner, base):
    # 実CLI境界で、空名の入口と名前付きの対照の両方を照合する。
    point = copy.deepcopy(base)
    point['inputs'] = point['inputs'][:1]
    raw = json.dumps(point).replace('"name": "M"', '"name": ""').replace('M.point', '.point')
    entry = json.loads(raw)
    for label, c in [('entry', entry), ('named', point)]:
        r = runner.invoke('module-'+label, 'analyze', c, 0)
        assert r['matched'] and r['accepted']
        assert r['inputs'][0]['bodies'][0]['definition'] == ('.point' if label == 'entry' else 'M.point')
    method = json.loads(raw.replace('.point', '%impl:2:1:point'))
    r = runner.invoke('module-entry-method', 'analyze', method, 0)
    assert r['matched'] and r['accepted']
    # 先頭の入口に続く名前付きモジュールを許す。空列でも後続の空名は拒否する。
    library = dict(name='Library', definitions=[])
    empty = dict(name='', definitions=[])
    mixed = copy.deepcopy(entry)
    mixed['inputs'][0]['modules'].append(library)
    # 本体の after/context は後続モジュールの前なので変わらない。
    r = runner.invoke('module-entry-library', 'analyze', mixed, 0)
    assert r['matched'] and r['accepted']
    for label, c, modules, reason in [
        ('later-empty', point, [library, empty], 'invalid module name'),
        ('duplicate-empty', entry, [empty], 'invalid module name'),
        ('duplicate-named', point, [dict(name='M', definitions=[])], 'duplicate module'),
    ]:
        changed = copy.deepcopy(c)
        changed['inputs'][0]['modules'].extend(modules)
        runner.invoke('module-'+label, 'analyze', changed, 2, reason)
    for label, replacement in [('missing-declaration', '.'), ('wrong-owner', 'Other.point')]:
        runner.invoke('module-'+label, 'analyze', raw.replace('.point', replacement), 2,
                      'definition name does not match module')
    changed = copy.deepcopy(entry)
    definition_rows(changed)[0]['types'][0]['key'][0] = 'M.point'
    runner.invoke('module-stale-key', 'analyze', changed, 2, 'type correspondence')


def exercise(directory, executable, source_dir=None, rust_dirs=(), vm_dir=None, cli=None):
    runner = Runner(directory, executable)
    if vm_dir is not None:
        import interval_vm_compare
        output = directory/'vm'
        output.mkdir()
        vm_runner = Runner(output, executable)
        interval_vm_compare.exercise(vm_runner, vm_dir, cli)
        import interval_range_vm
        range_output = output/'range'
        range_output.mkdir()
        range_runner = Runner(range_output, executable)
        interval_range_vm.exercise(range_runner, Path(vm_dir)/'range', cli)
        vm_runner.calls += range_runner.calls
        import interval_shift_vm
        shift_output = output/'shifts'
        shift_output.mkdir()
        shift_runner = Runner(shift_output, executable)
        interval_shift_vm.exercise(shift_runner, Path(vm_dir)/'shifts', cli)
        vm_runner.calls += shift_runner.calls
        runner.calls += vm_runner.calls
    if source_dir is not None:
        exercise_source(runner, source_dir)
    if rust_dirs:
        import interval_source_compare
        summaries = []
        for index, rust_dir in enumerate(rust_dirs):
            output = directory/('real-source-'+str(index))
            output.mkdir()
            source_runner = Runner(output, executable)
            summaries.append(interval_source_compare.exercise(source_runner, rust_dir))
            runner.calls += source_runner.calls
        (directory/'real-source-summary.json').write_text(json.dumps(summaries, indent=2)+'\n')
    corpora, selections = fixtures()+extra_fixtures(), []
    manifests = []
    for c in corpora:
        start = selected_fuel(c)
        fuel, attempts = start, []
        # 深さ停止を理由に全コーパスを再実行する。選んだ同じfuelを全本体と発見へ渡す。
        for attempt in range(8):
            set_fuel(c, fuel)
            probe_label = c['profile']+'-analyze-'+str(attempt)
            # 初回は0を期待する。深さ停止があった場合だけ非0を許し、他の不一致を隠さない。
            source = directory/(probe_label+'.input.json')
            report = directory/(probe_label+'.report.json')
            source.write_text(json.dumps(c))
            p = subprocess.run([str(executable), 'analyze', str(source), str(report)],
                               capture_output=True, text=True, timeout=30)
            runner.calls += 1
            result = json.loads(report.read_text())
            attempts.append(dict(fuel=str(fuel), exit=p.returncode,
                                 excluded=result.get('excludedCount'), matched=result.get('matched')))
            assert 'excludedCount' in result, (probe_label, result)
            if result['excludedCount'] == '0' and result['phaseDepthCount'] == '0':
                assert result.get('matched'), (probe_label, result)
                assert p.returncode == 0 and result['accepted'], (probe_label, result)
                break
            fuel *= 2
        else:
            raise AssertionError('fuel selection did not close; report exclusions')
        selections.append(dict(profile=c['profile'], initial=str(start), selected=str(fuel), attempts=attempts))
        assert result['initialFuel'] == str(start)
        assert result['comparedCount'] == str(len(definition_rows(c)) + sum(len(i.get('expectedBodies', [])) for i in c['inputs']))
        assert all(i['phaseDepthCount'] == '0' for i in result['inputs'])
        evaluated = runner.invoke(c['profile']+'-eval', 'eval', c, 0)
        for mode, report in [('analyze', result), ('eval', evaluated)]:
            manifest = report['profileManifest']
            assert manifest['requiredProfiles'] == REQUIRED_PROFILES
            assert manifest['profile'] == c['profile']
            assert manifest['definitionCount'] == str(len(definition_rows(c)))
            assert manifest['comparedCount'] == report['comparedCount']
            assert manifest['excludedCount'] == report['excludedCount']
            assert int(manifest['comparedCount']) > 0
            manifests.append(dict(mode=mode, **manifest))
    assert {row['profile'] for row in manifests} == set(REQUIRED_PROFILES)
    (directory/'profile-manifest.json').write_text(json.dumps(dict(requiredProfiles=REQUIRED_PROFILES,
        profiles=manifests, rustAnalysisCompared=False, vmCompared=False), indent=2)+'\n')
    exercise_profiles(runner, corpora)
    (directory/'fuel-selection.json').write_text(json.dumps(selections, indent=2)+'\n')
    base, flow = corpora[:2]
    exercise_entry_modules(runner, base)
    # 期待値の不一致は読者の拒否と分け、1にする。
    for label, path, value, field in [
        ('range', ['expected', 'integer'], interval(41), 'integer'),
        ('cost', ['expected', 'after', 'whole', 'operations'], '9', 'after'),
        ('context', ['expected', 'context', 'budget', 'body', 'peak'], '8', 'context'),
        ('unknown-reason', ['expected', 'coverage'], 'unsupported', 'coverage'),
        ('eval-value', ['evaluation', 'outcome'], normal(41), 'evaluation')]:
        changed = copy.deepcopy(base)
        d = definition_rows(changed)[0]
        for key in path[:-1]:
            d = d[key]
        d[path[-1]] = value
        runner.invoke('mismatch-'+label, 'eval' if label.startswith('eval') else 'analyze', changed, 1, field)
    # mayFailは観測専用であり、不一致や拒否にしない。
    changed = copy.deepcopy(base)
    definition_rows(changed)[0]['expected']['mayFail'] = True
    runner.invoke('may-fail-observation', 'analyze', changed, 0)
    for label, change, reason in [
        ('version', lambda c: c.update(version=2), 'version'),
        ('profile', lambda c: c.update(profile='future'), 'profile'),
        ('deep-extra', lambda c: definition_rows(c)[0]['body']['last']['expr']['literal']['value']['integer'].update(extra=True), 'Surface'),
        ('missing-key', lambda c: definition_rows(c)[0]['types'].pop(), 'correspondence'),
        ('nondecimal', lambda c: c['inputs'][0].update(fuel='01'), 'decimal'),
        ('bad-endpoint', lambda c: definition_rows(c)[0]['expected'].update(integer={'closed': ['2', '1']}), 'endpoints'),
        ('deep-eval', lambda c: definition_rows(c)[0]['evaluation']['outcome']['normal'].update(extra=1), 'concrete value'),
        ('deep-context', lambda c: definition_rows(c)[0]['expected']['context'].update(extra=1), 'context')]:
        changed = copy.deepcopy(base)
        change(changed)
        runner.invoke('invalid-'+label, 'analyze', changed, 2, reason)
    raw = json.dumps(base).replace('"value": 42', '"value": 42, "value": 43', 1)
    runner.invoke('invalid-duplicate', 'analyze', raw, 2, 'duplicate JSON field')
    # 警告のキー・原因、traceの順序・親の未到達は実入力を通して照合する。
    for label, change in [
        ('warning', lambda c: definition_rows(c)[4]['expected']['warnings'].clear()),
        ('independent', lambda c: definition_rows(c)[7]['expected']['independent'][0]['warnings'].clear()),
        ('embedded', lambda c: c['inputs'][8]['expectedBodies'][0]['expected'].update(integer=interval(10))),
        ('trace-order', lambda c: definition_rows(c)[5]['evaluation']['trace'].reverse()),
        ('trace-parent', lambda c: definition_rows(c)[6]['evaluation']['trace'].append(
            event('M.childFailure', 1, 'intDiv', [1, 0], {'failed': 'zeroDivisor'})))]:
        changed = copy.deepcopy(base if label == 'warning' else flow)
        change(changed)
        runner.invoke('mismatch-'+label, 'analyze' if label in ('warning', 'independent', 'embedded') else 'eval', changed, 1)
    # 空と全Topはmatchedでも受け入れへ進めない。
    empty = corpus('base', [])
    for mode in ('analyze', 'eval'):
        r = runner.invoke('empty-'+mode, mode, empty, 1, 'emptyComparison')
        assert r['matched'] and not r['accepted']
    unknown = definition('unknown', last({'funName': dict(name='User.value', tys=[], effs=[])}),
                         [INTEGER]*2, [], expected('top', (8, 3, 7), boolean_range=(True, True),
                         other=True, may_fail=True, coverage='unsupported'), {'excluded': 'notClosedOrFuel'})
    only_top = corpus('base', [unknown])
    set_fuel(only_top, selected_fuel(only_top))
    r = runner.invoke('all-top', 'analyze', only_top, 1, 'allTop')
    assert r['matched'] and r['inputs'][0]['counts']['unsupportedBodies'] == '1'
    runner.invoke('all-excluded-eval', 'eval', only_top, 1, 'notClosedOrFuel')
    # Unitの全正常値を、Integerのbottomだけで非Topと数えない（RV-C5中1）。
    unit = {'base': {'name': 'Unit'}}
    d = definition('unitTop', last('unit'), [unit]*2, [],
                   expected('bottom', (8, 3, 7), other=True),
                   dict(outcome={'normal': 'unit'}, trace=[]))
    only_unit = corpus('base', [d])
    set_fuel(only_unit, selected_fuel(only_unit))
    r = runner.invoke('all-top-unit', 'analyze', only_unit, 1, 'allTop')
    assert r['matched'] and r['informativeCount'] == '0' and not r['accepted']
    # unknownの失敗を選んでも、実行比較件数へ加えない。
    # 空の腕列は交換の境界の入力であり、通常checkerの受理を主張しない。
    unknown_failure = definition('unknownFailure', last({'matchE': dict(ret=INTEGER, scrutinee=integer(1), arms=[])}),
                                 [INTEGER]*3, [], expected('bottom', (0, 0, 0)), {'excluded': 'unknownFailure'})
    changed = copy.deepcopy(base)
    changed['inputs'].append(input_of(unknown_failure))
    set_fuel(changed, selected_fuel(changed))
    r = runner.invoke('unknown-failure-eval', 'eval', changed, 0, 'unknownFailure')
    assert r['comparedCount'] == '8' and r['excludedCount'] == '1'
    assert r['inputs'][-1]['bodies'][0]['observed']['outcome'] == {'failed': 'unknown'}
    # パラメータ付き本体を空環境で実行せず、比較の除外を明示する。
    changed = copy.deepcopy(base)
    d = definition_rows(changed)[0]
    d['params'], d['evaluation'] = [INTEGER], {'excluded': 'parameters'}
    r = runner.invoke('parameters-eval', 'eval', changed, 0, 'parameters')
    assert r['comparedCount'] == '7' and r['excludedCount'] == '1'
    # 本体の深さ停止を他本体へ広げず、段停止も残す。
    shallow = copy.deepcopy(definition_rows(base)[0])
    deep = copy.deepcopy(shallow)
    deep['name'] = 'M.deep'
    expr = integer(1)
    for _ in range(8):
        expr = {'paren': {'inner': expr}}
    deep = definition('deep', last(expr), [INTEGER]*10, [], expected('top', (0, 0, 0)),
                      {'excluded': 'notClosedOrFuel'})
    depth = corpus('base', [shallow])
    depth['inputs'][0]['modules'][0]['definitions'].append(deep)
    set_fuel(depth, 4)
    r = runner.invoke('depth-bodies', 'analyze', depth, 1, 'depthExclusions')
    rows = r['inputs'][0]['bodies']
    assert [b['comparisonEligible'] for b in rows] == [True, False]
    assert r['inputs'][0]['phaseDepthCount'] != '0' and r['comparedCount'] == '1'
    # 入れ子の深さだけでなく、Blockの列の長さでもfuelを使い切る。
    short = copy.deepcopy(flow)
    short['inputs'] = [short['inputs'][4]]
    set_fuel(short, 8)
    r = runner.invoke('depth-sequence', 'analyze', short, 1, 'depth')
    assert r['excludedCount'] != '0'
    # 操作数で止まる二位置を区別する。拒否した操作は消費しない。
    for cap, kind, next_key, spent, saved, peak in [(2, 'unidentified', 0, 3, 1, 3),
                                                  (3, 'exceeded', 1, 4, 2, 4)]:
        changed = copy.deepcopy(base)
        target = changed['inputs'][1]
        target['limits']['body']['operations'] = str(cap)
        d = target['modules'][0]['definitions'][0]
        d['expected'] = expected('top', (spent, saved, peak), boolean_range=(True, True), other=True,
                                 coverage={'stopped': dict(kind=kind, scope='body', resource='operations')})
        d['expected']['context'] = context(d['name'], cap, saved, peak, spent, 0, peak, next_key)
        # 発見は親の操作数を引き継ぎ、最初の番号取得に失敗して次番号0を保つ。
        # 待ち行列作成も同じ本体予算を引き継ぐため、作業枠でexceededになる。
        target['expected'] = input_expected(after(spent, saved, peak), [
            dict(definition=d['name'], phase='discovery',
                 reason=dict(kind='unidentified', scope='body', resource='operations'),
                 next=[d['name'], '0'], context=context(d['name'], cap, saved, peak, spent, 0, peak, 0)),
            dict(definition=d['name'], phase='queue',
                 reason=dict(kind='exceeded', scope='body', resource='operations'),
                 next=[d['name'], '0'], afterDefinition=after(spent, saved, peak))])
        target['expected']['counts']['unidentifiedBodies'] = str(int(kind == 'unidentified'))
        target['expected']['counts']['bodyBudgetExceeded'] = str(int(kind == 'exceeded'))
        r = runner.invoke('body-budget-'+str(cap), 'analyze', changed, 0)
        row = r['inputs'][1]
        assert row['bodies'][0]['actual']['context']['next'][1] == str(next_key)
        assert row['counts']['unidentifiedBodies'] == str(int(kind == 'unidentified'))
        assert row['counts']['bodyBudgetExceeded'] == str(int(kind == 'exceeded'))
        assert row['phaseStops'] and row['excludedCount'] == '0'
        for label, mutate, code, reason in [
            ('position', lambda t: t['expected']['phaseStops'][0].update(next=[d['name'], '1']), 1, 'phaseStops'),
            ('order', lambda t: t['expected']['phaseStops'].reverse(), 1, 'phaseStops'),
            ('context', lambda t: t['expected']['phaseStops'][0]['context']['budget']['body'].update(peak=str(peak+1)), 1, 'phaseStops'),
            ('deep-extra', lambda t: t['expected']['phaseStops'][0]['context'].update(extra=True), 2, 'context'),
            ('unknown-phase', lambda t: t['expected']['phaseStops'][0].update(phase='future'), 2, 'stop phase'),
            ('nondecimal-key', lambda t: t['expected']['phaseStops'][1].update(next=[d['name'], '01']), 2, 'decimal')]:
            mismatch = copy.deepcopy(changed)
            mutate(mismatch['inputs'][1])
            r = runner.invoke('body-budget-'+str(cap)+'-'+label, 'analyze', mismatch, code, reason)
            if code == 1:
                assert not r['matched']
    # 全体上限の未着手は本体の停止件数へ重ねず、元入力を残す。
    for cap in (0, 1):
        changed = copy.deepcopy(base)
        target = changed['inputs'][1]
        target['limits']['whole']['operations'] = str(cap)
        # 古い正常値の期待を残した入力は、未着手の期待と一致しない。
        r = runner.invoke('whole-budget-old-'+str(cap), 'analyze', changed, 1, 'notAnalyzed')
        assert not r['matched'] and r['inputs'][1]['unproducedBodies'][0]['mismatches'] == ['notAnalyzed']
        stop = dict(kind='exceeded', scope='whole', resource='operations')
        target['modules'][0]['definitions'][0]['expected'] = {'notAnalyzed': copy.deepcopy(stop)}
        # moduleの作成1操作が、上限0では拒否され、上限1では消費される。
        target['expected'] = input_expected(after(cap, 0, cap),
            [dict(phase='whole', reason=stop)], skipped=1)
        r = runner.invoke('whole-budget-'+str(cap), 'analyze', changed, 0)
        row = r['inputs'][1]
        assert row['bodies'] == [] and row['counts']['inputDefinitions'] == '1'
        assert row['counts']['wholeBudgetSkipped'] == '1' and row['counts']['unidentifiedBodies'] == '0'
        assert row['unproducedBodies'][0]['comparisonEligible'] is False
        assert row['unproducedBodies'][0]['stop']['scope'] == 'whole'
        assert r['matched'] and row['mismatches'] == []
        # 期待の停止理由、最終消費、段停止、専用射影の件数は個別に照合する。
        for label, mutate, field in [
            ('reason', lambda t: t['modules'][0]['definitions'][0]['expected']['notAnalyzed'].update(resource='items'), 'notAnalyzed'),
            ('after', lambda t: t['expected']['after']['whole'].update(operations=str(cap+1)), 'after'),
            ('phase', lambda t: t['expected']['phaseStops'][0]['reason'].update(kind='unidentified'), 'phaseStops'),
            ('counts', lambda t: t['expected']['counts'].update(wholeBudgetSkipped='0'), 'counts')]:
            mismatch = copy.deepcopy(changed)
            mutate(mismatch['inputs'][1])
            r = runner.invoke('whole-budget-'+str(cap)+'-'+label, 'analyze', mismatch, 1, field)
            assert not r['matched']
        for label, mutate, reason in [
            ('extra', lambda t: t['modules'][0]['definitions'][0]['expected'].update(integer='top'), 'not analyzed'),
            ('stop', lambda t: t['modules'][0]['definitions'][0]['expected']['notAnalyzed'].update(extra=True), 'halt'),
            ('unknown-stop', lambda t: t['modules'][0]['definitions'][0]['expected'].update(notAnalyzed='future'), 'object'),
            ('phase-extra', lambda t: t['expected']['phaseStops'][0].update(extra=True), 'whole phase'),
            ('input-extra', lambda t: t['expected'].update(extra=True), 'input expectation'),
            ('missing-count', lambda t: t['expected']['counts'].pop('unsupportedBodies'), 'counts'),
            ('count-decimal', lambda t: t['expected']['counts'].update(wholeBudgetSkipped='01'), 'decimal')]:
            invalid = copy.deepcopy(changed)
            mutate(invalid['inputs'][1])
            runner.invoke('whole-budget-invalid-'+str(cap)+'-'+label, 'analyze', invalid, 2, reason)
    # 全体期待は任意の三欄を独立に指定でき、成功時の発見の消費も比較する。
    final_point = input_expected(after(14, 3, 7))
    for field in ('after', 'phaseStops', 'counts'):
        changed = copy.deepcopy(base)
        changed['inputs'][0]['expected'] = {field: final_point[field]}
        r = runner.invoke('input-expected-'+field, 'analyze', changed, 0)
        assert r['matched']
    # 親の解析を終えた直後の全体停止では、未発見の別本体の期待も照合する。
    changed = copy.deepcopy(flow)
    target = changed['inputs'][-1]
    target['limits']['whole']['operations'] = '10'
    r = runner.invoke('embedded-unproduced-old', 'analyze', changed, 1, 'notAnalyzed')
    assert not r['matched'] and r['inputs'][-1]['unproducedBodies'][0]['mismatches'] == ['notAnalyzed']
    stop = dict(kind='exceeded', scope='whole', resource='operations')
    target['expectedBodies'][0]['expected'] = {'notAnalyzed': stop}
    # 発見前に止まり、未発見の別本体はwholeBudgetSkippedへ足さない。
    target['expected'] = input_expected(after(10, 4, 10), [dict(definition='M.lazy',
        phase='embedded', reason=copy.deepcopy(stop), next=None, afterDefinition=after(10, 4, 10))], skipped=1)
    target['expected']['counts']['unsupportedBodies'] = '1'
    r = runner.invoke('embedded-unproduced', 'analyze', changed, 0)
    assert r['matched'] and r['inputs'][-1]['unproducedBodies'][0]['mismatches'] == []
    # 完了済みの別本体へ未着手を期待した場合も、期待を読み捨てない。
    changed = copy.deepcopy(flow)
    changed['inputs'][-1]['expectedBodies'][0]['expected'] = {'notAnalyzed': 'depth'}
    r = runner.invoke('embedded-analyzed-expected-unproduced', 'analyze', changed, 1, 'notAnalyzed')
    assert not r['matched']
    # 解析済みの本体にnotAnalyzedを期待する場合も不一致とする。
    changed = copy.deepcopy(base)
    definition_rows(changed)[0]['expected'] = {'notAnalyzed': 'depth'}
    r = runner.invoke('analyzed-expected-unproduced', 'analyze', changed, 1, 'notAnalyzed')
    assert not r['matched']
    # 対応表のない期待本体を読み捨てず、交換の不正として拒否する。
    changed = copy.deepcopy(flow)
    changed['inputs'][-1]['expectedBodies'][0]['definition'] = 'M.unknown%body:1:0'
    runner.invoke('invalid-embedded-manifest', 'analyze', changed, 2, 'embedded manifest')
    # 終了前のcontextがない期待は、一致を検査した扱いにしない。
    changed = copy.deepcopy(base)
    del definition_rows(changed)[0]['expected']['context']
    runner.invoke('missing-context', 'analyze', changed, 1, 'context')
    # Exprsの列も、入れ子の浅さによらずfuelを消費する。
    list_type = {'list': {'elem': INTEGER}}
    d = definition('listDepth', last({'list': dict(elem=INTEGER, elems=[integer(1)]*12)}),
                   [list_type, list_type]+[INTEGER]*12, [], expected('top', (0, 0, 0)),
                   {'excluded': 'notClosedOrFuel'})
    c = corpus('flow', [d])
    set_fuel(c, 6)
    r = runner.invoke('depth-exprs', 'analyze', c, 1)
    assert r['excludedCount'] == '1' and r['inputs'][0]['phaseDepthCount'] != '0'
    # 式を増やさない64個のbuilder位置で、C1R2の初期fuel40が実際に尽きる。
    # 各位置は分類と環境書き込みの2操作、作業枠と環境の2項だけを増やす。
    body = last(integer(9))
    for _ in range(64):
        body = {'builderBind': dict(kind='bytes', rest=body)}
    c = corpus('flow', [definition('containerFuel', body, [INTEGER]*2, [],
                                  expected(interval(9), (136, 3, 135)), dict(outcome=normal(9), trace=[]))])
    start = selected_fuel(c)
    assert start == 40
    set_fuel(c, start)
    r = runner.invoke('fuel-initial', 'analyze', c, 1, 'depthExclusions')
    assert r['matched'] and r['excludedCount'] == '1'
    set_fuel(c, start*2)
    r = runner.invoke('fuel-selected', 'analyze', c, 0)
    assert r['excludedCount'] == '0' and r['phaseDepthCount'] == '0'
    runner.invoke('fuel-selected-eval', 'eval', c, 0)
    selections.append(dict(profile='flow-containers', initial=str(start), selected=str(start*2),
                           attempts=[dict(fuel=str(start), exit=1, excluded='1'),
                                     dict(fuel=str(start*2), exit=0, excluded='0')]))
    (directory/'fuel-selection.json').write_text(json.dumps(selections, indent=2)+'\n')
    # 引数とIOの失敗は比較の不一致とは別の2にする。
    # 相対名で起動し、保存する報告へ手元の絶対パスを含めない。
    io_cases = [([], 'usage:'), (['future', 'a', 'b'], 'usage:'),
                (['analyze', 'missing.json', 'missing.report.json'], 'missing.json'),
                (['analyze', 'base-eval.json', 'absent/report.json'], 'absent/report.json'),
                (['analyze', 'base-eval.json', 'base-eval.json'], 'must differ'),
                (['analyze', './base-eval.json', 'base-eval.json'], 'must differ')]
    (directory/'path-subdir').mkdir()
    io_cases.append((['analyze', 'base-eval.json', 'path-subdir/../base-eval.json'], 'must differ'))
    (directory/'input-link.json').symlink_to('base-eval.json')
    io_cases.append((['analyze', 'base-eval.json', 'input-link.json'], 'must differ'))
    for index, (args, message) in enumerate(io_cases):
        p = subprocess.run([str(executable)]+args, cwd=directory, capture_output=True, text=True, timeout=30)
        runner.calls += 1
        assert p.returncode == 2 and message in p.stderr, (index, p.returncode, p.stderr)
        (directory/('io-'+str(index)+'.stderr')).write_text(p.stderr.replace(str(directory), '<tmp>'))
    # 入力と報告を同じにした拒否が入力を変更していないことも確かめる。
    assert json.loads((directory/'base-eval.json').read_text()) == base
    print(json.dumps(dict(calls=runner.calls, profiles=REQUIRED_PROFILES,
                          definitions=[len(definition_rows(c)) for c in corpora],
                          fuel=selections), ensure_ascii=False))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--source-dir', type=Path)
    parser.add_argument('--rust-dir', type=Path, action='append', default=[])
    parser.add_argument('--vm-dir', type=Path)
    parser.add_argument('--cli', type=Path, default=FORMAL.parent/'target/debug/benitoite')
    parser.add_argument('--executable', type=Path, default=FORMAL/'.lake/build/bin/intervalDiff')
    args = parser.parse_args()
    executable = args.executable.resolve()
    if args.output:
        args.output.mkdir(parents=True, exist_ok=True)
        exercise(args.output.resolve(), executable, args.source_dir, args.rust_dir, args.vm_dir, args.cli)
    else:
        with tempfile.TemporaryDirectory(prefix='benitoite-interval-') as directory:
            exercise(Path(directory), executable, args.source_dir, args.rust_dir, args.vm_dir, args.cli)


if __name__ == '__main__':
    main()
