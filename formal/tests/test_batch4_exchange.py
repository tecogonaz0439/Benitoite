"""corpus13/sidecar5 の独立入力を六入口で比較する。Cargo は起動しない。"""
import copy
import json
from pathlib import Path
import runpy
import tempfile
import unittest

shared = runpy.run_path(str(Path(__file__).with_name('test_named_exchange.py')))
FILES, TOOLS = shared['FILES'], shared['TOOLS']
FIXTURES = Path(__file__).with_name('batch4-exchange')


def definition(data, key):
    return next(d['scope']['inScope'] for d in data['corpus']['inputs'][0]['definitions']
                if d['name'].endswith(f'({key})'))


class Batch4ExchangeTests(unittest.TestCase):
    def setUp(self):
        self.data = {f: json.loads((FIXTURES / f'{f}.json').read_text()) for f in FILES}
        self.tmp = tempfile.TemporaryDirectory(prefix='benitoite-batch4-exchange-')
        self.addCleanup(self.tmp.cleanup)
        self.directory = Path(self.tmp.name)

    def run_tool(self, tool, data=None, selected=None):
        return shared['ExchangeTests'].run_tool(self, tool, data, selected, 'independent-batch4')

    def test_six_entries(self):
        for tool in TOOLS:
            with self.subTest(tool=tool):
                result, report = self.run_tool(tool)
                self.assertEqual(result.returncode, 0, result.stderr + result.stdout + json.dumps(report))
                if tool == 'desugarDiff':
                    self.assertEqual(report['golden']['definitions'], dict(matched=45, mismatched=0, outside=0, excluded=0))
                    self.assertEqual(report['mismatches'], [])
                elif tool == 'builtinCheck':
                    self.assertEqual(report['errors'], [])
                    self.assertEqual(report['summaryMismatchCount'], 0)
                elif tool.startswith('coverage'):
                    self.assertEqual((report['matched'], report['mismatched'], report['fuelExhausted']), (6 if tool == 'coverageDiff' else 3, 0, 0))
                elif tool == 'surfaceCheck':
                    self.assertEqual(report['result'], {'ok': True})
                else:
                    self.assertEqual(report['counts'], dict(matched=45, mismatched=0, outOfScope=0,
                                     q11=0, lazyRestriction=0, preparationFailure=0))

    def test_required_builder_fields(self):
        for key in ('kind', 'rest'):
            data = copy.deepcopy(self.data)
            del definition(data, 'fn:201')['surface']['body']['builderBind'][key]
            result, _ = self.run_tool('desugarDiff', data)
            self.assertEqual(result.returncode, 2, result.stdout)
        for key in ('op', 'index', 'args', 'kind'):
            data = copy.deepcopy(self.data)
            del definition(data, 'fn:201')['surface']['body']['builderBind']['rest']['last']['expr']['returnE']['inner']['builderOp'][key]
            result, _ = self.run_tool('desugarDiff', data)
            self.assertEqual(result.returncode, 2, result.stdout)

    def test_core_builder_fields_are_required_and_unambiguous(self):
        for tag, keys in [('builderLet', ('kind', 'body')),
                          ('builderOp', ('kind', 'op', 'ref', 'args'))]:
            for key in (*keys, 'extra', 'ambiguous', 'reference'):
                data = copy.deepcopy(self.data)
                root = definition(data, 'fn:201')['core']['body']
                node = root if tag == 'builderLet' else root['builderLet']['body']
                if key == 'extra':
                    node[tag]['unexpected'] = None
                elif key == 'ambiguous':
                    node['unsupported'] = {'name': 'ignored'}
                elif key == 'reference':
                    if tag == 'builderLet':
                        node[tag]['kind'] = {'list': {'element': {'base': {'name': 'Integer'}}, 'extra': None}}
                    else:
                        node[tag]['ref']['bound']['extra'] = None
                else:
                    del node[tag][key]
                with self.subTest(tag=tag, key=key):
                    result, _ = self.run_tool('desugarDiff', data)
                    self.assertEqual(result.returncode, 2, result.stdout)

    def test_unknown_fields_are_not_discarded(self):
        for mutation in ('outer', 'payload', 'reference', 'kind', 'batch2'):
            data = copy.deepcopy(self.data)
            surface = definition(data, 'fn:201')['surface']
            bind = surface['body']['builderBind']
            if mutation == 'outer': surface['body']['empty'] = None
            elif mutation == 'payload': bind['newField'] = None
            elif mutation == 'reference': bind['refs'] = {}
            elif mutation == 'kind': bind['kind'] = {'list': {'element': {'base': {'name': 'Integer'}}, 'extra': None}}
            else: del surface['header']['effParams']
            result, _ = self.run_tool('desugarDiff', data)
            self.assertEqual(result.returncode, 2, result.stdout)

    def test_builder_semantic_rejections(self):
        for mutation, reason in [('kind', 'invalid local builder kind'),
                                 ('annotation', 'invalid local builder kind'),
                                 ('ordinary', 'local is missing or hidden'),
                                 ('index', 'invalid local builder kind'),
                                 ('effect', 'effect exceeds the allowed effect')]:
            data = copy.deepcopy(self.data)
            s = definition(data, 'fn:201')['surface']
            if mutation == 'kind': s['body']['builderBind']['kind'] = 'bytes'
            elif mutation == 'annotation': s['body']['builderBind']['rest']['last']['expr']['returnE']['inner']['builderOp']['kind'] = 'bytes'
            elif mutation == 'ordinary': s['body']['builderBind']['rest']['last']['expr']['returnE']['inner'] = {'local': {'index': 0}}
            elif mutation == 'index': s['body']['builderBind']['rest']['last']['expr']['returnE']['inner']['builderOp']['index'] = 1
            else:
                ask = {'call': dict(callee={'opName': dict(name='ask', tys=[])}, labels=[None],
                                    positions=[0], args=[{'literal': {'value': {'integer': {'value': 3}}}}])}
                copied = {'builderOp': dict(op='copy', index=0, args=[], kind='string')}
                s['body']['builderBind']['rest']['last']['expr']['returnE']['inner'] = {
                    'block': {'body': {'discard': dict(expr=ask, rest={'last': {'expr': copied}})}}}
            result, report = self.run_tool('surfaceCheck', data, 'fn:201')
            self.assertEqual(result.returncode, 1, result.stderr + json.dumps(report))
            self.assertEqual(report['result']['error']['reason'], reason)

    def test_capture_boundaries(self):
        root = definition(self.data, 'fn:201')['surface']['body']['builderBind']
        copied = root['rest']['last']['expr']['returnE']['inner']
        string = {'base': {'name': 'String'}}
        integer = {'base': {'name': 'Integer'}}
        state = [{'name': {'value': 'State'}}]
        lam = {'lam': dict(names=[], params=[], ret=string, eff=state,
                          body={'last': {'expr': {'returnE': dict(ret=string, inner=copied)}}})}
        fixed = {'expr': dict(label='left', position=0, inner=copied)}
        hole = {'hole': dict(label='right', position=1, ty=string)}
        add = {'primName': dict(name='add', tys=[], effs=[])}
        partial = {'partialCall': dict(callee=add, names=['left', 'right'], args=[fixed, hole], ret=string, eff=state)}
        callee = copy.deepcopy(partial)
        callee['partialCall']['args'] = [dict(hole=dict(label='left', position=0, ty=string)), hole]
        callee['partialCall']['callee'] = {'ite': dict(cond={'literal': {'value': {'boolean': {'value': True}}}},
            yes={'seq': dict(expr=copied, rest={'last': {'expr': add}})}, no={'last': {'expr': add}})}
        variants = [lam, {'lazyE': dict(body={'last': {'expr': copied}})}, partial, callee,
            {'partialCon': dict(name='PosPair', tys=[], args=[{'expr': dict(label=None, position=0, inner=copied)},
                                                        {'hole': dict(label=None, position=1, ty=integer)}])},
            {'call': dict(callee={'funName': dict(name='task', tys=[], effs=[])}, labels=['f'], positions=[0], args=[lam])},
            {'handleFail': dict(error=string, result=string, body={'last': {'expr': {'literal': {'value': {'string': {'value': 'ok'}}}}}},
                                clause={'last': {'expr': {'builderOp': dict(copied['builderOp'], index=2)}}})}]
        for n, expression in enumerate(variants):
            data = copy.deepcopy(self.data)
            definition(data, 'fn:201')['surface']['body']['builderBind']['rest']['last']['expr']['returnE']['inner'] = expression
            with self.subTest(boundary=n):
                result, report = self.run_tool('surfaceCheck', data, 'fn:201')
                self.assertEqual(result.returncode, 1, result.stderr + json.dumps(report))
                self.assertEqual(report['result']['error']['reason'], 'invalid local builder kind')

    def test_shared_numbering(self):
        for variant in ('depth', 'resume', 'value', 'received-dict', 'outer-cell'):
            data = copy.deepcopy(self.data)
            clause = definition(data, 'fn:210')['surface']['body']['last']['expr']['returnE']['inner']['handleE']['clauses'][0]
            rest = clause['body']['builderBind']['rest']['bind']['rest']['discard']
            if variant == 'depth': rest['expr']['opDicts']['dicts'][0]['clause']['depth'] = 1
            elif variant == 'resume': rest['rest']['last']['expr']['resume']['index'] = 1
            elif variant == 'value': rest['rest']['last']['expr']['resume']['inner']['local']['index'] = 2
            elif variant == 'outer-cell':
                s = definition(data, 'fn:214')['surface']['body']['builderBind']['rest']['last']['expr']['returnE']['inner']['handleE']
                s['clauses'][0]['body'] = {'last': {'expr': {'builderOp': dict(
                    definition(data, 'fn:201')['surface']['body']['builderBind']['rest']['last']['expr']['returnE']['inner']['builderOp'], index=2)}}}
            else:
                definition(data, 'fn:209')['surface']['body']['builderBind']['rest']['last']['expr']['returnE']['inner']['methName']['dict']['local']['index'] = 1
            key = 'fn:209' if variant == 'received-dict' else 'fn:214' if variant == 'outer-cell' else 'fn:210'
            with self.subTest(variant=variant):
                result, report = self.run_tool('surfaceCheck', data, key)
                self.assertEqual(result.returncode, 1, result.stderr + json.dumps(report))
                self.assertFalse(report['result']['ok'])
                expected = {
                    'depth': 'clause dictionary scope mismatch',
                    'resume': 'continuation is missing or hidden',
                    'value': 'continuations cannot be used as ordinary locals',
                    'received-dict': 'expected a dictionary type',
                    'outer-cell': 'invalid local builder kind',
                }
                self.assertEqual(report['result']['error']['reason'], expected[variant])

    def test_constants_reject_builders(self):
        for body in (definition(self.data, 'fn:201')['surface']['body']['builderBind']['rest']['last']['expr']['returnE']['inner'],
                     {'ite': {'cond': {'literal': {'value': {'boolean': {'value': True}}}},
                              'yes': definition(self.data, 'fn:201')['surface']['body'], 'no': 'empty'}}):
            data = copy.deepcopy(self.data)
            data['corpus']['inputs'][0]['constants'] = [dict(name='bad', package='author', ty={'base': {'name': 'String'}}, body=body)]
            for tool in ('desugarDiff', 'builtinCheck', 'surfaceCheck', 'surfaceCheckAll'):
                with self.subTest(tool=tool, body=body):
                    result, _ = self.run_tool(tool, data)
                    self.assertEqual(result.returncode, 2, result.stdout)
                    self.assertIn('source match/binding in constant', result.stderr)

    def test_expected_core_integer_is_bounded(self):
        # 比較される期待コアも、型付き表層と同じi64の契約を守る。
        for value in (-9223372036854775809, 9223372036854775808):
            data = copy.deepcopy(self.data)
            definition(data, 'fn:304')['core']['body']['ret']['value']['const']['value']['integer']['value'] = value
            for tool in ('desugarDiff', 'builtinCheck', 'surfaceCheck', 'surfaceCheckAll'):
                with self.subTest(value=value, tool=tool):
                    result, _ = self.run_tool(tool, data)
                    self.assertEqual(result.returncode, 2, result.stderr + result.stdout)
                    self.assertIn('integer outside i64', result.stderr)

    def test_version_boundaries_and_pairs(self):
        for f in FILES:
            versions = range(8, 13) if f == 'corpus' else range(2, 6)
            fields = ('block', 'builderBind', 'builderOp', 'builderLet', 'localRef')
            for version in versions:
                for field in fields:
                    data = copy.deepcopy(self.data)
                    # 正例全体の別のタグに先に拒否されない入力で版境界を観測する。
                    data[f] = dict(version=version, deep=[{'unknown': {field: None}}])
                    tool = {'corpus': 'desugarDiff', 'builtins': 'builtinCheck', 'stdlib': 'surfaceCheck',
                            'coverage': 'coverageDiff', 'coverage-program': 'coverageProgramDiff'}[f]
                    if f in ('builtins', 'stdlib'):
                        # この二形式はcorpusの後に読まれる。
                        tool = 'builtinCheck' if f == 'builtins' else 'surfaceCheck'
                    with self.subTest(file=f, version=version, field=field):
                        result, _ = self.run_tool(tool, data)
                        self.assertEqual(result.returncode, 2, result.stdout)
                        reason = ('regenerate with version 13' if f == 'corpus' and version == 12
                                  and field in ('builderBind', 'builderOp', 'builderLet')
                                  else f'new exchange version: {field}')
                        self.assertIn(reason, result.stderr)
        for f in ('builtins', 'stdlib', 'coverage-program'):
            data = copy.deepcopy(self.data)
            data[f]['version'] = 4
            for tool, fs in TOOLS.items():
                if f not in fs or len(fs) == 1:
                    continue
                with self.subTest(pair=tool, file=f):
                    result, _ = self.run_tool(tool, data)
                    self.assertEqual(result.returncode, 2, result.stdout)
                    self.assertIn('version pair mismatch', result.stderr)

    def test_new_corpus_rejects_all_legacy_reference_fields(self):
        for field in ('refs', 'newRef', 'getRef', 'setRef'):
            data = copy.deepcopy(self.data)
            data['corpus']['deep'] = [{'unknown': {field: {}}}]
            result, _ = self.run_tool('desugarDiff', data)
            self.assertEqual(result.returncode, 2, result.stdout)
            self.assertIn(f'new exchange version: {field}', result.stderr)

    def test_integer_readers_and_aliases(self):
        for version in range(8, 15):
            # 8〜10の閉じた互換は既存の正例から作り、範囲外だけを変異させる。
            directory = 'named-exchange' if version < 11 else 'batch2-exchange'
            base = {f: json.loads((FIXTURES.parent / directory / f'{f}.json').read_text()) for f in FILES}
            if version == 8:
                legacy = runpy.run_path(str(FIXTURES.parent / 'test_extensible_exchange.py'))['legacy']
                base = legacy(base)
            base['corpus']['version'] = version
            for f in FILES[1:]:
                base[f]['version'] = 2 if version == 8 else 3 if version < 11 else 6 if version >= 14 else 5 if version == 13 else 4
            for value in (-9223372036854775809, 9223372036854775808):
                data = copy.deepcopy(base)
                data['corpus']['inputs'][0]['constants'] = [dict(name='oversized', package='author',
                    ty={'base': {'name': 'Integer64'}}, body={'literal': {'value': {'integer': {'value': value}}}})]
                with self.subTest(version=version, value=value):
                    result, _ = self.run_tool('desugarDiff', data)
                    self.assertEqual(result.returncode, 2, result.stdout)
                    self.assertIn('integer outside i64', result.stderr)
        # 別名は型の入れ子や全sidecarでも同じIntegerとして読む。
        def alias(x):
            if isinstance(x, list):
                return [alias(a) for a in x]
            if isinstance(x, dict):
                return {k: ('Integer64' if k == 'name' and a == 'Integer' else alias(a)) for k, a in x.items()}
            return x
        for tool in TOOLS:
            result, report = self.run_tool(tool, alias(self.data))
            self.assertEqual(result.returncode, 0, result.stderr + json.dumps(report))
        for f, tool, location in [('coverage', 'coverageDiff', 'pattern'),
                                   ('coverage-program', 'coverageProgramDiff', 'pattern')]:
            for version in range(2, 6):
                for value in (-9223372036854775809, 9223372036854775808):
                    data = copy.deepcopy(self.data)
                    data[f]['version'] = version
                    if f == 'coverage':
                        data[f]['cases'] = [data[f]['cases'][1]]
                        data[f]['boundaryCases'] = 1
                        data[f]['cases'][0][location] = dict(kind='integer', value=value)
                        if version == 2:
                            del data[f]['cases'][0]['package']
                            del data[f]['cases'][0]['coverageView']
                    else:
                        data['builtins']['version'] = version
                        data[f]['inputs'][0]['bindings'][0]['ty'] = {'base': {'name': 'Integer64'}}
                        data[f]['inputs'][0]['bindings'][0][location] = {'const': {'value': {'integer': {'value': value}}}}
                    with self.subTest(sidecar=f, version=version, value=value):
                        result, _ = self.run_tool(tool, data)
                        self.assertEqual(result.returncode, 2, result.stdout)
                        self.assertIn('integer outside i64', result.stderr)

    def test_block_preserves_capture_and_return_boundaries(self):
        data = copy.deepcopy(self.data)
        s = definition(data, 'fn:201')['surface']
        copied = s['body']['builderBind']['rest']['last']['expr']['returnE']['inner']
        string = {'base': {'name': 'String'}}
        lam = {'lam': dict(names=[], params=[], ret=string, eff=[],
                           body={'last': {'expr': {'returnE': dict(ret=string, inner=copied)}}})}
        block = {'block': {'body': {'last': {'expr': lam}}}}
        s['body']['builderBind']['rest'] = {'last': {'expr': {'returnE': dict(ret=string, inner=block)}}}
        result, report = self.run_tool('surfaceCheck', data, 'fn:201')
        self.assertEqual(result.returncode, 1, result.stderr + json.dumps(report))
        self.assertEqual(report['result']['error']['reason'], 'invalid local builder kind')
        # blockをlazyに包んでも、lazy内のreturnを許可しない。
        data = copy.deepcopy(self.data)
        returned = {'returnE': dict(ret=string, inner={'literal': {'value': {'string': {'value': 'x'}}}})}
        block = {'block': {'body': {'last': {'expr': returned}}}}
        lazy = {'lazyE': {'body': {'last': {'expr': block}}}}
        definition(data, 'fn:301')['surface']['body'] = {'last': {'expr': {'returnE':
            dict(ret={'base': {'name': 'Integer'}}, inner=lazy)}}}
        result, report = self.run_tool('surfaceCheck', data, 'fn:301')
        self.assertEqual(result.returncode, 1, result.stderr + json.dumps(report))
        self.assertEqual(report['result']['error']['reason'], 'return is outside a function')

    def test_comparison_keeps_lets_order_and_local_references(self):
        for key, mutation in [('fn:204', 'ref'), ('fn:314', 'order'), ('fn:306', 'let')]:
            data = copy.deepcopy(self.data)
            body = definition(data, key)['core']['body']
            if mutation == 'ref':
                body['builderLet']['body']['letIn']['body']['builderOp']['ref']['bound']['index'] = 0
            elif mutation == 'order':
                args = body['ret']['value']['lam']['body']['letIn']['body']['letIn']['body']['app']['args']
                args.reverse()
            else:
                lam = body['ret']['value']['lam']
                lam['body'] = {'letIn': dict(bound={'ret': {'value': {'var': {'index': 0}}}}, body=lam['body'])}
            result, report = self.run_tool('desugarDiff', data)
            self.assertEqual(result.returncode, 1, result.stderr)
            self.assertEqual(report['golden']['definitions'], dict(matched=44, mismatched=1, outside=0, excluded=0))
            self.assertEqual(len(report['mismatches']), 1)
            self.assertNotEqual(report['mismatches'][0]['expected'], report['mismatches'][0]['actual'])

    def test_log_effects_cannot_be_hidden(self):
        for key in ('fn:309', 'fn:312', 'fn:313'):
            data = copy.deepcopy(self.data)
            definition(data, key)['surface']['header']['eff'] = []
            result, report = self.run_tool('surfaceCheck', data, key)
            self.assertEqual(result.returncode, 1, result.stderr + json.dumps(report))
            self.assertEqual(report['result']['error']['reason'], 'effect exceeds the allowed effect')


if __name__ == '__main__':
    unittest.main()
