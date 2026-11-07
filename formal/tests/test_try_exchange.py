"""corpus 10 の処置・辞書・説明・exit を、独立の期待コアと六入口で検査する。"""
import copy
import json
from pathlib import Path
import runpy
import tempfile
import unittest

shared = runpy.run_path(str(Path(__file__).with_name('test_named_exchange.py')))
TOOLS = shared['TOOLS']
CORPUS_TOOLS = ('desugarDiff', 'builtinCheck', 'surfaceCheck', 'surfaceCheckAll')


def surface(data, index=0):
    return data['corpus']['inputs'][0]['definitions'][index]['scope']['inScope']['surface']


def payload(data, index=0):
    expr = surface(data, index)['body']['last']['expr']['returnE']['inner']
    if 'conCall' in expr:
        expr = expr['conCall']['args'][0]
    return next(iter(expr.values()))


class TryExchangeTests(unittest.TestCase):
    def setUp(self):
        fixtures = Path(__file__).with_name('try-exchange')
        self.data = {name: json.loads((fixtures / f'{name}.json').read_text())
                     for name in shared['FILES']}
        self.tmp = tempfile.TemporaryDirectory(prefix='benitoite-try-exchange-')
        self.addCleanup(self.tmp.cleanup)
        self.directory = Path(self.tmp.name)

    def run_tool(self, tool, data=None, selected=None):
        return shared['ExchangeTests'].run_tool(self, tool, data, selected, 'independent-try')

    def test_six_entries_accept_new_try_information(self):
        for tool in TOOLS:
            with self.subTest(tool=tool):
                result, report = self.run_tool(tool)
                self.assertEqual(result.returncode, 0, result.stderr + result.stdout + json.dumps(report))
                if tool == 'desugarDiff':
                    self.assertEqual(report['golden']['definitions'],
                                     dict(matched=11, mismatched=0, outside=0, excluded=0))
                    self.assertEqual(report['mismatches'], [])
                elif tool == 'builtinCheck':
                    self.assertEqual(report['errors'], [])
                    self.assertEqual(report['summaryMismatchCount'], 0)
                elif tool.startswith('coverage'):
                    self.assertEqual((report['matched'], report['mismatched'], report['fuelExhausted']), (2, 0, 0))
                elif tool == 'surfaceCheck':
                    self.assertEqual(report['result'], {'ok': True})
                else:
                    self.assertEqual(report['counts'], dict(matched=11, mismatched=0, outOfScope=0,
                                     q11=0, lazyRestriction=0, preparationFailure=0))

    def test_missing_try_fields_are_not_defaulted(self):
        for index, fields in [(0, ('ty', 'ok', 'err', 'dict', 'showMethod', 'exit', 'inner', 'message')),
                              (2, ('ty', 'someCon', 'noneCon', 'exit', 'inner', 'message'))]:
            for field in fields:
                for tool in CORPUS_TOOLS:
                    with self.subTest(index=index, field=field, tool=tool):
                        data = copy.deepcopy(self.data)
                        del payload(data, index)[field]
                        result, report = self.run_tool(tool, data)
                        self.assertEqual(result.returncode, 2, result.stderr + result.stdout)
                        self.assertIn(field, result.stderr + json.dumps(report))
        for index in (5, 7):
            for tool in CORPUS_TOOLS:
                with self.subTest(index=index, action=True, tool=tool):
                    data = copy.deepcopy(self.data)
                    e = surface(data, index)['body']['last']['expr']['returnE']['inner']['conCall']['args'][0]
                    e['unknownTryAction'] = e.pop(next(iter(e)))
                    result, report = self.run_tool(tool, data)
                    self.assertEqual(result.returncode, 2, result.stderr + result.stdout)
                    self.assertIn('unknown Expr constructor', result.stderr + json.dumps(report))

    def test_old_versions_are_rejected(self):
        for tool, files in TOOLS.items():
            for field in files:
                for version in (range(8, 16) if field == 'corpus' else range(2, 8)):
                    data = copy.deepcopy(self.data)
                    data[field]['version'] = version
                    with self.subTest(tool=tool, field=field, version=version):
                        result, _ = self.run_tool(tool, data)
                        self.assertEqual(result.returncode, 2, result.stdout)
                        self.assertIn('version', result.stderr)

    def test_current_input_and_old_version_refusal(self):
        for tool in TOOLS:
            with self.subTest(tool=tool):
                result, report = self.run_tool(tool)
                self.assertEqual(result.returncode, 0, result.stderr + json.dumps(report))
                data = copy.deepcopy(self.data)
                first = TOOLS[tool][0]
                data[first]['version'] = 15 if first == 'corpus' else 7
                result, _ = self.run_tool(tool, data)
                self.assertEqual(result.returncode, 2, result.stdout)
                self.assertIn('version', result.stderr)

    def test_try_cannot_silently_drop_other_action_fields(self):
        for index, field, value in [(0, 'action', 'return'), (0, 'messageExtra', None),
                                    (2, 'dict', {'local': {'index': 2}}),
                                    (4, 'message', None), (5, 'exit', 'prim:8')]:
            for tool in CORPUS_TOOLS:
                with self.subTest(index=index, field=field, tool=tool):
                    data = copy.deepcopy(self.data)
                    payload(data, index)[field] = value
                    result, report = self.run_tool(tool, data)
                    self.assertEqual(result.returncode, 2, result.stderr + result.stdout)
                    self.assertIn('unexpected try', result.stderr + json.dumps(report))
        for tool in CORPUS_TOOLS:
            with self.subTest(ambiguous=True, tool=tool):
                data = copy.deepcopy(self.data)
                expr = surface(data)['body']['last']['expr']['returnE']['inner']
                expr['tryOption'] = {'retArgs': [], 'someCon': 'con:some',
                                     'noneCon': 'con:none', 'inner': 'unit'}
                result, report = self.run_tool(tool, data)
                self.assertEqual(result.returncode, 2, result.stderr + result.stdout)
                self.assertIn('ambiguous try action', result.stderr + json.dumps(report))

    def test_checker_checks_exchanged_die_contracts(self):
        impure = {'call': {'callee': {'primName': {'name': 'prim:8',
                   'tys': [{'base': {'name': 'String'}}], 'effs': [], 'ranges': []}},
                   'labels': [None], 'positions': [0],
                   'args': [{'literal': {'value': {'integer': {'value': 1}}}}]}}
        # 篩付きの検査器の拒否の理由。辞書でない局所の値は呼出しの頭を解決できず、表示のメソッドと終了の組込みの
        # 誤りは呼出しの署名の誤り、表示の型と効果の誤りは案内の再検査の失敗として断る。
        cases = [('dict', {'local': {'index': 1}}, 'call head cannot be resolved'),
                 ('showMethod', 'show', 'call signature is invalid'),
                 ('exit', 'exit', 'call signature is invalid'),
                 ('message', {'local': {'index': 1}}, 'type or certificate check failed'),
                 ('message', impure, 'type or certificate check failed')]
        for field, value, reason in cases:
            for tool in ('surfaceCheck', 'surfaceCheckAll'):
                with self.subTest(field=field, tool=tool):
                    data = copy.deepcopy(self.data)
                    payload(data)[field] = value
                    result, report = self.run_tool(tool, data)
                    self.assertEqual(result.returncode, 1, result.stderr + result.stdout)
                    error = (report['result']['error'] if tool == 'surfaceCheck'
                             else report['mismatchExamples'][0]['error'])
                    self.assertEqual(error['reason'], reason)
                    # 篩付きの検査器の位置は、二つの入口で同じ（定義の根からの番号）である。
                    self.assertEqual(error['path'], [0, 0, 1] if field == 'message' else [0, 0, 1, 0, 0])
                    if tool == 'surfaceCheckAll':
                        self.assertEqual(report['counts']['mismatched'], 1)

    def test_comparison_preserves_dictionary_references_and_message_lambdas(self):
        for index, mode in [(0, 'local'), (9, 'implementation'), (8, 'effects'), (8, 'message'), (10, 'effects'), (2, 'empty-message')]:
            with self.subTest(mode=mode):
                data = copy.deepcopy(self.data)
                core = data['corpus']['inputs'][0]['definitions'][index]['scope']['inScope']['core']
                if mode == 'effects': core['lambdaEffects'] = []
                elif mode == 'empty-message':
                    payload(data, index)['message'] = {'literal': {'value': {'string': {'value': ''}}}}
                elif mode == 'message':
                    core['body']['letIn']['body']['matchC']['arms'][1]['mk']['body']['letIn']['bound'] = {'ret': {'value': {'var': {'index': 0}}}}
                else:
                    d = core['body']['letIn']['body']['matchC']['arms'][1]['mk']['body']['letIn']['bound']['meth']['dict']
                    if mode == 'local': d['var']['index'] = 2
                    else: d['dict']['name'] = 'renamed-Show'
                result, report = self.run_tool('desugarDiff', data)
                self.assertEqual(result.returncode, 1, result.stderr + result.stdout)
                self.assertEqual(len(report['mismatches']), 1)
                self.assertNotEqual(report['mismatches'][0]['expected'], report['mismatches'][0]['actual'])

    def test_remaining_entries_report_independent_mismatches(self):
        for tool in ('builtinCheck', 'coverageDiff', 'coverageProgramDiff'):
            with self.subTest(tool=tool):
                data = copy.deepcopy(self.data)
                if tool == 'builtinCheck':
                    data['corpus']['inputs'][0]['primOps'][0]['names'] = ['wrong']
                elif tool == 'coverageDiff':
                    data['coverage']['cases'][0]['expected']['exhaustive'] = False
                else:
                    data['coverage-program']['inputs'][0]['matches'][0]['arms'] = []
                result, report = self.run_tool(tool, data)
                self.assertEqual(result.returncode, 1, result.stderr + result.stdout)
                if tool == 'builtinCheck':
                    self.assertEqual(report['errors'], ['golden/independent-try: prim:8: operation signature mismatch'])
                else:
                    self.assertEqual(report['mismatched'], 1)


if __name__ == '__main__':
    unittest.main()
