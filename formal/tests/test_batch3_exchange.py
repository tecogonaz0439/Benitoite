"""corpus12/sidecar4 の独立入力を六入口で比較する。Cargo は起動しない。"""
import argparse
import copy
import json
from pathlib import Path
import runpy
import tempfile
import unittest

shared = runpy.run_path(str(Path(__file__).with_name('test_named_exchange.py')))
FILES, TOOLS = shared['FILES'], shared['TOOLS']
FIXTURES = Path(__file__).with_name('batch3-exchange')
RUST_MANIFEST = Path(__file__).resolve().parents[2] / 'crates/benitoite/tests/desugar_export/batch3/manifest.json'


def definition(data, key):
    return next(d['scope']['inScope'] for d in data['corpus']['inputs'][0]['definitions']
                if d['name'].endswith(f'({key})'))


class Batch3ExchangeTests(unittest.TestCase):
    def setUp(self):
        self.data = {f: json.loads((FIXTURES / f'{f}.json').read_text()) for f in FILES}
        self.tmp = tempfile.TemporaryDirectory(prefix='benitoite-batch3-exchange-')
        self.addCleanup(self.tmp.cleanup)
        self.directory = Path(self.tmp.name)

    def run_tool(self, tool, data=None, selected=None):
        return shared['ExchangeTests'].run_tool(self, tool, data, selected, 'independent-batch3')

    def test_six_entries(self):
        for tool in TOOLS:
            with self.subTest(tool=tool):
                result, report = self.run_tool(tool)
                self.assertEqual(result.returncode, 0, result.stderr + result.stdout + json.dumps(report))
                if tool == 'desugarDiff':
                    self.assertEqual(report['golden']['definitions'], dict(matched=30, mismatched=0, outside=0, excluded=0))
                    self.assertEqual(report['mismatches'], [])
                elif tool == 'builtinCheck':
                    self.assertEqual(report['errors'], [])
                    self.assertEqual(report['summaryMismatchCount'], 0)
                elif tool.startswith('coverage'):
                    self.assertEqual((report['matched'], report['mismatched'], report['fuelExhausted']), (3 if tool == 'coverageDiff' else 2, 0, 0))
                elif tool == 'surfaceCheck':
                    self.assertEqual(report['result'], {'ok': True})
                else:
                    self.assertEqual(report['counts'], dict(matched=30, mismatched=0, outOfScope=0,
                                     q11=0, lazyRestriction=0, preparationFailure=0))

    def test_old_versions_reject_nested_builder_information(self):
        for f in FILES:
            for version in ([8, 9, 10, 11] if f == 'corpus' else [2, 3, 4]):
                for field in ('builderBind', 'builderOp', 'refs', 'newRef', 'getRef', 'setRef'):
                    data = copy.deepcopy(self.data)
                    data[f]['version'] = version
                    data[f]['deep'] = [{'unknown': {field: None}}]
                    tool = next(t for t, fs in TOOLS.items() if f in fs)
                    with self.subTest(file=f, version=version, field=field):
                        result, _ = self.run_tool(tool, data)
                        self.assertEqual(result.returncode, 2, result.stdout)
                        self.assertIn(f'new exchange version: {field}', result.stderr)

    def test_corpus11_batch2_and_sidecar_versions(self):
        data = {f: json.loads((Path(__file__).with_name('batch2-exchange') / f'{f}.json').read_text()) for f in FILES}
        for v in (11, 12):
            data['corpus']['version'] = v
            for tool in TOOLS:
                with self.subTest(version=v, tool=tool):
                    result, report = shared['ExchangeTests'].run_tool(self, tool, data, None, 'independent-batch2')
                    self.assertEqual(result.returncode, 0, result.stderr + json.dumps(report))
        for f in ('builtins', 'stdlib'):
            data = copy.deepcopy(self.data)
            data[f]['version'] = 3
            result, _ = self.run_tool('surfaceCheck', data)
            self.assertEqual(result.returncode, 2, result.stdout)
        for f in FILES:
            for v in (0, 1, 5, 6, 7, 13):
                data = copy.deepcopy(self.data)
                data[f]['version'] = v
                tool = next(t for t, fs in TOOLS.items() if f in fs)
                result, _ = self.run_tool(tool, data)
                self.assertEqual(result.returncode, 2, result.stdout)
                self.assertIn('version', result.stderr)

    def test_required_builder_fields(self):
        for key in ('kind', 'refs', 'rest'):
            data = copy.deepcopy(self.data)
            del definition(data, 'fn:201')['surface']['body']['builderBind'][key]
            result, _ = self.run_tool('desugarDiff', data)
            self.assertEqual(result.returncode, 2, result.stdout)
        for key in ('op', 'index', 'args', 'refs'):
            data = copy.deepcopy(self.data)
            del definition(data, 'fn:201')['surface']['body']['builderBind']['rest']['last']['expr']['returnE']['inner']['builderOp'][key]
            result, _ = self.run_tool('desugarDiff', data)
            self.assertEqual(result.returncode, 2, result.stdout)

    def test_unknown_fields_are_not_discarded(self):
        for mutation in ('outer', 'payload', 'reference', 'kind', 'batch2'):
            data = copy.deepcopy(self.data)
            surface = definition(data, 'fn:201')['surface']
            bind = surface['body']['builderBind']
            if mutation == 'outer': surface['body']['empty'] = None
            elif mutation == 'payload': bind['newField'] = None
            elif mutation == 'reference': bind['refs']['string']['cell']['newRef']['effs'] = []
            elif mutation == 'kind': bind['kind'] = {'list': {'element': {'base': {'name': 'Integer'}}, 'extra': None}}
            else: del surface['header']['effParams']
            result, _ = self.run_tool('desugarDiff', data)
            self.assertEqual(result.returncode, 2, result.stdout)

    def test_builder_semantic_rejections(self):
        for mutation, reason in [('kind', 'invalid builder declaration references'),
                                 ('get', 'invalid builder declaration references'),
                                 ('ordinary', 'local is missing or hidden'),
                                 ('index', 'invalid local builder or operation references'),
                                 ('effect', 'effect exceeds the allowed effect')]:
            data = copy.deepcopy(self.data)
            s = definition(data, 'fn:201')['surface']
            if mutation == 'kind': s['body']['builderBind']['kind'] = 'bytes'
            elif mutation == 'get': s['body']['builderBind']['refs']['string']['cell']['getRef']['name'] = 'set'
            elif mutation == 'ordinary': s['body']['builderBind']['rest']['last']['expr']['returnE']['inner'] = {'local': {'index': 0}}
            elif mutation == 'index': s['body']['builderBind']['rest']['last']['expr']['returnE']['inner']['builderOp']['index'] = 1
            else: s['header']['eff'] = []
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
                self.assertEqual(report['result']['error']['reason'], 'invalid local builder or operation references')

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
                    'outer-cell': 'invalid local builder or operation references',
                }
                self.assertEqual(report['result']['error']['reason'], expected[variant])

    def test_monad2_wrong_super_and_error_type(self):
        for key, mutation in [('fn:220', 'super'), ('fn:223', 'error')]:
            data = copy.deepcopy(self.data)
            call = definition(data, key)['surface']['body']['last']['expr']['returnE']['inner']['call']
            if mutation == 'super': call['callee']['methName']['dict']['super']['cls'] = 'Missing'
            else: call['callee']['methName']['tys'][1] = {'base': {'name': 'Integer'}}
            result, report = self.run_tool('surfaceCheck', data, key)
            self.assertEqual(result.returncode, 1, result.stderr + json.dumps(report))
            self.assertFalse(report['result']['ok'])

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

    def test_missing_or_empty_rust_output_is_not_success(self):
        with self.assertRaises(FileNotFoundError):
            check_rust(self.directory / 'missing')
        for f, doc in self.data.items():
            (self.directory / f'{f}.json').write_text(json.dumps(doc))
        (self.directory / 'corpus.json').write_text(json.dumps(dict(self.data['corpus'], inputs=[])))
        with self.assertRaisesRegex(AssertionError, 'definitions'):
            check_rust(self.directory)

    def test_rust_manifest_rejects_partial_exports(self):
        # 外部JSONの件数契約を確かめる。型の成否は同じ独立入力の六入口が持つ。
        data = copy.deepcopy(self.data)
        original = data['corpus']['inputs'][0]
        data['corpus']['inputs'] = [dict(original, name=name, definitions=original['definitions'][:3])
                                    for name in ('higher-order', 'super-paths', 'failure')]
        for f in ('builtins', 'stdlib', 'coverage-program'):
            data[f]['inputs'] = [dict(data[f]['inputs'][0], name=name) for name in ('higher-order', 'super-paths', 'failure')]
        data['coverage']['cases'] = data['coverage']['cases'][:1]
        for item in data['coverage-program']['inputs']:
            item['matches'], item['bindings'] = [], []
        data['coverage-program']['inputs'][0]['matches'] = self.data['coverage-program']['inputs'][0]['matches'][:1]
        for mutation in ('none', 'missing-definition', 'duplicate-input', 'outside', 'excluded', 'missing-table', 'coverage'):
            changed = copy.deepcopy(data)
            if mutation == 'missing-definition': changed['corpus']['inputs'][0]['definitions'].pop()
            elif mutation == 'duplicate-input': changed['corpus']['inputs'].append(changed['corpus']['inputs'][0])
            elif mutation == 'outside': changed['corpus']['inputs'][0]['definitions'][0]['scope'] = {'outOfScope': {'elements': ['bad']}}
            elif mutation == 'excluded': changed['corpus']['inputs'][0]['excluded'] = ['bad']
            elif mutation == 'missing-table': changed['builtins']['inputs'].pop()
            elif mutation == 'coverage': changed['coverage']['cases'] = []
            for f, doc in changed.items():
                (self.directory / f'{f}.json').write_text(json.dumps(doc))
            with self.subTest(mutation=mutation):
                if mutation == 'none':
                    _, expected = rust_inputs(self.directory, 't3')
                    self.assertEqual(expected['definitions'], 9)
                    with self.assertRaisesRegex(AssertionError, 'manifest'):
                        rust_inputs(self.directory, 'b3')
                else:
                    with self.assertRaises(AssertionError):
                        rust_inputs(self.directory, 't3')


def rust_inputs(directory, profile=None):
    """五形式と、実ソースごとの固定した期待件数を照合する。"""
    data = {f: json.loads((directory / f'{f}.json').read_text()) for f in FILES}
    for f, doc in data.items():
        if doc['version'] != (12 if f == 'corpus' else 4):
            raise AssertionError(f'{f}: expected corpus12/sidecar4')
    inputs = data['corpus']['inputs']
    if not inputs or not any(i['definitions'] for i in inputs):
        raise AssertionError('Rust batch3 corpus must contain definitions')
    if any(i['excluded'] or i['group'] != 'golden' or not i['definitions'] for i in inputs):
        raise AssertionError('local batch3 inputs must be nonempty golden inputs without exclusions')
    if any(set(d['scope']) != {'inScope'} for i in inputs for d in i['definitions']):
        raise AssertionError('Rust definitions outside scope')
    manifest = json.loads(RUST_MANIFEST.read_text())
    counts = {i['name']: len(i['definitions']) for i in inputs}
    if len(counts) != len(inputs):
        raise AssertionError('duplicate Rust input names')
    # 入力を減らして別作業の集合へ見せ掛けても、B3の成功にはしない。
    profile = profile or (directory.name if directory.name in manifest['profiles'] else 'b3')
    expected = manifest['profiles'][profile]
    if expected['inputs'] != counts:
        raise AssertionError(f'Rust input definitions differ from manifest: {counts}')
    keys = {('golden', name) for name in counts}
    for f in ('builtins', 'stdlib', 'coverage-program'):
        actual = [(i['group'], i['name']) for i in data[f]['inputs']]
        if len(actual) != len(keys) or set(actual) != keys:
            raise AssertionError(f'{f}: Rust input coverage differs')
    total = sum(counts.values())
    surface_total = sum(sum(d['scope']['inScope']['surface']['implementation'] is None for d in i['definitions'])
                        + len({d['scope']['inScope']['surface']['implementation'] for d in i['definitions']
                               if d['scope']['inScope']['surface']['implementation'] is not None}) for i in inputs)
    program_total = sum(len(i['matches']) + len(i['bindings']) for i in data['coverage-program']['inputs'])
    if (total, surface_total, len(data['coverage']['cases']), program_total) != (
            expected['definitions'], expected['surfaceChecks'], expected['coverageCases'], expected['programCoverageCases']):
        raise AssertionError('Rust aggregate counts differ from manifest')
    return data, expected


def check_rust(directory):
    """五形式の欠落、空corpus、比較の不一致・対象外を失敗にする。"""
    data, expected = rust_inputs(directory)
    inputs = data['corpus']['inputs']
    case = Batch3ExchangeTests()
    case.setUp()
    try:
        for tool in TOOLS:
            if tool == 'surfaceCheck':
                for i in inputs:
                    result, report = shared['ExchangeTests'].run_tool(case, tool, data, None, i['name'])
                    case.assertEqual(result.returncode, 0, result.stderr + json.dumps(report))
                    case.assertEqual(report['result'], {'ok': True})
                continue
            result, report = case.run_tool(tool, data)
            case.assertEqual(result.returncode, 0, result.stderr + result.stdout + json.dumps(report))
            if tool == 'desugarDiff':
                case.assertGreater(report['golden']['definitions']['matched'], 0)
                case.assertEqual(report['golden']['definitions']['matched'], expected['definitions'])
                case.assertEqual(report['mismatches'], [])
                for k in ('mismatched', 'outside', 'excluded'):
                    case.assertEqual(report['golden']['definitions'][k], 0)
            elif tool == 'builtinCheck':
                case.assertEqual(report['errors'], [])
                case.assertEqual(report['summaryMismatchCount'], 0)
            elif tool.startswith('coverage'):
                case.assertGreater(report['matched'], 0)
                case.assertEqual(report['matched'], expected['coverageCases' if tool == 'coverageDiff' else 'programCoverageCases'])
                case.assertEqual((report['mismatched'], report['fuelExhausted']), (0, 0))
            else:
                case.assertGreater(report['counts']['matched'], 0)
                case.assertEqual(report['counts']['matched'], expected['surfaceChecks'])
                for k in ('mismatched', 'preparationFailure', 'outOfScope', 'lazyRestriction', 'q11'):
                    case.assertEqual(report['counts'][k], 0)
    finally:
        case.doCleanups()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--rust-dir', type=Path)
    args, rest = parser.parse_known_args()
    result = unittest.main(argv=[__file__, *rest], exit=False).result
    if not result.wasSuccessful():
        raise SystemExit(1)
    if args.rust_dir is not None:
        check_rust(args.rust_dir)
