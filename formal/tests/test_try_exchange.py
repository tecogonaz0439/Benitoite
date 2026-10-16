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

    def test_old_corpus_rejects_new_actions_even_when_nested(self):
        for version in (8, 9):
            for tag in ('tryResultDie', 'tryOptionDie', 'tryResultReturn', 'tryOptionReturn'):
                for tool in CORPUS_TOOLS:
                    with self.subTest(version=version, tag=tag, tool=tool):
                        data = copy.deepcopy(self.data)
                        data['corpus']['version'] = version
                        # Reject before decoding, including new tags hidden in unused constants.
                        data['corpus']['inputs'][0]['constants'] = [{'nested': {tag: {}}}]
                        result, report = self.run_tool(tool, data)
                        self.assertEqual(result.returncode, 2, result.stderr + result.stdout)
                        self.assertIn('field requires new exchange version:', result.stderr + json.dumps(report))

    def test_corpus_nine_remains_compatible_without_new_actions(self):
        data = {name: json.loads((Path(__file__).with_name('named-exchange') / f'{name}.json').read_text())
                for name in shared['FILES']}
        data['corpus']['version'] = 9
        for tool in TOOLS:
            with self.subTest(tool=tool):
                result, report = shared['ExchangeTests'].run_tool(
                    self, tool, data, input_name='independent-named')
                self.assertEqual(result.returncode, 0, result.stderr + result.stdout + json.dumps(report))

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
                   'tys': [{'base': {'name': 'String'}}], 'effs': []}},
                   'labels': [None], 'positions': [0],
                   'args': [{'literal': {'value': {'integer': {'value': 1}}}}]}}
        cases = [('dict', {'local': {'index': 1}}, 'expected a dictionary type'),
                 ('showMethod', 'show', 'unknown die display method'),
                 ('exit', 'exit', 'unknown die exit primitive'),
                 ('message', {'local': {'index': 1}}, 'type is not included in the expected type'),
                 ('message', impure, 'effect exceeds the allowed effect')]
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
                    suffix = [] if field == 'exit' else [1] if field == 'message' else [2]
                    self.assertEqual(error['path'], ([0, 0, 0, 0, 0] if tool == 'surfaceCheck'
                                                     else [0, 0, 0]) + suffix)
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
