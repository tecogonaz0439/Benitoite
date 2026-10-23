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


class UnavailableProbeTests(unittest.TestCase):
    def test_failed_compiler_keeps_cli_and_marks_missing_probe_metrics(self):
        # 守る契約はランナーの記録と終了。外部のgit/compiler/processだけを代用し、
        # build・機能判定・入力選択・照合・標本採取・reportは本物を接続する。
        import io
        import subprocess
        import tarfile
        from functools import partial
        from build import ROOT, build_all
        from run import main
        real_check_output, real_run = subprocess.check_output, subprocess.run
        commits = dict(before='a'*40, after='b'*40)
        lock = b'lock bytes'
        archive = io.BytesIO()
        fixtures = ['tools/bench/programs/'+n+'.bnt' for n in ('fib', 'loop', 'string')]
        fixtures += ['crates/benitoite/testdata/handlers/'+n+'.bnt' for n in ('f1-nofail-call', 'f1-join-effects')]
        fixtures += ['crates/benitoite/testdata/external/'+n for n in
                     ('adapter-route/x.wasm', 'resource/x.wasm', 'resource/Lib/Cell.bnt')]
        with tarfile.open(fileobj=archive, mode='w') as tf:
            for name, data in [('Cargo.lock', lock), ('Cargo.toml', b'package'),
                               *((name, (ROOT/name).read_bytes()) for name in fixtures)]:
                info = tarfile.TarInfo(name); info.size = len(data)
                tf.addfile(info, io.BytesIO(data))
        def git(*args):
            if args[0] == 'archive': return archive.getvalue()
            if args[0] == 'rev-parse': return args[-1].split('^')[0].encode()+b'\n'
            return lock
        def check_output(cmd, **kwargs):
            if cmd[0] == 'git': return commits['after'] if cmd[1] == 'rev-parse' else ''
            if cmd[0] in ('rustc', 'cargo'): return cmd[0]+' example'
            return real_check_output(cmd, **kwargs)
        for missing in (('before',), ('before', 'after')):
            with self.subTest(missing=missing), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                def process(cmd, **kwargs):
                    stdout, stderr, status = '', '', 0
                    if cmd[0] == 'cargo':
                        release = Path(cmd[cmd.index('--target-dir')+1])/'release'
                        release.mkdir(exist_ok=True)
                        (release/'benitoite').write_bytes(b'cli')
                    elif cmd[0] == 'rustc':
                        output = Path(cmd[cmd.index('-o')+1])
                        # alloc helper は両版で利用不能。default は片側／両側の二通り。
                        if '-alloc-stats' in str(output) or any(commits[s] in str(output) for s in missing):
                            status = 1
                        else:
                            output.write_bytes(b'probe')
                    elif Path(cmd[0]).name == 'timing-probe':
                        if cmd[2] == 'bridge':
                            stdout = json.dumps(dict(bridge_to_heap=.01, bridge_from_heap=.02,
                                bridge_time=.03, unique_nodes=9, heap_nodes=9, edges=16, observation=7))
                        else:
                            stdout = json.dumps(dict(errors=0, load_parse=.01, reparse=.01, resolve=.01, typeck=.01))
                    elif len(cmd) > 1 and cmd[1].endswith('rss.py'):
                        if Path(cmd[2]).name == 'timing-probe':
                            stdout = process(cmd[2:]).stdout
                        stderr = 'bench-rss: 1\n'
                    elif Path(cmd[0]).name == 'benitoite':
                        if kwargs.get('env', {}).get('BENITOITE_DEV_ALLOC_STATS'):
                            stderr = 'alloc-stats: allocated_bytes=1 peak_heap_bytes=1 allocations=1\n'
                    else:
                        return real_run(cmd, **kwargs)
                    return subprocess.CompletedProcess(cmd, status, stdout=stdout, stderr=stderr)
                target = root/'targets.json'
                target.write_text(json.dumps(dict(cases=['functions-main-0-0', 'bridge-shared-8'],
                    min_samples=1, targets=[dict(label='missing bridge', kind='ratio', limit=1,
                        expression=dict(op='ratio', left=median('bridge-shared-8', 'after'),
                                        right=median('bridge-shared-8', 'before')))])))
                argv = ['run.py', '--tier', 'targets', '--targets', str(target), '--samples', '1',
                        '--alloc', '--work', str(root/'work'), '--out', str(root/'out'),
                        *(arg for s, c in commits.items() for arg in ('--state', f'{s}={c}'))]
                with patch('build.git', git), patch('build.subprocess.check_output', check_output), \
                     patch('build.subprocess.run', process), patch('sys.argv', argv), \
                     patch('run.build_all', partial(build_all, cache=root/'builds')):
                    main()
                manifest = json.loads((root/'out/manifest.json').read_text())
                cli = json.loads((root/'out/section-16.2.json').read_text())['measurements']['functions-main-0-0']
                bridge = json.loads((root/'out/section-16.8.json').read_text())['measurements']['bridge-shared-8']
                self.assertTrue(all(len(cli[s]['cli']) == 1 for s in commits))
                self.assertEqual(set(bridge), set(commits)-set(missing))
                self.assertTrue(all(not m.get('allocated_bytes') for m in bridge.values()))
                self.assertEqual({r['state'] for r in manifest['skipped'] if 'timing_probe' in r['reason']}, set(missing))
                self.assertEqual({r['state'] for r in manifest['skipped'] if r.get('scope') == 'alloc'}, set(bridge))
                self.assertTrue(all(not manifest['capabilities'][s]['timing_probe']['supported'] for s in missing))
                verdict = json.loads((root/'out/result-manifest.json').read_text())['goals'][0]
                self.assertEqual(verdict['status'], '判定不能')
                self.assertTrue((root/'out/results.md').is_file())
                self.assertTrue((root/'out/results.html').is_file())


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


class SyntaxBatch4Contracts(unittest.TestCase):
    # 関門: 共通 runner の入口で単位・欠測・状態拒否を確かめる。
    # 旧比較のテストは新しい計時差、実行用キーと全目標の接続を含まない。
    def test_units_iqr_and_nonpositive_ratio_inputs(self):
        def diff(metric):
            return dict(op='difference', left=median('point', metric=metric), right=median('zero', metric=metric))
        data = {'point': {'new': {'vm_run': [.003]*10, 'allocated_bytes': [2]*10}},
                'zero': {'new': {'vm_run': [.002]*10, 'allocated_bytes': [1]*10}}}
        self.assertIsNone(expression(dict(op='ratio', left=diff('vm_run'), right=1), data, 10))
        self.assertEqual(expression(dict(op='ratio', left=diff('allocated_bytes'), right=1), data, 10)['median'], 1)
        data['point']['new']['vm_run'] = [.004]*10
        data['zero']['new']['vm_run'] = [.001]*10
        self.assertAlmostEqual(expression(diff('vm_run'), data, 10)['median'], .003)
        data['point']['new']['vm_run'] = [1,1,1,1,1,1,1,1,1,100]
        data['zero']['new']['vm_run'] = [.1]*10
        self.assertAlmostEqual(expression(diff('vm_run'), data, 10)['median'], .9)
        data['point']['new']['vm_run'] = [0]*10
        self.assertIsNone(expression(dict(op='ratio', left=diff('vm_run'), right=1), data, 10))
        data['point']['new']['vm_run'] = [float('nan')]*10
        self.assertIsNone(expression(diff('vm_run'), data, 10))
        with self.assertRaisesRegex(ValueError, 'incompatible units'):
            expression(dict(op='ratio', left=median('point', metric='allocated_bytes'), right=median('zero', metric='vm_run')), data, 10)

    def test_target_references_and_missing_data(self):
        from run import validate_targets
        configs = [*Path('docs').glob('*syntax-batch4/bench-targets.json'),
                   *Path('docs/archive').glob('*syntax-batch4/bench-targets.json')]
        self.assertEqual(len(configs), 1)
        config = json.loads(configs[0].read_text())
        cases = corpus(False)
        validate_targets(config, cases)
        result = evaluate(config, {}, {}, cases)
        self.assertEqual(len(result), len(config['targets']))
        self.assertTrue(all(row['status'] == '判定不能' for row in result))
        changed = copy.deepcopy(config)
        changed['targets'][0]['expression'] = median('build-string-builder-0-0', metric='invented')
        with self.assertRaisesRegex(ValueError, 'metric'):
            validate_targets(changed, cases)

    def test_state_specific_limit_is_not_a_success_sample(self):
        from scenarios.patterns import cases
        from validation import validate, verify_group
        case = next(c for c in cases() if c.id == 'patterns-tree-13')
        rejected = dict(status=2, stdout='', stderr=json.dumps(dict(code='L0112', severity='error'))+'\n')
        self.assertEqual(validate(case, 'before', rejected), 'expected-rejection')
        accepted = dict(status=0, stdout='0\n12\n-1\n', stderr='')
        self.assertEqual(validate(case, 'after', accepted), 'verified')
        verify_group(case, dict(before=rejected, after=accepted))
        for state, value in [('before', accepted), ('after', rejected), ('after', dict(accepted, stdout='0\n0\n-1\n'))]:
            with self.assertRaises(RuntimeError): validate(case, state, value)

    def test_external_observer_checks_both_directions_and_missing_is_absent(self):
        from observations import external_values
        from scenarios.external_tests import cases
        case = next(c for c in cases(True) if c.family == 'normal' and c.n == 1)
        output = '\n'.join(json.dumps(v) for v in [dict(kind='test',outcome='passed'),
                 dict(kind='testSummary',passed=1,failed=0,filesNotRun=0,interrupted=False)])
        value = dict(status=0, stdout=output, stderr=json.dumps(dict(runtime_compilations=dict(normal=1,adapter=0), stateful_instances=[])))
        self.assertEqual(external_values(case, value, 'after', stats=True)['runtime_compilations'], 1)
        for n in (0,2):
            bad = dict(value, stderr=json.dumps(dict(runtime_compilations=dict(normal=n,adapter=0),stateful_instances=[])))
            with self.assertRaisesRegex(RuntimeError, 'compilation/key mismatch'): external_values(case, bad, 'after', stats=True)
        self.assertEqual(external_values(case, dict(value,stderr='{}'), 'before', stats=True), {})
        with self.assertRaises(RuntimeError): external_values(case, dict(value,stdout=output.replace('"passed": 1','"passed": 0')), 'after', stats=True)

    def test_probe_and_resource_decoders_refuse_missing_and_wrong_values(self):
        from observations import probe_values, alloc_values
        from run import stage_values
        from scenarios.codegen import cases
        case = next(c for c in cases(True) if c.id == 'codegen-holes-1-direct')
        result = dict(status=0,stdout=json.dumps(dict(vm_run=.1,hole_lets=3,errors=0,output='wrong')),stderr='')
        with self.assertRaisesRegex(RuntimeError, 'output mismatch'): stage_values(case,'after',result)
        with self.assertRaisesRegex(RuntimeError, 'missing probe metric'): probe_values(dict(result,stdout='{}'),('vm_run',))
        with self.assertRaises(RuntimeError): probe_values(dict(result,stdout='{"vm_run": -1}'))
        self.assertEqual(alloc_values('')[0], {})
        with self.assertRaises(RuntimeError): alloc_values('alloc-stats: allocated_bytes=0\n')
        observed, stderr = alloc_values('alloc-stats: allocations=1 allocated_bytes=8 peak_heap_bytes=8\nalloc-stats: allocations=2 allocated_bytes=16 peak_heap_bytes=12\n')
        self.assertEqual(observed, dict(allocations=3,allocated_bytes=24,peak_heap_bytes=12))
        self.assertEqual(stderr, '')

    def test_partial_invariant_evidence_is_inconclusive(self):
        case = Case('x','s','f',1,common(''),states=('a','b'),params=dict(keys=1))
        goal = dict(label='g',kind='invariant',field='runtime_compilations',parameter='keys')
        outputs = {'x': {'a': dict(stdout='', observations=dict(runtime_compilations=1))}}
        self.assertEqual(evaluate(dict(targets=[goal]),{},outputs,[case])[0]['status'], '判定不能')

    def test_probe_failures_identify_case_state_and_metrics(self):
        from run import stage_values
        from validation import validate
        from scenarios.codegen import cases
        case = next(c for c in cases(True) if c.id == 'codegen-irenv-empty')
        failures = [dict(status=1, stdout='', stderr='missing declaration scheme'),
                    dict(status=0, stdout='{}', stderr=''),
                    dict(status=0, stdout='not JSON', stderr='')]
        for check in (validate, stage_values):
            for state in ('before', 'after'):
                for result in failures:
                    with self.subTest(check=check.__name__, state=state, result=result):
                        with self.assertRaisesRegex(RuntimeError, f'{case.id}/{state}.*ir_check'):
                            check(case, state, result)


class CommonProbeCompilationTests(unittest.TestCase):
    def test_both_revisions_compile_through_the_common_builder(self):
        # コンパイルだけでは宣言型などの実行時の前提の欠落を捕まえられない。
        # quick の独立 IR とグラフを両版自身の検査・変換の入口へ一度ずつ通す。
        from build import build_all, git
        from run import execute, probe_command, stage_values
        from scenarios import select_tier
        baseline = 'c31e64b03d2810343e1779926bea4ebc958b6164'
        head = git('rev-parse','HEAD').decode().strip()
        records = build_all(dict(before=baseline,after=head))
        for state, record in records.items():
            self.assertIn('probe', record, (state, record.get('probe_unavailable')))
            self.assertTrue(Path(record['probe']).is_file())
            self.assertIn('conversion_unit', record['bridge_sources'])
        cases = [c for c in select_tier(corpus(True), 'short', quick=True) if c.command == 'probe']
        configure(cases, {s: dict(timing_probe=bool(b.get('probe'))) for s, b in records.items()})
        with tempfile.TemporaryDirectory() as tmp:
            _, entries = materialize(Path(tmp), cases)
            for case in cases:
                for state in case.states:
                    with self.subTest(case=case.id, state=state, metrics=case.metrics):
                        result = execute(probe_command(case, records[state], entries[case.id, state]), 30)
                        values = stage_values(case, state, result)
                        self.assertTrue(set(case.metrics) - {'allocated_bytes'} <= values.keys())
            # 専用validatorの入力はexpected_stdoutを使わない。各版で利用可能なAPIを使う。
            shrink = next(c for c in corpus(True) if c.id == 'property-seven-24-0-0-all-ok')
            features = {s: {name: r['supported'] for name, r in
                           probe_features(b['binary'], Path(tmp)/s, 30, execute).items()}
                        for s, b in records.items()}
            configure([shrink], features)
            _, entries = materialize(Path(tmp), [shrink], features)
            for state in shrink.states:
                variant = shrink.variant(features[state])
                with self.subTest(case=shrink.id, state=state, variant=variant):
                    result = execute(probe_command(shrink, records[state], entries[shrink.id, state]), 30)
                    stage_values(shrink, state, result, variant=variant)
                    bad = dict(result, stdout=result['stdout'].replace('message=bad', 'message=wrong'))
                    with self.assertRaisesRegex(RuntimeError, 'probe output mismatch'):
                        stage_values(shrink, state, bad, variant=variant)


if __name__ == '__main__':
    unittest.main()
