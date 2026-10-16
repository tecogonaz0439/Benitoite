"""属性・型表示と本体ごとの view を六入口の公開境界で検査する。"""
import copy
import json
from pathlib import Path
import runpy
import tempfile
import unittest

# -I で実行しても、共有の六入口の呼び出しを同じファイルから読む。
shared = runpy.run_path(str(Path(__file__).with_name('test_named_exchange.py')))
TOOLS = shared['TOOLS']
FILES = shared['FILES']


def legacy(data):
    """属性のない旧形式の正の入力。新版の欄を完全に除く。"""
    def strip(value, kind):
        if isinstance(value, list):
            return [strip(x, kind) for x in value]
        if not isinstance(value, dict):
            return value
        return {k: strip(v, kind) for k, v in value.items()
                if k not in ('builtin', 'package', 'coverageView', 'extensible', 'isRecord', 'dataTypes')
                and not (k in ('typeName', 'constructorName') and kind != 'coverage')}
    result = {k: strip(v, k) for k, v in data.items()}
    for k, v in result.items():
        v['version'] = 8 if k == 'corpus' else 2
    return result


def drop_view_names(value, names):
    if isinstance(value, list):
        for item in value: drop_view_names(item, names)
    elif isinstance(value, dict):
        if 'coverageView' in value:
            value['coverageView'] = [n for n in value['coverageView'] if n not in names]
        for item in value.values(): drop_view_names(item, names)


class ExtensibleExchangeTests(unittest.TestCase):
    def setUp(self):
        fixtures = Path(__file__).with_name('extensible-exchange')
        self.data = {name: json.loads((fixtures / f'{name}.json').read_text()) for name in FILES}
        self.tmp = tempfile.TemporaryDirectory(prefix='benitoite-extensible-exchange-')
        self.addCleanup(self.tmp.cleanup)
        self.directory = Path(self.tmp.name)

    def run_tool(self, tool, data=None, selected=None, input_name='independent-extensible'):
        return shared['ExchangeTests'].run_tool(self, tool, data, selected, input_name)

    def test_six_entries_share_author_external_and_record_views(self):
        for tool in TOOLS:
            with self.subTest(tool=tool):
                result, report = self.run_tool(tool)
                self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
                if tool == 'desugarDiff':
                    self.assertEqual(report['golden']['definitions'],
                                     {'matched': 6, 'mismatched': 0, 'outside': 0, 'excluded': 0})
                elif tool == 'surfaceCheck':
                    self.assertEqual(report['result'], {'ok': True})
                elif tool == 'surfaceCheckAll':
                    self.assertEqual(report['counts'], {'matched': 6, 'mismatched': 0, 'outOfScope': 0,
                                     'q11': 0, 'lazyRestriction': 0, 'preparationFailure': 0})
                elif tool.startswith('coverage'):
                    self.assertEqual((report['mismatched'], report['fuelExhausted']), (0, 0))
                else:
                    self.assertEqual(report['errors'], [])

    def test_closed_legacy_input_is_accepted_by_all_entries(self):
        data = {name: json.loads((Path(__file__).with_name('named-exchange') / f'{name}.json').read_text())
                for name in FILES}
        for tool in TOOLS:
            with self.subTest(tool=tool):
                result, _ = self.run_tool(tool, legacy(data), input_name='independent-named')
                self.assertEqual(result.returncode, 0, result.stderr + result.stdout)

    def test_old_versions_reject_new_information_even_when_empty(self):
        closed = {name: json.loads((Path(__file__).with_name('named-exchange') / f'{name}.json').read_text())
                  for name in FILES}
        for tool, files in TOOLS.items():
            for field, value in [('coverageView', []), ('extensible', False),
                                 ('isRecord', False), ('typeName', 'Unused'), ('package', 'unused'),
                                 ('builtin', 'ordinary'), ('dataTypes', []), ('constructorName', 'Unused')]:
                with self.subTest(tool=tool, field=field):
                    data = legacy(closed)
                    # 網羅性 2 の typeName は旧来から存在する。新しい型表示の印を添える。
                    if tool == 'coverageDiff' and field in ('typeName', 'constructorName'):
                        data[files[0]]['unusedMetadata'] = {field: value, 'isRecord': False}
                    else:
                        data[files[0]]['unusedMetadata'] = {field: value}
                    result, _ = self.run_tool(tool, data, input_name='independent-named')
                    self.assertEqual(result.returncode, 2, result.stdout)
                    self.assertIn('requires new exchange version', result.stderr)

    def test_required_new_fields_are_not_defaulted(self):
        for tool, files in TOOLS.items():
            for field in ('coverageView', 'extensible', 'typeName', 'isRecord', 'package', 'builtin'):
                if tool == 'desugarDiff' or tool.startswith('surface'):
                    data = copy.deepcopy(self.data)
                    i = data['corpus']['inputs'][0]
                    target = i['definitions'][1]['scope']['inScope']['surface'] if field == 'coverageView' else i['dataTypes'][0]
                elif tool == 'builtinCheck' or tool == 'coverageProgramDiff':
                    data = copy.deepcopy(self.data)
                    target = (data['coverage-program']['inputs'][0]['matches'][1]
                              if field == 'coverageView' and tool == 'coverageProgramDiff'
                              else data['builtins']['inputs'][0]['dataDecls'][0])
                    if tool == 'builtinCheck' and field == 'coverageView':
                        target = data['corpus']['inputs'][0]['definitions'][1]['scope']['inScope']['surface']
                else:
                    data = copy.deepcopy(self.data)
                    target = data['coverage']['cases'][1] if field == 'coverageView' else data['coverage']['cases'][1]['decls'][0]
                with self.subTest(tool=tool, field=field):
                    del target[field]
                    result, report = self.run_tool(tool, data)
                    self.assertEqual(result.returncode, 2, result.stdout)
                    self.assertIn(field, result.stderr + json.dumps(report))

    def test_invalid_views_are_rejected_instead_of_becoming_closed(self):
        for tool in TOOLS:
            for mode in ('unknown', 'closed', 'duplicate'):
                with self.subTest(tool=tool, mode=mode):
                    data = copy.deepcopy(self.data)
                    if tool == 'coverageDiff':
                        target = data['coverage']['cases'][1]
                        ds = target['decls']
                    elif tool == 'coverageProgramDiff':
                        target = data['coverage-program']['inputs'][0]['matches'][1]
                        ds = data['builtins']['inputs'][0]['dataDecls']
                    else:
                        target = data['corpus']['inputs'][0]['definitions'][1]['scope']['inScope']['surface']
                        ds = data['corpus']['inputs'][0]['dataTypes']
                    target['coverageView'] = ['Missing'] if mode == 'unknown' else ['Kind', 'Kind'] if mode == 'duplicate' else ['Kind']
                    if mode == 'closed': ds[0]['extensible'] = False
                    result, report = self.run_tool(tool, data)
                    self.assertEqual(result.returncode, 2, result.stdout)
                    reason = {'unknown': 'unknown coverage view type', 'closed': 'not extensible',
                              'duplicate': 'duplicate coverage view type'}[mode]
                    self.assertIn(reason, result.stderr + json.dumps(report))

    def test_external_match_and_bind_use_their_own_view(self):
        for index, mode in [(0, 'author-to-external'), (1, 'missing-fallback'),
                            (2, 'record-author-to-external'), (4, 'bind'), (5, 'method')]:
            data = copy.deepcopy(self.data)
            s = data['corpus']['inputs'][0]['definitions'][index]['scope']['inScope']['surface']
            if mode in ('missing-fallback', 'method'):
                s['body']['last']['expr']['matchE']['arms'].pop()
            elif mode == 'bind':
                s['body']['bindPat']['pattern'] = {'con': {'name': 'Wrap', 'args': [{'con': {'name': 'Only', 'args': []}}]}}
            else:
                s['coverageView'] = ['Kind', 'Rec', 'Unused']
                s['package'] = 'external'
            for tool in ('surfaceCheck', 'surfaceCheckAll'):
                with self.subTest(tool=tool, mode=mode):
                    result, report = self.run_tool(tool, data)
                    self.assertEqual(result.returncode, 1, result.stderr + result.stdout)
                    reason = (report['result']['error']['reason'] if tool == 'surfaceCheck'
                              else report['mismatchExamples'][0]['error']['reason'])
                    self.assertEqual(reason, 'binding pattern is not exhaustive' if mode == 'bind' else 'match is not exhaustive')
            if mode not in ('bind', 'method'):
                result, report = self.run_tool('surfaceCheck', data, selected=f'fn:{index}')
                self.assertEqual(result.returncode, 1, result.stderr + result.stdout)

    def test_future_display_preserves_type_and_record(self):
        for d, witness in [('Kind', '<future constructor of ErrorKind>'), ('Rec', '<future shape of ParseError>')]:
            data = copy.deepcopy(self.data)
            index = 1 if d == 'Kind' else 2
            case = data['coverage']['cases'][index]
            case['arms'].pop()
            case['expected'] = {'exhaustive': False, 'uncovered': witness, 'unreachable': []}
            case['pattern'] = case['arms'][0]['alts'][0]
            case['irrefutable'] = False
            case['irrefutableWitness'] = witness
            result, report = self.run_tool('coverageDiff', data)
            self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
            self.assertEqual(report['boundaryResults'][index]['lean']['uncovered'], witness)

    def test_nested_future_values_keep_their_type_display(self):
        for mode, witness in [('constructor', 'Wrap(<future constructor of ErrorKind>)'),
                              ('record', 'ParseError(detail: <future constructor of ErrorKind>)'),
                              ('list', '[<future constructor of ErrorKind>, ..]')]:
            with self.subTest(mode=mode):
                data = copy.deepcopy(self.data)
                case = data['coverage']['cases'][1]
                wild = {'kind': 'wild'}
                only = {'kind': 'con', 'name': 'Only', 'args': []}
                rawkind = {'kind': 'data', 'name': 'Kind', 'args': []}
                if mode == 'constructor':
                    case['decls'].append({'builtin': 'ordinary', 'package': 'author', 'name': 'Wrap', 'typeName': 'Wrap', 'isRecord': False,
                        'extensible': False, 'ntys': 0, 'fields': None,
                        'ctors': [{'name': 'Wrap', 'constructorName': 'Wrap', 'tag': 0, 'args': [rawkind]}]})
                    case['ty'] = {'kind': 'data', 'name': 'Wrap', 'args': []}
                    pat = {'kind': 'con', 'name': 'Wrap', 'args': [only]}
                    patterns = [pat]
                elif mode == 'record':
                    case['decls'][1]['ctors'][0]['args'] = [rawkind]
                    case['ty'] = {'kind': 'data', 'name': 'Rec', 'args': []}
                    pat = {'kind': 'con', 'name': 'Rec', 'args': [only]}
                    patterns = [pat]
                else:
                    case['ty'] = {'kind': 'list', 'args': [rawkind]}
                    nil = {'kind': 'list', 'before': [], 'rest': False, 'after': []}
                    pat = {'kind': 'list', 'before': [only], 'rest': True, 'after': []}
                    patterns = [nil, pat]
                case['arms'] = [{'guarded': False, 'alts': [p]} for p in patterns]
                case['expected'] = {'exhaustive': False, 'uncovered': witness, 'unreachable': []}
                # 束縛は別の契約であり、ここでは既存の wild の検査を保つ。
                result, report = self.run_tool('coverageDiff', data)
                self.assertEqual(result.returncode, 0, result.stderr + result.stdout + json.dumps(report['mismatches']))
                self.assertEqual(report['boundaryResults'][1]['lean']['uncovered'], witness)

    def test_metadata_disagreement_and_empty_new_table_are_rejected(self):
        for tool in ('builtinCheck', 'surfaceCheck', 'surfaceCheckAll'):
            for mode in ('attribute', 'record', 'display', 'empty', 'missing'):
                with self.subTest(tool=tool, mode=mode):
                    data = copy.deepcopy(self.data)
                    ds = data['corpus']['inputs'][0]['dataTypes']
                    # 未使用の型も全宣言の対応から落とさない。
                    if mode == 'attribute':
                        ds[2]['extensible'] = False
                        for d in data['corpus']['inputs'][0]['definitions']:
                            view = d['scope']['inScope']['surface']['coverageView']
                            if 'Unused' in view: view.remove('Unused')
                    elif mode == 'record': ds[2]['isRecord'] = True
                    elif mode == 'display': ds[2]['typeName'] = 'ForgedError'
                    elif mode == 'missing': ds.pop(0)
                    else: ds.clear()
                    # 空表のときは、view 参照も空にして表の対応だけを検査する。
                    if mode == 'missing': drop_view_names(data['corpus'], ['Kind'])
                    if mode == 'empty':
                        for d in data['corpus']['inputs'][0]['definitions']:
                            d['scope']['inScope']['surface']['coverageView'] = []
                    result, report = self.run_tool(tool, data)
                    self.assertEqual(result.returncode, 2, result.stdout)
                    self.assertIn('missing data type metadata' if mode in ('empty', 'missing') else 'data type metadata mismatch', result.stderr + json.dumps(report))

    def test_record_flag_must_agree_with_constructor_fields(self):
        for tool in ('builtinCheck', 'coverageDiff', 'coverageProgramDiff', 'surfaceCheck', 'surfaceCheckAll'):
            with self.subTest(tool=tool):
                data = copy.deepcopy(self.data)
                if tool == 'coverageDiff':
                    data['coverage']['cases'][1]['decls'][1]['isRecord'] = False
                else:
                    data['builtins']['inputs'][0]['dataDecls'][1]['isRecord'] = False
                result, _ = self.run_tool(tool, data)
                self.assertEqual(result.returncode, 2, result.stdout)
                self.assertIn('isRecord/fields mismatch', result.stderr)

    def test_program_coverage_uses_view_for_match_and_binding(self):
        for mode in ('match', 'binding'):
            with self.subTest(mode=mode):
                data = copy.deepcopy(self.data)
                i = data['coverage-program']['inputs'][0]
                if mode == 'match':
                    i['matches'][1]['arms'].pop()
                else:
                    i['bindings'][0]['pattern'] = {'con': {'name': 'Only', 'args': []}}
                result, report = self.run_tool('coverageProgramDiff', data)
                self.assertEqual(result.returncode, 1, result.stderr + result.stdout)
                self.assertEqual((report['matched'], report['mismatched'], report['outOfScope'],
                                  report['fuelExhausted']), (3, 1, 0, 0))
                outcome = report['mismatches'][0]['outcome']['detail']
                self.assertEqual(outcome['uncovered'], '<future constructor of ErrorKind>')

    def test_synthetic_superclass_unit_is_not_a_function_body(self):
        data = copy.deepcopy(self.data)
        h = {'tparams': [], 'neffs': 0, 'names': [], 'params': [],
             'ret': {'base': {'name': 'Unit'}}, 'eff': []}
        data['corpus']['inputs'][0]['definitions'].append({
            'name': 'I supers (impl:0)', 'scope': {'inScope': {
                'surface': {'header': h, 'body': 'empty', 'dictParams': [],
                            'implementation': 'I', 'method': None, 'supers': [], 'coverageView': [], 'package': 'author'},
                'core': {'header': h, 'body': {'ret': {'value': {'const': {'value': 'unit'}}}},
                         'lambdaEffects': [], 'supers': []}}}})
        for tool in ('desugarDiff', 'surfaceCheck', 'surfaceCheckAll'):
            with self.subTest(tool=tool):
                result, report = self.run_tool(tool, data)
                self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
                if tool == 'desugarDiff':
                    self.assertEqual(report['golden']['definitions'],
                                     {'matched': 7, 'mismatched': 0, 'outside': 0, 'excluded': 0})

    def test_body_and_constant_packages_are_required(self):
        for tool in ('desugarDiff', 'builtinCheck', 'surfaceCheck', 'surfaceCheckAll'):
            for kind in ('function', 'constant'):
                with self.subTest(tool=tool, kind=kind):
                    data = copy.deepcopy(self.data)
                    i = data['corpus']['inputs'][0]
                    if kind == 'function':
                        del i['definitions'][0]['scope']['inScope']['surface']['package']
                    else:
                        i['constants'] = [{'name': 'unused', 'ty': {'base': {'name': 'Unit'}},
                                           'body': 'unit'}]
                    result, report = self.run_tool(tool, data)
                    self.assertEqual(result.returncode, 2, result.stdout)
                    self.assertIn('package', result.stderr + json.dumps(report))

    def test_package_rule_rejects_missing_or_spurious_view_types(self):
        # 外部の型の指定漏れを、Rust と Lean が共に見逃す退行を防ぐ。
        for tool in TOOLS:
            for mode in ('missing', 'author'):
                with self.subTest(tool=tool, mode=mode):
                    data = copy.deepcopy(self.data)
                    if tool == 'coverageDiff':
                        target = data['coverage']['cases'][1]
                    elif tool == 'coverageProgramDiff':
                        target = data['coverage-program']['inputs'][0]['matches'][1]
                    else:
                        target = data['corpus']['inputs'][0]['definitions'][1]['scope']['inScope']['surface']
                    if mode == 'missing':
                        target['coverageView'].remove('Kind')
                    else:
                        target['package'] = 'author'
                    result, report = self.run_tool(tool, data)
                    self.assertEqual(result.returncode, 2, result.stdout)
                    self.assertIn('coverage view/package mismatch', result.stderr + json.dumps(report))

    def test_result_and_option_cannot_be_opened(self):
        # 表示名から標準型の同一性を推測する退行も防ぐ。
        for tool in TOOLS:
            for builtin in ('result', 'option'):
                with self.subTest(tool=tool, builtin=builtin):
                    data = copy.deepcopy(self.data)
                    tables = ([case['decls'] for case in data['coverage']['cases']] if tool == 'coverageDiff'
                              else [data['corpus']['inputs'][0]['dataTypes'],
                                    data['builtins']['inputs'][0]['dataDecls']])
                    for table in tables:
                        table[0]['builtin'] = builtin
                    result, report = self.run_tool(tool, data)
                    self.assertEqual(result.returncode, 2, result.stdout)
                    self.assertIn('Result/Option must be closed', result.stderr + json.dumps(report))

    def test_desugar_rejects_missing_data_metadata_without_sidecar(self):
        data = copy.deepcopy(self.data)
        i = data['corpus']['inputs'][0]
        i['dataTypes'].clear()
        for d in i['definitions']:
            d['scope']['inScope']['surface']['coverageView'] = []
        result, report = self.run_tool('desugarDiff', data)
        self.assertEqual(result.returncode, 2, result.stdout)
        self.assertIn('missing data type metadata: Kind', result.stderr + json.dumps(report))

    def test_duplicate_function_and_method_views_are_rejected(self):
        for index in (0, 5):
            with self.subTest(index=index):
                data = copy.deepcopy(self.data)
                d = copy.deepcopy(data['corpus']['inputs'][0]['definitions'][index])
                surface = d['scope']['inScope']['surface']
                surface['package'] = 'external' if index == 0 else 'author'
                surface['coverageView'] = ['Kind', 'Rec', 'Unused'] if index == 0 else []
                data['corpus']['inputs'][0]['definitions'].append(d)
                result, report = self.run_tool('desugarDiff', data)
                self.assertEqual(result.returncode, 2, result.stdout)
                self.assertIn('duplicate body coverage view', result.stderr + json.dumps(report))

    def test_legacy_sidecars_reject_new_fields(self):
        closed = {name: json.loads((Path(__file__).with_name('named-exchange') / f'{name}.json').read_text())
                  for name in FILES}
        for tool in ('builtinCheck', 'coverageProgramDiff', 'surfaceCheck', 'surfaceCheckAll'):
            for key in TOOLS[tool][1:]:
                with self.subTest(tool=tool, sidecar=key):
                    data = legacy(closed)
                    data[key]['inputs'][0]['unusedType'] = {'extensible': True}
                    result, _ = self.run_tool(tool, data, input_name='independent-named')
                    self.assertEqual(result.returncode, 2, result.stdout)
                    self.assertIn('requires new exchange version: extensible', result.stderr)

    def test_builtin_identity_is_unique_and_standard(self):
        for tool in TOOLS:
            for mode in ('duplicate', 'package'):
                with self.subTest(tool=tool, mode=mode):
                    data = copy.deepcopy(self.data)
                    tables = ([data['coverage']['cases'][0]['decls']] if tool == 'coverageDiff'
                              else [data['corpus']['inputs'][0]['dataTypes'],
                                    data['builtins']['inputs'][0]['dataDecls']])
                    for table in tables:
                        for n in (0, 1) if mode == 'duplicate' else (0,):
                            table[n].update(builtin='option', extensible=False, package='stdlib')
                        if mode == 'package': table[0]['package'] = 'author'
                    drop_view_names(data, ['Kind', 'Rec'] if mode == 'duplicate' else ['Kind'])
                    result, report = self.run_tool(tool, data)
                    self.assertEqual(result.returncode, 2, result.stdout)
                    self.assertIn('duplicate builtin data type' if mode == 'duplicate' else
                                  'builtin data type must belong to stdlib', result.stderr + json.dumps(report))

    def test_builtin_constructor_shape_is_checked(self):
        for tool in ('builtinCheck', 'coverageDiff', 'coverageProgramDiff', 'surfaceCheck', 'surfaceCheckAll'):
            for builtin in ('result', 'option'):
                for mode in ('name', 'args', 'params', 'record', 'count', 'missing-name'):
                    with self.subTest(tool=tool, builtin=builtin, mode=mode):
                        data = copy.deepcopy(self.data)
                        names = ['Ok', 'Error'] if builtin == 'result' else ['Some', 'None']
                        params = [[0], [1]] if builtin == 'result' else [[0], []]
                        raw = tool == 'coverageDiff'
                        ctors = [{'name': f'Builtin{n}', 'constructorName': name,
                                  **({'tag': n} if raw else {'fields': None}),
                                  'args': [({'kind': 'param', 'index': i} if raw else
                                            {'tvar': {'index': i}}) for i in args]}
                                 for n, (name, args) in enumerate(zip(names, params))]
                        decl = {'name': 'Builtin', 'typeName': 'UnrelatedDisplay', 'package': 'stdlib',
                                'builtin': builtin, 'isRecord': False, 'extensible': False,
                                'ntys': 2 if builtin == 'result' else 1, 'ctors': ctors}
                        if raw: decl['fields'] = None
                        if mode == 'name': ctors[0]['constructorName'] = 'Wrong'
                        elif mode == 'args': ctors[0]['args'] = []
                        elif mode == 'params': decl['ntys'] += 1
                        elif mode == 'record': decl['isRecord'] = True
                        elif mode == 'count': ctors.pop()
                        else: del ctors[0]['constructorName']
                        if raw:
                            data['coverage']['cases'][0]['decls'].append(decl)
                        else:
                            data['builtins']['inputs'][0]['dataDecls'].append(decl)
                            data['corpus']['inputs'][0]['dataTypes'].append(
                                {k: decl[k] for k in ('name', 'typeName', 'package', 'builtin', 'isRecord', 'extensible')})
                        result, report = self.run_tool(tool, data)
                        self.assertEqual(result.returncode, 2, result.stdout)
                        self.assertIn('constructorName' if raw and mode == 'missing-name' else
                                      'invalid builtin constructor shape', result.stderr + json.dumps(report))

    def test_constants_cannot_hide_source_matches_or_bindings(self):
        for tool in ('desugarDiff', 'builtinCheck', 'surfaceCheck', 'surfaceCheckAll'):
            for mode in ('match', 'binding'):
                with self.subTest(tool=tool, mode=mode):
                    data = copy.deepcopy(self.data)
                    body = (data['corpus']['inputs'][0]['definitions'][0]['scope']['inScope']['surface']['body']['last']['expr']
                            if mode == 'match' else {'lam': {'names': [], 'params': [],
                                'ret': {'base': {'name': 'Unit'}}, 'eff': [],
                                'body': {'lastPat': {'shadow': False, 'pattern': 'wild',
                                    'ty': {'base': {'name': 'Unit'}}, 'expr': 'unit'}}}})
                    data['corpus']['inputs'][0]['constants'] = [{'name': 'unused', 'package': 'author',
                        'ty': {'base': {'name': 'Unit'}}, 'body': {'paren': {'inner': body}}}]
                    result, report = self.run_tool(tool, data)
                    self.assertEqual(result.returncode, 2, result.stdout)
                    self.assertIn('source match/binding in constant', result.stderr + json.dumps(report))

    def test_version_pairs_must_agree(self):
        for tool in ('builtinCheck', 'coverageProgramDiff', 'surfaceCheck', 'surfaceCheckAll'):
            for key in TOOLS[tool][1:]:
                with self.subTest(tool=tool, sidecar=key):
                    data = copy.deepcopy(self.data)
                    data[key] = legacy(self.data)[key]
                    result, _ = self.run_tool(tool, data)
                    self.assertEqual(result.returncode, 2, result.stdout)
                    self.assertIn('exchange version pair mismatch', result.stderr)


if __name__ == '__main__':
    unittest.main()
