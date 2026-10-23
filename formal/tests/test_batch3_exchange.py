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


def builder_free(data):
    data = copy.deepcopy(data)
    kept = ['fn:8', *[f'fn:{n}' for n in range(101, 107)], *[f'fn:{n}' for n in range(220, 224)]]
    data['corpus']['inputs'][0]['definitions'] = [d for d in data['corpus']['inputs'][0]['definitions']
        if any(d['name'].endswith(f'({key})') for key in kept)]
    # 末尾matchのfn:211は新版へ移した集合に属する。
    data['corpus']['annotations']['tailMatch'] = [0, 0]
    return data


class Batch3ExchangeTests(unittest.TestCase):
    def setUp(self):
        self.data = {f: json.loads((FIXTURES / f'{f}.json').read_text()) for f in FILES}
        self.tmp = tempfile.TemporaryDirectory(prefix='benitoite-batch3-exchange-')
        self.addCleanup(self.tmp.cleanup)
        self.directory = Path(self.tmp.name)

    def run_tool(self, tool, data=None, selected=None):
        return shared['ExchangeTests'].run_tool(self, tool, data, selected, 'independent-batch3')

    def test_six_entries(self):
        # 構築器を含まない既存11定義の意味は変えない。
        self.data = builder_free(self.data)
        for tool in TOOLS:
            with self.subTest(tool=tool):
                result, report = self.run_tool(tool)
                self.assertEqual(result.returncode, 0, result.stderr + result.stdout + json.dumps(report))
                if tool == 'desugarDiff':
                    self.assertEqual(report['golden']['definitions'], dict(matched=11, mismatched=0, outside=0, excluded=0))
                    self.assertEqual(report['mismatches'], [])
                elif tool == 'builtinCheck':
                    self.assertEqual(report['errors'], [])
                    self.assertEqual(report['summaryMismatchCount'], 0)
                elif tool.startswith('coverage'):
                    self.assertEqual((report['matched'], report['mismatched'], report['fuelExhausted']), (3 if tool == 'coverageDiff' else 2, 0, 0))
                elif tool == 'surfaceCheck':
                    self.assertEqual(report['result'], {'ok': True})
                else:
                    self.assertEqual(report['counts'], dict(matched=11, mismatched=0, outOfScope=0,
                                     q11=0, lazyRestriction=0, preparationFailure=0))

    def test_corpus12_builders_require_regeneration(self):
        for tool in ('desugarDiff', 'builtinCheck', 'surfaceCheck', 'surfaceCheckAll'):
            result, _ = self.run_tool(tool)
            self.assertEqual(result.returncode, 2, result.stdout)
            self.assertIn('builder syntax requires exchange version 13; regenerate with version 13', result.stderr)

    def test_old_versions_reject_nested_builder_information(self):
        for f in FILES:
            for version in ([8, 9, 10, 11] if f == 'corpus' else [2, 3, 4]):
                for field in ('builderBind', 'builderOp', 'refs', 'newRef', 'getRef', 'setRef'):
                    data = copy.deepcopy(self.data)
                    data['corpus']['inputs'][0]['definitions'] = []
                    data[f]['version'] = version
                    data[f]['deep'] = [{'unknown': {field: None}}]
                    tool = next(t for t, fs in TOOLS.items() if f in fs)
                    with self.subTest(file=f, version=version, field=field):
                        result, _ = self.run_tool(tool, data)
                        self.assertEqual(result.returncode, 2, result.stdout)
                        self.assertIn(f'new exchange version: {field}', result.stderr)

    def test_corpus11_batch2_and_sidecar_versions(self):
        self.data = builder_free(self.data)
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
            for v in ((0, 1, 5, 6, 7, 15) if f == 'corpus' else (0, 1, 7, 8, 13)):
                data = copy.deepcopy(self.data)
                data[f]['version'] = v
                tool = next(t for t, fs in TOOLS.items() if f in fs)
                result, _ = self.run_tool(tool, data)
                self.assertEqual(result.returncode, 2, result.stdout)
                self.assertIn('version', result.stderr)

    def test_monad2_wrong_super_and_error_type(self):
        self.data = builder_free(self.data)
        for key, mutation in [('fn:220', 'super'), ('fn:223', 'error')]:
            data = copy.deepcopy(self.data)
            call = definition(data, key)['surface']['body']['last']['expr']['returnE']['inner']['call']
            if mutation == 'super': call['callee']['methName']['dict']['super']['cls'] = 'Missing'
            else: call['callee']['methName']['tys'][1] = {'base': {'name': 'Integer'}}
            result, report = self.run_tool('surfaceCheck', data, key)
            self.assertEqual(result.returncode, 1, result.stderr + json.dumps(report))
            self.assertFalse(report['result']['ok'])


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
    version = data['corpus']['version']
    if version not in (12, 13, 14):
        raise AssertionError('expected corpus12, corpus13 or corpus14')
    for f, doc in data.items():
        if doc['version'] != (version if f == 'corpus' else (6 if version == 14 else 5 if version == 13 else 4)):
            raise AssertionError(f'{f}: corpus/sidecar version mismatch')
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
