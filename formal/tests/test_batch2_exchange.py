"""11/4 の独立入力を六入口で照合する。Rust の局所出力は明示した場合だけ読む。"""
import argparse
import copy
import json
from pathlib import Path
import runpy
import tempfile
import unittest

shared = runpy.run_path(str(Path(__file__).with_name('test_named_exchange.py')))
SOURCES = runpy.run_path(str(Path(__file__).with_name('test_range_sources.py')))
GAPS = SOURCES['preparation_gaps']
FILES, TOOLS = shared['FILES'], shared['TOOLS']
FIXTURES = Path(__file__).with_name('batch2-exchange')


class Batch2ExchangeTests(unittest.TestCase):
    def setUp(self):
        self.data = {f: json.loads((FIXTURES / f'{f}.json').read_text()) for f in FILES}
        self.tmp = tempfile.TemporaryDirectory(prefix='benitoite-batch2-exchange-')
        self.addCleanup(self.tmp.cleanup)
        self.directory = Path(self.tmp.name)

    def run_tool(self, tool, data=None, selected=None):
        return shared['ExchangeTests'].run_tool(self, tool, data, selected, 'independent-batch2')

    def test_six_entries(self):
        for tool in TOOLS:
            with self.subTest(tool=tool):
                result, report = self.run_tool(tool)
                self.assertEqual(result.returncode, 0, result.stderr + result.stdout + json.dumps(report))
                if tool == 'desugarDiff':
                    self.assertEqual(report['golden']['definitions'], dict(matched=7, mismatched=0, outside=0, excluded=0))
                    self.assertEqual(report['mismatches'], [])
                elif tool == 'builtinCheck':
                    self.assertEqual(report['errors'], [])
                    self.assertEqual(report['summaryMismatchCount'], 0)
                elif tool.startswith('coverage'):
                    self.assertEqual((report['matched'], report['mismatched'], report['fuelExhausted']), (3 if tool == 'coverageDiff' else 2, 0, 0))
                elif tool == 'surfaceCheck':
                    self.assertEqual(report['result'], {'ok': True})
                else:
                    self.assertEqual(report['counts'], dict(matched=7, mismatched=0, outOfScope=0,
                                     q11=0, lazyRestriction=0, preparationFailure=0))

    def test_required_fields_and_old_versions(self):
        for tool, files in TOOLS.items():
            for file in files:
                for version in ([8, 9, 10] if file == 'corpus' else [2, 3]):
                    with self.subTest(tool=tool, file=file, version=version):
                        data = copy.deepcopy(self.data)
                        data[file]['version'] = version
                        result, _ = self.run_tool(tool, data)
                        self.assertEqual(result.returncode, 2, result.stdout)
                        self.assertIn('version', result.stderr)
        for field in ('effParams',):
            data = copy.deepcopy(self.data)
            del shared['surface'](data, 0)['header'][field]
            for tool in ('desugarDiff', 'builtinCheck', 'surfaceCheck', 'surfaceCheckAll'):
                with self.subTest(tool=tool, missing=field):
                    result, _ = self.run_tool(tool, data)
                    self.assertEqual(result.returncode, 2, result.stdout)
                    self.assertIn(field, result.stderr)

    def test_dictionary_and_nofail_rejections(self):
        for kind in ('dict-index', 'missing-dicts', 'row-count', 'row-type', 'row-contract', 'row-index', 'fail-arity'):
            with self.subTest(kind=kind):
                data = copy.deepcopy(self.data)
                i = data['corpus']['inputs'][0]
                if kind == 'dict-index': i['ops'][-1]['dictParams'][0][1] = 1
                elif kind == 'missing-dicts': del i['ops'][-1]['dictParams']
                elif kind == 'row-count': shared['surface'](data, 3)['header']['effParams'] = []
                elif kind == 'row-type': shared['surface'](data, 3)['header']['effParams'] = [{'noFail': 0}]
                elif kind == 'row-contract': shared['surface'](data, 3)['header']['effParams'] = [{'noFail': False}]
                elif kind == 'row-index': shared['surface'](data, 3)['header']['eff'][-1]['rho']['index'] = 1
                else: shared['surface'](data, 1)['header']['eff'][0]['args'] = []
                result, report = self.run_tool('surfaceCheck', data)
                self.assertEqual(result.returncode, 2, result.stderr + json.dumps(report))
                self.assertTrue(result.stderr)

    def test_checker_rejects_wrong_error_and_dictionary(self):
        # 篩付きの検査器の拒否の理由: 誤りの型の違いは再検査の失敗、辞書の欠けは依存する引数の署名の不一致として断る。
        for kind, message in [('error', 'type or certificate check failed'), ('dict', 'dependent argument signature mismatch')]:
            with self.subTest(kind=kind):
                data = copy.deepcopy(self.data)
                if kind == 'error':
                    shared['expr'](data, 1)['call']['callee']['raise']['error'] = {'base': {'name': 'Integer'}}
                else:
                    shared['expr'](data, 4)['call']['callee']['opDicts']['dicts'] = []
                result, report = self.run_tool('surfaceCheck', data)
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertFalse(report['result']['ok'])
                self.assertIn(message, report['result']['error']['reason'])

    def test_clause_metadata_and_scope(self):
        for field in ('dictCount', 'failureType'):
            data = copy.deepcopy(self.data)
            clause = shared['expr'](data, 6)['handleE']['clauses'][0]
            del clause[field]
            for tool in ('desugarDiff', 'surfaceCheck', 'surfaceCheckAll', 'builtinCheck'):
                with self.subTest(tool=tool, field=field):
                    result, _ = self.run_tool(tool, data)
                    self.assertEqual(result.returncode, 2, result.stderr)
                    self.assertIn(field, result.stderr)
        for field, value in [('dictCount', 0), ('ntys', 2), ('arity', 2)]:
            data = copy.deepcopy(self.data)
            shared['expr'](data, 6)['handleE']['clauses'][0][field] = value
            result, _ = self.run_tool('desugarDiff', data)
            self.assertEqual(result.returncode, 2, result.stderr)
            self.assertIn('clause signature mismatch', result.stderr)
        data = copy.deepcopy(self.data)
        evidence = shared['expr'](data, 6)['handleE']['clauses'][0]['body']['discard']['expr']['opDicts']['dicts'][0]['clause']
        evidence['constraint'] = 1
        result, report = self.run_tool('surfaceCheck', data)
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertEqual(report['result']['error']['reason'], 'clause dictionary scope mismatch')

    def test_failure_normalization_keeps_distinct_types(self):
        data = copy.deepcopy(self.data)
        scope = data['corpus']['inputs'][0]['definitions'][3]['scope']['inScope']
        integer = {'kind': 'fail', 'error': {'base': {'name': 'Integer'}}}
        scope['surface']['header']['eff'].append(integer)
        effects = scope['surface']['header']['eff']
        scope['core']['header']['eff'] = list(reversed(effects)) + [integer]
        result, report = self.run_tool('desugarDiff', data)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(report['golden']['definitions'], dict(matched=7, mismatched=0, outside=0, excluded=0))
        # Releaseの補助上限を読めても、表層の具体化後の単一Failは別に検査する。
        result, report = self.run_tool('surfaceCheck', data)
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertEqual(report['result']['error']['reason'], 'type or certificate check failed')
        scope['core']['header']['eff'] = effects[:-1]
        result, report = self.run_tool('desugarDiff', data)
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertEqual(len(report['mismatches']), 1)
        self.assertEqual(report['mismatches'][0]['definition'], 'batch2 (fn:103)')

    def test_missing_rust_output_is_not_success(self):
        with self.assertRaises(FileNotFoundError):
            check_rust(self.directory / 'missing')

    def test_rust_output_rejects_old_and_mismatched_versions(self):
        for stale in (FILES, *((f,) for f in FILES)):
            with self.subTest(stale=stale):
                data = copy.deepcopy(self.data)
                for f, document in data.items():
                    document['version'] = ((12 if f == 'corpus' else 4) if f in stale
                                           else (16 if f == 'corpus' else 8))
                    (self.directory / f'{f}.json').write_text(json.dumps(document))
                with self.assertRaisesRegex(AssertionError, f'{stale[0]}: expected batch2 version'):
                    check_rust(self.directory)


def surface_gaps(tool, result, report, corpus):
    """表層の検査の準備の段が、標準表との差（分類の表の原因）だけで断ったときの原因。ほかは None。全件の入口は、
    残りの入力の照合（不一致0・準備の失敗の件数・末尾の照合の件数）を `classified_all` で行う。"""
    if result.returncode != 2:
        return None
    if tool == 'surfaceCheck':
        return GAPS(result.stdout + result.stderr)
    return SOURCES['classified_all'](report, corpus) if report is not None else None


def check_rust(directory):
    """O2/F3 の出力が存在し、今の版（16/8）と六入口の実比較を満たすことを確かめる。表層の検査の準備の段が
    標準表との差で断った入力は、最初の失敗で止めず、原因とともに分類して返す。"""
    data = {f: json.loads((directory / f'{f}.json').read_text()) for f in FILES}
    # Rust の出力は今の交換器の 16/8 だけを要求する。
    for f, document in data.items():
        if document['version'] != (16 if f == 'corpus' else 8):
            raise AssertionError(f'{f}: expected batch2 version')
    inputs = [i for i in data['corpus']['inputs'] if not i['excluded']]
    if not inputs or not any(i['definitions'] for i in inputs):
        raise AssertionError('Rust batch2 corpus must contain definitions')
    rejected = []
    case = Batch2ExchangeTests()
    case.setUp()
    try:
        for tool in TOOLS:
            if tool == 'surfaceCheck':
                for i in inputs:
                    result, report = shared['ExchangeTests'].run_tool(case, tool, data, None, i['name'])
                    if i['group'] != 'golden':
                        raise AssertionError('local batch2 inputs must use group golden')
                    gaps = surface_gaps(tool, result, report, data['corpus'])
                    if gaps is not None:
                        rejected.append({'tool': tool, 'input': i['name'], **gaps})
                        continue
                    case.assertEqual(result.returncode, 0, result.stderr + json.dumps(report))
                    case.assertEqual(report['result'], {'ok': True})
            else:
                result, report = case.run_tool(tool, data)
                gaps = surface_gaps(tool, result, report, data['corpus']) if tool == 'surfaceCheckAll' else None
                if gaps is not None:
                    rejected.append({'tool': tool, **gaps})
                    # 残りの入力の照合は classified_all が行った。範囲外・遅延の制限・Q11 の分類も0とする。
                    for key in ('outOfScope', 'lazyRestriction', 'q11'):
                        case.assertEqual(report['counts'][key], 0)
                    continue
                case.assertEqual(result.returncode, 0, result.stderr + result.stdout + json.dumps(report))
                if tool == 'desugarDiff':
                    case.assertEqual(report['mismatches'], [])
                elif tool.startswith('coverage'):
                    case.assertGreater(report['matched'], 0)
                    case.assertEqual((report['mismatched'], report['fuelExhausted']), (0, 0))
                elif tool == 'surfaceCheckAll':
                    case.assertGreater(report['counts']['matched'], 0)
                    for key in ('mismatched', 'preparationFailure', 'outOfScope', 'lazyRestriction', 'q11'):
                        case.assertEqual(report['counts'][key], 0)
    finally:
        case.doCleanups()
    if rejected:
        print(f'batch2 {directory.name}: surface checks rejected at preparation: {json.dumps(rejected)}')
    return rejected


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--rust-dir', type=Path)
    args, rest = parser.parse_known_args()
    result = unittest.main(argv=[__file__, *rest], exit=False).result
    if not result.wasSuccessful():
        raise SystemExit(1)
    if args.rust_dir is not None:
        check_rust(args.rust_dir)
