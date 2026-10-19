"""Public contracts for arbitrary state counts, probes, cache keys and JSON targets."""
import copy
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from analysis import evaluate, expression
from build import build_key, evidence
from features import configure, probe_features
from model import Case, common
from run import materialize, arguments
from scenarios import corpus


def median(cid='x', state='new', metric='cli'):
    return dict(op='median', case=cid, state=state, metric=metric)


class EvaluationTests(unittest.TestCase):
    def setUp(self):
        self.measurements = {'x': {'new': {'cli':[2,2,2]}, 'old': {'cli':[4,4,4]}}}

    def check_goal(self, goal, status, value=None):
        result = evaluate(dict(min_samples=3, targets=[dict(label='g',**goal)]), self.measurements)[0]
        self.assertEqual(result['status'], status)
        if value is not None: self.assertAlmostEqual(result['value'],value)
        return result

    def test_each_numerical_goal_kind(self):
        for kind in ('ratio','growth'):
            self.check_goal(dict(kind=kind, expression=dict(op='ratio',left=median(),right=median(state='old')),limit=.5),'達成',.5)
            self.check_goal(dict(kind=kind, expression=dict(op='ratio',left=median(),right=median(state='old')),limit=.49),'未達',.5)
        self.check_goal(dict(kind='difference',expression=dict(op='difference',left=median(state='old'),right=median()),limit=2),'達成',2)
        self.check_goal(dict(kind='regression',old=median(state='old'),new=median(),relative=.1,absolute_seconds=.002),'達成',-2)
        self.measurements['x']['new']['cli']=[4.5]*3
        self.check_goal(dict(kind='regression',old=median(state='old'),new=median(),relative=.1,absolute_seconds=.002),'未達',.5)
        self.measurements['x']['new']['cli']=[.002]*3
        self.measurements['x']['old']['cli']=[.001]*3
        self.assertEqual(self.check_goal(dict(kind='regression',old=median(state='old'),new=median(),relative=.1,absolute_seconds=.002),'達成')['threshold'],.002)

    def test_signed_difference_and_noisy_regression(self):
        self.check_goal(dict(kind='difference', expression=dict(op='difference', left=median(), right=median(state='old')), limit=0), '達成', -2)
        self.measurements['x']['new']['cli']=[3,4,5]
        self.measurements['x']['old']['cli']=[3,4,5]
        self.check_goal(dict(kind='regression', old=median(state='old'), new=median(), relative=.1, absolute_seconds=.002), '判定不能')

    def test_missing_insufficient_and_noisy_differences_are_inconclusive(self):
        config=dict(kind='ratio',expression=dict(op='ratio',left=dict(op='difference',left=median(),right=median(state='old')),right=median(state='old')),limit=.5)
        self.check_goal(config,'判定不能')
        self.measurements['x']['new']['cli']=[3,4,5]
        self.measurements['x']['old']['cli']=[2.9,3.9,4.9]
        self.check_goal(config,'判定不能')
        self.measurements['x']['new']['cli']=[10]
        self.check_goal(config,'判定不能')
        self.check_goal(dict(kind='ratio',expression=dict(op='ratio',left=median('absent'),right=median()),limit=2),'判定不能')
        self.assertIsNone(expression(dict(op='ratio',left=1,right=0),{},3))

    def test_output_invariant_all_repeats_and_missing_field(self):
        c=Case('x','example','sample',1,common(''),params=dict(limit=4))
        goal=dict(label='budget',kind='invariant',select=dict(section='example'),field='work',parameter='limit')
        outputs={'x':{'any':dict(stdout='work=4\nwork=5\n')}}
        config=dict(targets=[goal])
        result=evaluate(config,{},outputs,[c])[0]
        self.assertEqual(result['status'],'未達')
        self.assertEqual(result['checked'],2)
        self.assertEqual(result['violations'][0]['value'],5)
        outputs['x']['any']['stdout']='work=0\nwork=4\n'
        self.assertEqual(evaluate(config,{},outputs,[c])[0]['status'],'達成')
        self.assertEqual(evaluate(config,{}, {},[c])[0]['status'],'判定不能')


class FeatureAndStateTests(unittest.TestCase):
    def test_probes_use_actual_check_output_and_keep_evidence(self):
        with tempfile.TemporaryDirectory() as tmp:
            def execute(cmd, timeout):
                self.assertEqual(cmd[1:3],['check','--diagnostics=json'])
                source=Path(cmd[-1]).read_text()
                supported='maxShrinkWork:' in source
                return dict(status=0 if supported else 2,stdout='',stderr='' if supported else json.dumps(dict(code='E1',severity='error'))+'\n')
            result=probe_features('arbitrary-binary',Path(tmp),1,execute)
            self.assertTrue(result['shrink_steps']['supported'])
            self.assertFalse(result['builders']['supported'])
            self.assertIn('sha256',result['shrink_steps'])
            with self.assertRaises(RuntimeError):
                probe_features('broken',Path(tmp),1,lambda *_:dict(status=-9,stdout='',stderr=''))

    def test_two_or_four_arbitrary_names_and_variants(self):
        for count in (2,4):
            with self.subTest(count=count), tempfile.TemporaryDirectory() as tmp:
                features={f'rev{i}':dict(shrink_steps=bool(i%2),builders=bool(i%2)) for i in range(count)}
                cases=corpus(True)
                skipped=configure(cases,features)
                manifest,entries=materialize(Path(tmp),cases,features)
                c=next(c for c in cases if c.id=='property-seven-24-20-1000-all-ok')
                self.assertEqual(c.states,tuple(features))
                self.assertNotIn('maxShrinkWork:', entries[c.id,'rev0'].read_text())
                self.assertIn('maxShrinkWork:', entries[c.id,'rev1'].read_text())
                self.assertTrue(any(x['state']=='rev0' and x['case']=='build-string-builder-4-0' for x in skipped))
                self.assertTrue(all(len(row['inputs'])==count for row in manifest if row['section']=='16.2'))
                self.assertTrue(all(count//2==len(c.states) for c in cases if c.requires))

    def test_manifest_roundtrip_keeps_state_order_for_resume(self):
        with tempfile.TemporaryDirectory() as tmp:
            c=Case('x','s','f',1,common('hello'), states=('a','b'))
            rows,_=materialize(Path(tmp),[c])
            self.assertEqual(rows,json.loads(json.dumps(rows)))
            self.assertEqual(rows[0]['states'],['a','b'])

    def test_command_arguments_are_materialized(self):
        c=Case('file','runtime','lines',1,common(''),arguments=('{input}/lines.txt','17'))
        self.assertEqual(arguments(c,Path('/tmp/example/main.bnt')),['/tmp/example/lines.txt','17'])


class BuildTests(unittest.TestCase):
    def test_each_cache_identity_component_invalidates(self):
        values=['a'*40,'default','rustc version','cargo version','hash']
        key=build_key(*values)
        for i in range(len(values)):
            changed=values.copy(); changed[i]+='changed'
            self.assertNotEqual(key,build_key(*changed))
        self.assertEqual(key,build_key(*values))

    def test_refs_are_resolved_and_only_self_version_is_ignored(self):
        base=b'[[package]]\nname = "benitoite"\nversion = "0.0.8"\n\n[[package]]\nname = "dependency"\nversion = "1.0"\n'
        def fake_git(*args):
            if args[0]=='rev-parse': return b'a'*40+b'\n'
            return base.replace(b'0.0.8', b'0.0.9') if args[-1].startswith('a') else base
        with patch('build.git',fake_git):
            for count in (2,4):
                result=evidence([f's{i}=HEAD' for i in range(count)])
                self.assertEqual(len(result['commits']),count)
                self.assertEqual(set(result['commits'].values()),{'a'*40})
            with self.assertRaises(ValueError): evidence(['x=HEAD','x=HEAD'])
        def differing(*args):
            if args[0]=='rev-parse': return (b'a' if args[-1].startswith('first') else b'b')*40+b'\n'
            return base if args[-1].startswith('a') else base.replace(b'1.0',b'2.0')
        with patch('build.git',differing):
            with self.assertRaisesRegex(RuntimeError,'dependency records differ'):
                evidence(['x=first','y=second'])



class PersistentCacheTests(unittest.TestCase):
    def test_reuse_invalidates_and_failed_public_probe_is_explicit(self):
        import io
        import subprocess
        import tarfile
        from build import build_all, ROOT
        lock=b'lock bytes'
        data=io.BytesIO()
        with tarfile.open(fileobj=data,mode='w') as tf:
            for name,contents in [('Cargo.lock',lock),('Cargo.toml',b'package')]:
                info=tarfile.TarInfo(name);info.size=len(contents)
                tf.addfile(info,io.BytesIO(contents))
        def git(*args):
            return data.getvalue() if args[0]=='archive' else lock
        def check_output(cmd,**kwargs):
            return 'rustc example' if cmd[0]=='rustc' else 'cargo example'
        def run(cmd,**kwargs):
            if cmd[0]=='cargo':
                self.assertEqual(kwargs['cwd'],ROOT)
                target=Path(cmd[cmd.index('--target-dir')+1])/'release'
                target.mkdir(exist_ok=True);(target/'benitoite').write_bytes(b'binary')
                return subprocess.CompletedProcess(cmd,0)
            return subprocess.CompletedProcess(cmd,1)
        with tempfile.TemporaryDirectory() as tmp, patch('build.git',git), patch('build.subprocess.check_output',check_output), patch('build.subprocess.run',side_effect=run) as calls:
            cache=Path(tmp)
            first=build_all({'before':'a'*40},cache=cache)['before']
            self.assertIn('public API helper build failed', first['probe_unavailable'])
            self.assertFalse(first['reused'])
            count=calls.call_count
            again=build_all({'renamed':'a'*40},cache=cache)['renamed']
            self.assertTrue(again['reused'])
            self.assertEqual(calls.call_count,count)
            Path(again['binary']).write_bytes(b'tampered')
            self.assertFalse(build_all({'x':'a'*40},cache=cache)['x']['reused'])
            self.assertGreater(calls.call_count,count)


class TierTests(unittest.TestCase):
    def test_full_confirmation_is_required_before_build(self):
        import subprocess
        result = subprocess.run(['python3', str(Path(__file__).with_name('run.py')),
                                 '--state', 'a=HEAD', '--state', 'b=HEAD', '--tier', 'full'],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)
        self.assertIn('--confirm-full', result.stderr)
        self.assertNotIn('build default', result.stdout)

    def test_short_guard_and_actual_calibration(self):
        from run import enforce_short_budget, short_estimate
        small = short_estimate({'x': {'a': {'seconds': .1}, 'b': {'seconds': .1}}}, 5)
        enforce_short_budget(small)
        large = short_estimate({'x': {'a': {'seconds': 50}, 'b': {'seconds': 50}}}, 5)
        with self.assertRaisesRegex(RuntimeError, 'reduce short points'):
            enforce_short_budget(large)
        with self.assertRaises(RuntimeError):
            enforce_short_budget(dict(cached_total_seconds=1, missing_cases=['x']))

    def test_short_has_every_registered_family_and_two_state_goals(self):
        from scenarios import FAMILIES, select_tier
        from run import short_targets
        full = corpus(False)
        short = select_tier(full, 'short')
        for family in FAMILIES:
            ids = {c.id for c in family.cases(False)}
            self.assertTrue(any(c.id in ids for c in short), family.__name__)
        config = short_targets(short, {'before': 'a', 'after': 'b'}, 5)
        self.assertEqual(len(config['targets']), len(short))
        self.assertEqual(config['targets'][0]['old']['state'], 'before')
        self.assertEqual(config['targets'][0]['new']['state'], 'after')

    def test_runtime_calibration_and_nonlinear_work_models(self):
        from run import work_ratio
        from scenarios import runtime
        from dataclasses import asdict
        quick={c.family:c for c in runtime.cases(True)}
        self.assertEqual(quick['loop'].n,runtime.SHORT['loop'])
        self.assertGreater(quick['fib'].n,runtime.SIZES['fib'][0])
        big=Case('x','runtime','tree',22,common(''))
        self.assertGreater(work_ratio(big,asdict(quick['tree'])),1000)
        big.family='fib';big.n=35
        self.assertGreater(work_ratio(big,asdict(quick['fib'])),1000)
        big.family='loop';big.n=20000000
        self.assertEqual(work_ratio(big,asdict(quick['loop'])),200)

    def test_targets_select_only_explicit_points_and_expression_leaves(self):
        from scenarios import select_tier
        cases = [Case('x','a','f',1,common('')), Case('y','a','f',2,common('')), Case('z','a','f',3,common(''))]
        config = dict(cases=['x'], targets=[dict(expression=median('y'))])
        self.assertEqual([c.id for c in select_tier(cases, 'targets', config)], ['x','y'])
        with self.assertRaisesRegex(ValueError,'unknown target cases'):
            select_tier(cases, 'targets', dict(cases=['absent']))


if __name__ == '__main__':
    unittest.main()
