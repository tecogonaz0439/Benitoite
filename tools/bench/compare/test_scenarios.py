"""Tool contracts: deterministic fixtures, acceptance arithmetic and fail-closed verification."""
import copy
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

from analysis import evaluate, increment, ratio, summary
from scenarios import corpus, select_tier, target_ids
from model import Case, common
from features import configure
from run import materialize, validate, verify_group


class GeneratorTests(unittest.TestCase):
    def test_every_generated_byte_is_reproducible(self):
        def fingerprint():
            return [(c.id, c.params, {v: {p: hashlib.sha256(s.encode()).hexdigest() for p, s in files.items()} for v, files in c.files.items()}) for c in corpus(False)]
        first = fingerprint()
        self.assertEqual(first, fingerprint())
        self.assertEqual(len(first), len({item[0] for item in first}))

    def test_matrix_and_api_boundaries(self):
        cases = corpus(False)
        main = [c for c in cases if c.section == '16.2' and c.family == 'main' and not c.codes]
        self.assertEqual({c.n for c in main}, {0, 1, 8, 10, 32, 64, 100, 256, 1000, 1250, 2500, 5000, 10000, 20000})
        properties = [c for c in cases if c.id.startswith('property-')]
        self.assertEqual(len(properties), 3*4*4*4*2)
        for c in properties:
            self.assertNotIn('maxShrinkWork:', c.sources('legacy')['main.bnt'])
            self.assertIn('maxShrinkWork:', c.sources('modern')['main.bnt'])
        modules = next(c for c in cases if c.id == 'functions-modules-1250-0')
        self.assertEqual(len(modules.sources('legacy')), 14)
        self.assertEqual(modules.sources('legacy')['main.bnt'].count('import Part'), 13)

    def test_interval_check_points_and_load_controls(self):
        # 関門: 新系列の測定漏れと、標準ロード固定費を空対照へ混ぜる退行を防ぐ。
        # 既存の全族の検査は各系列の代表点や対照の対応までは拘束しない。
        families = {'interval-'+name for name in ('bind', 'add', 'flow', 'range', 'http')}
        families.update('interval-width-'+name for name in (
            'Integer8', 'Integer16', 'Integer32', 'Integer64',
            'UnsignedInteger16', 'UnsignedInteger32', 'UnsignedInteger64'))
        full = corpus(False)
        index = {c.id: c for c in full}
        for quick in (False, True):
            generated = corpus(quick)
            selected = select_tier(generated, 'short', quick=quick)
            intervals = [c for c in selected if c.family.startswith('interval-')]
            self.assertEqual({c.family for c in intervals}, families)
            for family in families:
                self.assertEqual({c.n for c in intervals if c.family == family and c.n},
                                 {1, 8, 32} if quick else {64, 256}, family)
            ids = {c.id for c in selected}
            for n in ((0, 1, 8, 32) if quick else (0, 64, 256)):
                self.assertIn(f'functions-main-{n}-0', ids)
                c = next(c for c in selected if c.id == f'functions-main-{n}-0')
                self.assertEqual(c.params['source_bytes'],
                                 sum(len(s.encode()) for s in c.sources('legacy').values()))
            for c in intervals:
                self.assertEqual(c.command, 'check')
                self.assertEqual(c.codes, ())
                self.assertFalse(c.requires)
                source = c.sources('legacy')['main.bnt']
                self.assertEqual(c.files['legacy'], c.files['modern'])
                self.assertEqual(c.params['source_bytes'], len(source.encode()))
                control = index[c.params['control_case']]
                self.assertIn(control.id, ids)
                control_source = control.sources('legacy')['main.bnt']
                self.assertEqual([s for s in source.splitlines() if s.startswith('import ')],
                                 [s for s in control_source.splitlines() if s.startswith('import ')])
                self.assertNotIn(' bind ', control_source)

    def test_short_proposals_preserve_every_goal_input(self):
        full = corpus(False, fixtures=Path('.'))
        declaration = next(iter([*Path('docs').glob('*syntax-batch3/bench-targets.json'),
                                 *Path('docs/archive').glob('*syntax-batch3/bench-targets.json')]))
        config = json.loads(declaration.read_text())
        for suite in ('targets',):
            selected = {c.id for c in select_tier(full, suite, config)}
            for family in ('main',):
                for n in (0, 5000, 10000, 20000):
                    self.assertIn(f'functions-{family}-{n}-0', selected)
            for failure in (0, 1):
                for n in (0, 450, 900, 1800):
                    self.assertIn(f'higher-{failure}-{n}', selected)
            for distribution in ('seven', 'distinct', 'zero', 'max'):
                for n in (88, 256):
                    for mode in ('all-ok', 'always-error'):
                        self.assertIn(f'property-{distribution}-{n}-20-1000-{mode}', selected)

    def test_materialization_refuses_changed_input(self):
        with tempfile.TemporaryDirectory() as temp:
            case = Case('example', '16.2', 'main', 1, common('one'))
            case.states = ('old',)
            _, paths = materialize(Path(temp), [case])
            paths[case.id, 'old'].write_text('two')
            with self.assertRaisesRegex(RuntimeError, 'generated input changed'):
                materialize(Path(temp), [case])


class GoalTests(unittest.TestCase):
    def test_median_not_best_sample(self):
        self.assertEqual(summary([1, 3, 5, 100])['median'], 4)

    def test_noise_prevents_spurious_speedup(self):
        self.assertIsNone(increment(summary([.9, 1.1]), summary([.85, 1.05])))
        self.assertEqual(ratio(None, 1, .25, 'test')['status'], '判定不能')
        self.assertEqual(ratio(1, 0, .25, 'test')['status'], '判定不能')
        self.assertEqual(ratio(1, 4, .25, 'test')['status'], '達成')
        self.assertEqual(ratio(1.01, 4, .25, 'test')['status'], '未達')

    def test_r17_increments_and_r19_typeck_are_separate(self):
        m = {}
        for state, slope in (('old', 4), ('map', 1), ('final', 1)):
            for n in (0, 5000, 10000, 20000):
                m[f'functions-main-{n}-0'] = m.get(f'functions-main-{n}-0', {})
                m[f'functions-main-{n}-0'][state] = {'cli': [10 + slope*n/10000]*10}
        for state, seconds in (('map', 4), ('solve', 3)):
            m.setdefault('higher-0-900', {})[state] = {'typeck': [seconds]*10, 'cli': [100]*10}
        def median(cid, state, metric='cli'):
            return dict(op='median', case=cid, state=state, metric=metric)
        def inc(cid, state):
            return dict(op='difference', left=median(cid,state), right=median('functions-main-0-0',state))
        def goal(label,a,b):
            return dict(label=label,kind='ratio',expression=dict(op='ratio',left=a,right=b),limit=1)
        config = dict(min_samples=10,targets=[
            goal('R17 map/old I(10000)',inc('functions-main-10000-0','map'),inc('functions-main-10000-0','old')),
            goal('R17 map I(20000)/I(10000)',inc('functions-main-20000-0','map'),inc('functions-main-10000-0','map')),
            goal('R19 higher-0 typeck(900) solve/map',median('higher-0-900','solve','typeck'),median('higher-0-900','map','typeck')),
            goal('R22 seven/all-ok final/old n=88',median('missing','final'),median('missing','old'))])
        result = {g['label']: g for g in evaluate(config, m)}
        self.assertEqual(result['R17 map/old I(10000)']['value'], .25)
        self.assertEqual(result['R17 map I(20000)/I(10000)']['value'], 2)
        self.assertEqual(result['R19 higher-0 typeck(900) solve/map']['value'], .75)
        self.assertEqual(result['R22 seven/all-ok final/old n=88']['status'], '判定不能')


class VerificationTests(unittest.TestCase):
    def test_output_mismatch_is_fatal(self):
        c = Case('bad', '16.2', 'main', 1, common(''))
        a = dict(status=0, stdout='', stderr='')
        b = dict(a, stdout='changed')
        with self.assertRaisesRegex(RuntimeError, 'output mismatch'):
            verify_group(c, dict(old=a, map=b))
        with self.assertRaises(RuntimeError):
            validate(c, 'old', b)

    def test_work_and_trial_budgets_are_independent(self):
        c = next(c for c in corpus(True) if c.id == 'property-seven-24-20-1000-all-ok')
        valid = dict(status=0, stderr='', stdout='reduced=' + '[' + ', '.join(['7']*24) + ']\nmessage=bad\nshrinks=20\nshrinkWork=100\nlimitReached=true\n')
        validate(c, 'modern', valid)
        for old, new in (('shrinks=20', 'shrinks=21'), ('shrinkWork=100', 'shrinkWork=1001')):
            with self.assertRaises(RuntimeError):
                validate(c, 'modern', dict(valid, stdout=valid['stdout'].replace(old, new)))

    def test_builder_value_checked_against_independent_expectation(self):
        c = next(c for c in corpus(True) if c.id == 'build-string-builder-4-0')
        validate(c, 'modern', dict(status=0, stdout='8\n', stderr=''))
        with self.assertRaisesRegex(RuntimeError, 'wrong builder result'):
            validate(c, 'modern', dict(status=0, stdout='7\n', stderr=''))


class NewFamilyContracts(unittest.TestCase):
    # 関門: 自由な比較手法が builders の有無で落ちる退行と、R/2R の入力差を防ぐ。
    def test_builder_requirements_and_dynamic_repeat_identity(self):
        from scenarios import builders
        for case in builders.cases(False):
            builder = case.params.get('method', '').startswith('builder')
            self.assertEqual(bool(case.requires), builder, case.id)
            self.assertEqual('import Benitoite.'+dict(string='StringBuilder',list='ListBuilder',bytes='BytesBuilder').get(case.family,'none') in case.files['legacy']['main.bnt'], builder, case.id)
        cases = {c.id:c for c in builders.repeated_cases(False)}
        for cid, case in cases.items():
            if '-r64-' in cid:
                other = cases[cid.replace('-r64-', '-r128-')]
                self.assertEqual(case.files, other.files)
                self.assertEqual(case.expected_stdout, other.expected_stdout)
                self.assertEqual(case.arguments, ('64',))
                self.assertEqual(other.arguments, ('128',))
        case = cases['build-string-repeat-128-4-r64-builder']
        value = dict(status=0,stdout=case.expected_stdout,stderr='')
        validate(case,'after',value)
        with self.assertRaises(RuntimeError): validate(case,'after',dict(value,stdout=case.expected_stdout.replace('p0000雪','p0000違',1)))

    def test_bridge_graph_counts_and_independent_validation(self):
        from scenarios import bridge
        for n in (16,32,64):
            g = bridge.graph('nodes',n)
            self.assertEqual(len(g['nodes']), n)
            self.assertEqual(sum(map(len,g['nodes'])), 2*(n-1))
            self.assertTrue(all(child < i for i, edges in enumerate(g['nodes']) for child in edges))
        case = next(c for c in bridge.cases() if c.id == 'bridge-nodes-16')
        fields = dict(bridge_to_heap=.01,bridge_from_heap=.02,bridge_time=.03,allocated_bytes=200,unique_nodes=16,heap_nodes=16,edges=30,observation=7)
        result = dict(status=0,stderr='',stdout=json.dumps(fields))
        validate(case,'after',result)
        for key in ('unique_nodes','heap_nodes','edges','observation'):
            with self.assertRaises(RuntimeError): validate(case,'after',dict(result,stdout=json.dumps(dict(fields,**{key:0}))))


if __name__ == '__main__':
    unittest.main()
