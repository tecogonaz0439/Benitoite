"""corpus14/sidecar6の独立交換入力を六入口で検査する。Cargoは起動しない。

作成時の関門: 交換の版・必須欄・型と書式・固定署名・引数順が独立した契約である。
既存入力にはformattedがなく、指定の読み落としや精度省略の0への変換を捕まえない。
手書きの期待コアと本物の六CLIを使い、公開範囲や検査用フラグは増やさない。
"""
import argparse
import copy
import json
from pathlib import Path
import runpy
import tempfile
import unittest

shared = runpy.run_path(str(Path(__file__).with_name('test_named_exchange.py')))
FILES, TOOLS = shared['FILES'], shared['TOOLS']
FIXTURES = Path(__file__).with_name('batch5-exchange')


def surface(data, index=0):
    return data['corpus']['inputs'][0]['definitions'][index]['scope']['inScope']['surface']


def interpolation(data, index=0):
    return surface(data, index)['body']['last']['expr']['returnE']['inner']['interpolation']


def spec(data, index=0):
    return interpolation(data, index)['parts'][1]['formatted']['spec']


class Batch5ExchangeTests(unittest.TestCase):
    def setUp(self):
        self.data = {f: json.loads((FIXTURES / f'{f}.json').read_text()) for f in FILES}
        self.tmp = tempfile.TemporaryDirectory(prefix='benitoite-batch5-exchange-')
        self.addCleanup(self.tmp.cleanup)
        self.directory = Path(self.tmp.name)

    def run_tool(self, tool, data=None, selected=None):
        return shared['ExchangeTests'].run_tool(self, tool, data, selected, 'independent-batch5')

    def test_six_entries(self):
        for tool in TOOLS:
            with self.subTest(tool=tool):
                result, report = self.run_tool(tool)
                self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
                if tool == 'desugarDiff':
                    self.assertEqual(report['golden']['definitions'],
                                     dict(matched=29, mismatched=0, outside=0, excluded=0))
                    self.assertEqual(report['mismatches'], [])
                elif tool == 'builtinCheck':
                    self.assertEqual(report['errors'], [])
                    self.assertEqual(report['summaryMismatchCount'], 0)
                elif tool.startswith('coverage'):
                    self.assertEqual((report['matched'], report['mismatched'], report['fuelExhausted']), (1, 0, 0))
                elif tool == 'surfaceCheck':
                    self.assertEqual(report['result'], {'ok': True})
                else:
                    self.assertEqual(report['counts'], dict(matched=29, mismatched=0, outOfScope=0,
                                     q11=0, lazyRestriction=0, preparationFailure=0))
                    self.assertTrue(report['q11Agrees'])

    def test_invalid_specs_and_types(self):
        cases = [dict(width=0), dict(width=65536), dict(precision=29, kind='f'),
                 dict(precision=0), dict(width=None), dict(align='left', width=None),
                 dict(align='right', zero=True), dict(alternate=True),
                 dict(kind='f'), dict(kind='s'), dict(kind='c'),
                 dict(kind='unknown'), dict(align='unknown'), dict(sign='unknown'),
                 dict(width=-1), dict(precision=-1, kind='f')]
        for changed in cases:
            data = copy.deepcopy(self.data)
            spec(data).update(changed)
            with self.subTest(changed=changed):
                result, _ = self.run_tool('desugarDiff', data)
                self.assertEqual(result.returncode, 2, result.stdout)
                if changed.get('width') == -1 or changed.get('precision') == -1:
                    self.assertIn('Nat', result.stderr)
                else:
                    self.assertIn('invalid format', result.stderr)
        # 空指定、非数の符号・ゼロ埋め、Unit・型変数・構造型を受け入れない。
        for index, changed, ty in [(0, dict(width=None), None),
                                  (11, dict(sign='plus'), None), (13, dict(zero=True), None),
                                  (0, {}, {'base': {'name': 'Unit'}}),
                                  (0, {}, {'tvar': {'index': 0}}),
                                  (0, {}, {'list': {'elem': {'base': {'name': 'Integer'}}}})]:
            data = copy.deepcopy(self.data)
            spec(data, index).update(changed)
            if ty is not None:
                interpolation(data, index)['parts'][1]['formatted']['ty'] = ty
            result, _ = self.run_tool('desugarDiff', data)
            self.assertEqual(result.returncode, 2, result.stdout)
            self.assertIn('invalid formatted interpolation', result.stderr)

    def test_required_fields(self):
        for key in ('kind', 'align', 'sign', 'alternate', 'zero', 'width', 'precision', 'extra'):
            data = copy.deepcopy(self.data)
            if key == 'extra': spec(data)[key] = None
            else: del spec(data)[key]
            with self.subTest(key=key):
                result, _ = self.run_tool('desugarDiff', data)
                self.assertEqual(result.returncode, 2, result.stdout)
                self.assertIn('format spec field', result.stderr)
        for key in ('ty', 'spec', 'extra', 'ambiguous'):
            data = copy.deepcopy(self.data)
            part = interpolation(data)['parts'][1]
            if key == 'ambiguous': part['stringExpr'] = None
            elif key == 'extra': part['formatted'][key] = None
            else: del part['formatted'][key]
            result, _ = self.run_tool('desugarDiff', data)
            self.assertEqual(result.returncode, 2, result.stdout)

    def test_counts_and_direct_head(self):
        for changed in ('expression', 'converter', 'indirect'):
            data = copy.deepcopy(self.data)
            node = interpolation(data)
            if changed == 'expression': node['es'] = []
            elif changed == 'converter': node['converters'] = []
            else: node['converters'] = [{'local': {'index': 0}}]
            result, _ = self.run_tool('desugarDiff', data)
            self.assertEqual(result.returncode, 2, result.stdout)
            self.assertIn('indirect interpolation converter' if changed == 'indirect' else 'count mismatch', result.stderr)

    def test_formatted_head_identity_and_membership(self):
        # 同じ署名を与えても別名や通常関数への差し替えを受理しない。
        for changed in ('wrong-type', 'alias', 'function', 'type-argument', 'missing'):
            data = copy.deepcopy(self.data)
            node = interpolation(data)
            if changed == 'missing':
                data['builtins']['inputs'][0]['prims'] = [
                    p for p in data['builtins']['inputs'][0]['prims'] if p['name'] != '%Format.Integer']
            elif changed == 'function':
                node['converters'][0] = {'funName': {'name': '%Format.Integer', 'tys': [], 'effs': []}}
            elif changed == 'type-argument':
                node['converters'][0]['primName']['tys'] = [{'base': {'name': 'Integer'}}]
            else:
                name = '%Format.String' if changed == 'wrong-type' else 'alias'
                node['converters'][0]['primName']['name'] = name
                entry = copy.deepcopy(data['builtins']['inputs'][0]['prims'][0])
                entry['name'] = name
                if changed == 'alias': data['builtins']['inputs'][0]['prims'].append(entry)
            with self.subTest(changed=changed):
                tool = 'surfaceCheck' if changed == 'missing' else 'desugarDiff'
                result, _ = self.run_tool(tool, data, 'fn:500' if changed == 'missing' else None)
                self.assertEqual(result.returncode, 2, result.stdout)
                self.assertIn('missing format builtin' if changed == 'missing' else 'formatted interpolation', result.stderr)

    def test_format_builtin_signatures(self):
        for changed in ('name', 'names', 'type', 'effect', 'kind', 'polymorphic', 'return'):
            data = copy.deepcopy(self.data)
            p = data['builtins']['inputs'][0]['prims'][0]
            if changed == 'name': p['name'] = '%Format.Unit'
            elif changed == 'names': p['names'][1], p['names'][2] = p['names'][2], p['names'][1]
            elif changed == 'type': p['params'][0] = {'base': {'name': 'String'}}
            elif changed == 'effect': p['eff'] = [{'name': {'value': 'State'}}]
            elif changed == 'kind': p['kind'] = 'io'
            elif changed == 'return': p['ret'] = {'base': {'name': 'Integer'}}
            else: p['neffs'], p['effParams'] = 1, [{'noFail': False}]
            with self.subTest(changed=changed):
                result, _ = self.run_tool('builtinCheck', data)
                self.assertEqual(result.returncode, 2, result.stdout)
                self.assertIn('format builtin', result.stderr)

    def test_old_versions_reject_formatted_at_any_depth(self):
        for f in FILES:
            for version in (range(8, 14) if f == 'corpus' else range(2, 6)):
                data = copy.deepcopy(self.data)
                data[f]['version'] = version
                # 未知欄の内側でも読み捨てない。既存欄の互換エラーとは分ける。
                data[f]['nested'] = [{'unknown': {'formatted': {}}}]
                tool = {'corpus': 'desugarDiff', 'builtins': 'builtinCheck', 'stdlib': 'surfaceCheck',
                        'coverage': 'coverageDiff', 'coverage-program': 'coverageProgramDiff'}[f]
                with self.subTest(file=f, version=version):
                    result, _ = self.run_tool(tool, data)
                    self.assertEqual(result.returncode, 2, result.stdout)
                    self.assertIn('regenerate with new version', result.stderr)

    def test_corpus_sidecar_generations(self):
        # formattedを持たない既存入力は8〜14の意味を維持する。
        legacy = runpy.run_path(str(FIXTURES.parent / 'test_extensible_exchange.py'))['legacy']
        for version in range(8, 15):
            directory = 'named-exchange' if version < 11 else 'batch2-exchange'
            data = {f: json.loads((FIXTURES.parent / directory / f'{f}.json').read_text()) for f in FILES}
            input_name = data['corpus']['inputs'][0]['name']
            if version == 8: data = legacy(data)
            data['corpus']['version'] = version
            sidecar = 6 if version >= 14 else 5 if version == 13 else 4 if version >= 11 else 3 if version >= 9 else 2
            for f in FILES[1:]: data[f]['version'] = sidecar
            result, report = shared['ExchangeTests'].run_tool(self, 'surfaceCheck', data, input_name=input_name)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(report['result'], {'ok': True})
            if version == 14:
                data['stdlib']['version'] = 5
                result, _ = shared['ExchangeTests'].run_tool(self, 'surfaceCheck', data, input_name=input_name)
                self.assertEqual(result.returncode, 2, result.stdout)
                self.assertIn('version', result.stderr)


def check_rust(directory, report_path):
    """実ソースの書式を独立した期待表層・コアと六入口で照合する。"""
    checker = runpy.run_path(str(Path(__file__).resolve().parents[2] /
                                'crates/benitoite/tests/desugar_export/check_named.py'))
    require, run = checker['require'], checker['run']
    data = {f: json.loads((directory / f'{f}.json').read_text()) for f in FILES}
    manifest = json.loads((FIXTURES / 'rust-manifest.json').read_text())
    counts = {i['name']: len(i['definitions']) for i in data['corpus']['inputs']}
    require(counts == manifest['inputs'], 'batch5 Rust input counts')
    for f, doc in data.items():
        require(doc['version'] == (15 if f == 'corpus' else 7), f'{f}: version')
    for item in data['corpus']['inputs']:
        require(not item['excluded'], f"{item['name']}: excluded")
        require(all(set(d['scope']) == {'inScope'} for d in item['definitions']), 'batch5 outside')
    for f in ('builtins', 'stdlib', 'coverage-program'):
        require([(i['group'], i['name']) for i in data[f]['inputs']] ==
                [('golden', name) for name in counts], f'{f}: input identity')
    independent = json.loads((FIXTURES / 'corpus.json').read_text())
    actual = data['corpus']['inputs'][0]['definitions']
    for index in range(25):
        got = copy.deepcopy(next(d['scope']['inScope'] for d in actual
                                if d['name'].startswith(f'format{index} (')))
        expected = checker['explicit_top_ranges'](independent['inputs'][0]['definitions'][index]['scope']['inScope'])
        for key in ('package', 'coverageView'): expected['surface'][key] = got['surface'][key]
        # 末尾returnの継続型はRustではUnit。返す値とコアの比較は保持する。
        expected['surface']['body']['last']['expr']['returnE']['ret'] = {'base': {'name': 'Unit'}}
        require(got == expected, f'format{index}: independent surface/core differ')
    formatted, strings = [], 0
    def visit(value):
        nonlocal strings
        if isinstance(value, dict):
            if 'interpolation' in value:
                node = value['interpolation']
                strings += sum(p == 'stringExpr' for p in node['parts'])
                formatted.extend(p['formatted'] for p in node['parts'] if isinstance(p, dict) and 'formatted' in p)
            for child in value.values(): visit(child)
        elif isinstance(value, list):
            for child in value: visit(child)
    visit(data['corpus'])
    formatted_strings = sum(p['ty'] == {'base': {'name': 'String'}} for p in formatted)
    require(len(formatted) == manifest['formatted'] and formatted_strings == manifest['formattedString'],
            'formatted parts lost')
    # mixedの書式なしのStringだけがstringExprになる。
    formatted_string_fallback = strings - manifest['plainString']
    require(formatted_string_fallback == 0, 'formatted String fell back to stringExpr')
    heads = {p['name'] for p in data['builtins']['inputs'][0]['prims'] if p['name'].startswith('%Format.')}
    expected_heads = {p['name'] for p in json.loads((FIXTURES / 'builtins.json').read_text())['inputs'][0]['prims']
                      if p['name'].startswith('%Format.')}
    require(heads == expected_heads and len(heads) == 14, '14 exported format heads')
    # 合併済みの契約とNoFail・本体は個別宣言と同じままE2へ入る。
    file_input, individual = data['corpus']['inputs'][1:]
    for key in ('definitions', 'effects', 'ops', 'primOps', 'constants'):
        require(file_input[key] == individual[key], f'file uses: {key}')
    reports = {}
    for tool, files in TOOLS.items():
        selections = list(counts) if tool == 'surfaceCheck' else [None]
        reports[tool] = []
        for index, name in enumerate(selections):
            args = [directory / f'{f}.json' for f in files]
            if name is not None: args += ['golden', name]
            report = run(tool, args, directory / f'{tool}-{index}-report.json')
            if tool == 'desugarDiff':
                require(report['golden']['definitions'] == dict(matched=manifest['definitions'], mismatched=0,
                        outside=0, excluded=0) and not report['mismatches'], 'batch5 desugar')
            elif tool == 'builtinCheck':
                require(not report['errors'] and report['summaryMismatchCount'] == 0, 'batch5 builtins')
            elif tool.startswith('coverage'):
                require(report['matched'] == manifest[tool] and report['mismatched'] == 0 and
                        report['fuelExhausted'] == 0, f'{tool}: counts')
            elif tool == 'surfaceCheck': require(report['result'] == {'ok': True}, f'E2: {name}')
            else:
                require(report['counts'] == dict(matched=manifest['definitions'], mismatched=0, outOfScope=0,
                        q11=0, lazyRestriction=0, preparationFailure=0), 'batch5 E2 counts')
            reports[tool].append(report)
    require(reports['surfaceCheck'][1]['atoms'] == reports['surfaceCheck'][2]['atoms'],
            'file uses: E2 atoms differ')
    report_path.write_text(json.dumps(dict(inputs=counts, formatted=len(formatted), formattedString=formatted_strings,
        formattedStringFallback=formatted_string_fallback, formatHeads=sorted(heads), results=reports), indent=2) + '\n')
    print(f'batch5: {sum(counts.values())} definitions, {len(formatted)} formatted, '
          f'{formatted_strings} formatted String, {formatted_string_fallback} fallback; '
          f'six entries agree: {report_path}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--rust-dir', type=Path)
    parser.add_argument('--report', type=Path)
    args, rest = parser.parse_known_args()
    result = unittest.main(argv=[__file__, *rest], exit=False).result
    if not result.wasSuccessful(): raise SystemExit(1)
    if args.rust_dir:
        check_rust(args.rust_dir, args.report or args.rust_dir / 'exchange-results.json')
