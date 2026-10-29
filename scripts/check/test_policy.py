#!/usr/bin/env python3
"""check.sh の入口と長い対象の実行器を、一時Gitリポジトリで検査する。"""

import ast
from contextlib import contextmanager
import json
import os
from pathlib import Path
import re
import runpy
import shlex
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
FIXTURE = Path(__file__).with_name('fixtures') / 'legacy-commands.json'
LEGACY_NAMES = ('rust default_lib long release_stack licenses heap spec_examples '
                'reference_examples skill spec_coverage skill_eval python formal').split()

# 代用は外部プロセスだけに置く。分類・引数・順序は写したcheck.shと実行器が決める。
EXTERNAL = r'''#!/usr/bin/env python3
import json
import os
from pathlib import Path
import sys
name = Path(sys.argv[0]).name
args = sys.argv[1:]
entry = [name, *args]
with open(os.environ['POLICY_LOG'], 'a') as stream:
    stream.write(json.dumps(entry) + '\n')
if os.environ.get('POLICY_FAIL') == str(len(Path(os.environ['POLICY_LOG']).read_text().splitlines())):
    sys.exit(17)
if name == 'lake':
    print(os.environ.get('POLICY_LAKE_OUTPUT', ''), end='')
if name != 'cargo':
    sys.exit(0)
if args[:2] == ['deny', '--version']:
    if os.environ.get('POLICY_ADVISORIES_MISSING'):
        print('error: no such command: deny', file=sys.stderr)
        sys.exit(101)
    print('cargo-deny 0.20.2')
    sys.exit(0)
if args[0] == 'deny' and args[-2:] == ['check', 'advisories']:
    key = 'fuzz' if 'fuzz/Cargo.toml' in args else 'workspace'
    case = json.loads(Path(os.environ['POLICY_ADVISORIES']).read_text())[key] if os.environ.get('POLICY_ADVISORIES') else {}
    print(case.get('stdout', ''), end='')
    print(case.get('stderr', '{"type":"summary","fields":{"advisories":{"errors":0,"warnings":0,"notes":0,"helps":0}}}\n'), end='', file=sys.stderr)
    sys.exit(case.get('exit', 0))
scenario_path = os.environ.get('POLICY_CARGO')
if not scenario_path:
    sys.exit(0)
scenario = json.loads(Path(scenario_path).read_text())
if args[0] != 'test':
    sys.exit(0)
key = 'long' if '--ignored' in args else 'stack'
mode = scenario.get('execution', 'ok')
if mode == 'exit':
    print('test result: ok. 10 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.01s')
    sys.exit(19)
for summary in scenario[key]:
    print(summary, flush=True)
print('cargo progress', file=sys.stderr, flush=True)
'''


def execute(arguments, cwd, env=None):
    return subprocess.run(arguments, cwd=cwd, env=env, text=True, capture_output=True)


def ignored_fixture():
    """Cargoが返す複数ターゲットの要約。選択の引数は本物の入口から観察する。"""
    def summary(count):
        return f'test result: ok. {count} passed; 0 failed; 0 ignored; 0 measured; 9 filtered out; finished in 0.01s'
    return {'long': [summary(1), summary(0), summary(1)], 'stack': [summary(10)]}


class Sandbox:
    """本物のGit・Python・道具を使う、既存リポジトリから独立した準備。"""

    def __init__(self):
        self.temp = tempfile.TemporaryDirectory(prefix='benitoite-policy-')
        self.root = Path(self.temp.name)
        self.bin = self.root / '.external'
        self.bin.mkdir()
        self.log = self.bin / 'calls.jsonl'
        self.env = dict(os.environ, PATH=str(self.bin) + os.pathsep + os.environ['PATH'],
                        POLICY_LOG=str(self.log), PYTHONDONTWRITEBYTECODE='1',
                        GIT_CONFIG_NOSYSTEM='1', GIT_CONFIG_GLOBAL=os.devnull)
        for name in ('POLICY_FAIL', 'POLICY_CARGO', 'POLICY_LAKE_OUTPUT', 'POLICY_ADVISORIES', 'POLICY_ADVISORIES_MISSING', 'BENITOITE_ADVISORY_DB_PATH'):
            self.env.pop(name, None)
        for name in ('cargo', 'lake'):
            self.put('.external/' + name, EXTERNAL, executable=True)
        for path in ('scripts/check.sh', 'scripts/check-heap.sh', 'scripts/check-formal.sh',
                     'deny.toml', 'scripts/release/about.toml'):
            self.copy(path)
        self.put('scripts/check-heap.sh', EXTERNAL, executable=True)
        for path in ROOT.glob('scripts/check/**/*.py'):
            self.copy(str(path.relative_to(ROOT)))
        # 構文検査と自己検査には、本物のPythonの道具を写す。
        for path in ROOT.glob('tools/**/*.py'):
            if '__pycache__' not in path.parts:
                self.copy(str(path.relative_to(ROOT)))
        for path in ROOT.glob('docs/design/01-spec/*.md'):
            self.copy(str(path.relative_to(ROOT)))
        (self.root / 'crates/benitoite/src').mkdir(parents=True)
        (self.root / 'formal').mkdir()
        # 集計器には独立した小さい入力を与える。道具の実装は写したものを使う。
        self.put('crates/benitoite/testdata/runner/sample.bnt', '// spec: 01-02 EBNF の表記\n')
        self.put('docs/design/00-overview/00-03-roadmap.md',
                 '### 初回リリース版\n#### 完了条件\n| 条件 | 期待 |\n|---|---|\n'
                 + ''.join(f'| fixture {i} | ok |\n' for i in range(4)))
        self.put('crates/benitoite/testdata/acceptance/INDEX.md',
                 '## 初回リリース版の完了条件\n| 完了条件 | テスト |\n|---|---|\n'
                 + ''.join(f'| fixture {i} | `runner/sample.bnt` |\n' for i in range(4)))
        self.put('.gitignore', '.external/\n__pycache__/\ntarget/\n')
        for name in ('Cargo.lock', 'fuzz/Cargo.lock'):
            self.put(name, '# fixture input\n')
        self.git('init', '-q')
        self.git('add', '.')
        self.git('-c', 'user.name=Policy Test', '-c', 'user.email=policy@example.invalid',
                 '-c', 'commit.gpgsign=false', 'commit', '-qm', 'fixture base')
        self.base = self.git('rev-parse', 'HEAD').stdout.strip()

    def close(self):
        self.temp.cleanup()

    def put(self, name, content, executable=False):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding='utf-8')
        if executable:
            path.chmod(0o755)

    def copy(self, name):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / name, path)

    def git(self, *arguments):
        result = execute(['git', *arguments], self.root, self.env)
        if result.returncode:
            raise AssertionError(result.stderr)
        return result

    def calls(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []

    @contextmanager
    def ignored(self):
        self.put('.external/scenario.json', json.dumps(ignored_fixture()))
        self.env['POLICY_CARGO'] = str(self.bin / 'scenario.json')
        try:
            yield self.base
        finally:
            self.env.pop('POLICY_CARGO')

    def check(self, *arguments, trace=False):
        self.log.unlink(missing_ok=True)
        return execute(['bash', *(['-x'] if trace else []), 'scripts/check.sh', *arguments],
                       self.root, self.env)

    def observe(self, arguments):
        result = self.check(*arguments, trace=True)
        # 時間や一時パスを含む道具の本文は保存せず、入口で決めた計画・コマンド・終了を採る。
        python_commands = [shlex.split(line[2:]) for line in result.stderr.splitlines()
                           if re.match(r'^\+ python3 (?:-B )?tools/[^ ]+\.py(?: |$)', line)]
        checks = [line[3:] for line in result.stdout.splitlines()
                  if line.startswith('== ') and not line.startswith(('== plan:', '== stop:'))]
        plan = result.stdout.split('\n== ', 1)[0]
        plan = plan.replace(self.base, '<BASE>')
        return dict(exit=result.returncode, plan=plan,
                    stops=[line.replace(self.base, '<BASE>') for line in result.stdout.splitlines()
                           if line.startswith('== stop:')], checks=checks,
                    python_commands=python_commands, calls=self.calls())


def legacy_cases():
    for name in LEGACY_NAMES:
        yield 'only-' + name, ['--only', name], None
        yield 'only-' + name + '-dry', ['--only', name, '--dry-run'], None
    yield 'full', ['--full'], None
    yield 'full-dry', ['--full', '--dry-run'], None


def automatic_cases():
    for scenario, change in [('documents', 'notes.md'), ('rust', 'crates/benitoite/src/new.rs'),
                             ('heap', 'crates/benitoite/src/runtime/heap/new.rs'),
                             ('unclassified', 'unknown.input'), ('missing-base', None)]:
        for dry in (False, True):
            yield 'auto-' + scenario + ('-dry' if dry else ''), (['--dry-run'] if dry else []), change


class PolicyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.box = Sandbox()

    @classmethod
    def tearDownClass(cls):
        cls.box.close()

    def test_formal_entries_and_failure_propagation(self):
        # 外部プロセスだけを代え、本物のシェルが独立入力と実ソースを両方呼ぶこと、
        # 各入口の失敗を最後の成功で上書きしないことを確かめる。
        with tempfile.TemporaryDirectory(prefix='benitoite-formal-policy-') as temporary:
            root = Path(temporary).resolve()
            (root / 'scripts').mkdir()
            shutil.copy2(ROOT / 'scripts/check-formal.sh', root / 'scripts/check-formal.sh')
            (root / 'formal/.lake/build/bin').mkdir(parents=True)
            (root / 'external').mkdir()
            for name in ('lake', 'cargo', 'python3'):
                path = root / 'external' / name
                observer = ("if name == 'cargo' and any(a.startswith('export_interval_') for a in args):\n"
                            "    with open(os.environ['POLICY_EXPORT_DIRS'], 'a') as stream:\n"
                            "        stream.write(json.dumps(os.environ['BENITOITE_DESUGAR_DIFF_DIR']) + '\\n')\n")
                path.write_text(EXTERNAL.replace("#!/usr/bin/env python3", "#!" + sys.executable, 1)
                                .replace("if name == 'lake':", observer + "if name == 'lake':"))
                path.chmod(0o755)
            for name in ('coverageDiff', 'coverageProgramDiff', 'desugarDiff', 'builtinCheck', 'surfaceCheckAll'):
                path = root / 'formal/.lake/build/bin' / name
                path.write_text(EXTERNAL.replace("#!/usr/bin/env python3", "#!" + sys.executable, 1))
                path.chmod(0o755)
            log = root / 'calls.jsonl'
            env = dict(os.environ, PATH=str(root / 'external') + os.pathsep + os.environ['PATH'], POLICY_LOG=str(log))
            for name in ('POLICY_FAIL', 'POLICY_CARGO', 'BENITOITE_DESUGAR_DIFF_DIR',
                         'BENITOITE_COVERAGE_DIFF_DIR', 'BENITOITE_INTERVAL_DIFF_DIR'):
                env.pop(name, None)
            # 失敗時の呼び出し列も全引数で比べるため、実行ごとのPIDを含まない出力先にする。
            output_dir = root / 'target/desugar-diff/policy'
            env['BENITOITE_DESUGAR_DIFF_DIR'] = str(output_dir)
            env['BENITOITE_COVERAGE_DIFF_DIR'] = str(root / 'target/coverage-diff/policy')
            interval_dir = root / 'target/interval-diff/policy'
            env['BENITOITE_INTERVAL_DIFF_DIR'] = str(interval_dir)
            env['POLICY_EXPORT_DIRS'] = str(root/'export-dirs.jsonl')
            result = execute(['bash', 'scripts/check-formal.sh'], root, env)
            self.assertEqual(result.returncode, 0, result.stderr)
            calls = [json.loads(line) for line in log.read_text().splitlines()]
            independent = ['python3', '-B', 'formal/tests/test_batch3_exchange.py']
            self.assertEqual(calls.count(independent), 1)
            batch4 = ['python3', '-B', 'formal/tests/test_batch4_exchange.py']
            self.assertEqual(calls.count(batch4), 1)
            range_calls = [
                ['python3', '-I', 'formal/tests/test_range_exchange.py',
                 '--output', str(output_dir / 'range-exchange-comparison')],
                ['python3', '-B', 'formal/tests/test_range_sources.py',
                 '--exports', str(output_dir / 'range-sources'),
                 '--cli', str(root / 'target/debug/benitoite'),
                 '--output', str(output_dir / 'range-source-comparison')],
                ['python3', '-B', 'formal/tests/test_range_budget_sources.py',
                 '--rust-dir', str(output_dir / 'range-budget'),
                 '--output-dir', str(output_dir / 'range-budget-comparison')],
                ['python3', '-B', 'formal/tests/test_range_known_differences.py',
                 '--cli', str(root / 'target/debug/benitoite'),
                 '--output-dir', str(output_dir / 'range-known-differences')],
            ]
            for call in range_calls:
                self.assertEqual(calls.count(call), 1)
            rust = [call for call in calls if call[:3] == independent and '--rust-dir' in call]
            self.assertEqual(len(rust), 1)
            self.assertTrue(rust[0][-1].endswith('/batch3/b3'))
            checker = [call for call in calls if len(call) > 2 and call[2].endswith('/check_batch3.py')]
            self.assertEqual(len(checker), 4)
            self.assertEqual(checker[0][4], rust[0][-1])
            for profile in ('b3', 'blocks', 'g2', 'g3'):
                with self.subTest(profile=profile):
                    rust_dir = str(output_dir / 'batch3' / profile)
                    profile_checker = [call for call in checker if call[3:5] == ['--rust-dir', rust_dir]]
                    self.assertEqual(len(profile_checker), 1)
                    self.assertEqual(profile_checker[0], [
                        'python3', '-B', 'crates/benitoite/tests/desugar_export/check_batch3.py',
                        '--rust-dir', rust_dir,
                        '--report', str(output_dir / 'batch3' / (profile + '-exchange-results.json')),
                    ])
            interval = [call for call in calls if call[:3] ==
                        ['python3', '-B', 'formal/tests/test_interval_exchange.py']]
            self.assertEqual(len(interval), 1)
            args = interval[0][3:]
            self.assertEqual(args[args.index('--output')+1], str(interval_dir / 'comparison'))
            self.assertEqual(args[args.index('--source-dir')+1], str(interval_dir / 'identity'))
            self.assertEqual(args[args.index('--vm-dir')+1], str(interval_dir / 'vm'))
            self.assertEqual([args[i+1] for i, value in enumerate(args) if value == '--rust-dir'],
                             [str(interval_dir / name) for name in (
                                 'programs', 'identity', 'manifest/manifest-interval', 'range/interval',
                                 'vm/original', 'vm/instrumented', 'vm/range/original',
                                 'vm/range/instrumented', 'vm/shifts/original', 'vm/shifts/instrumented')])
            exports = [['cargo', 'test', '--test', 'desugar_export', 'export_interval_'+name,
                        '--', '--nocapture'] for name in ('identity', 'manifest', 'range', 'vm')]
            for call in exports:
                self.assertEqual(calls.count(call), 1)
            self.assertEqual([json.loads(line) for line in (root/'export-dirs.jsonl').read_text().splitlines()],
                             [str(interval_dir/name) for name in ('identity', 'manifest', 'range', 'vm')])
            self.assertIn(['cargo', 'test', '--test', 'desugar_export', '--',
                           '--include-ignored', '--nocapture', '--skip', 'export_interval'], calls)
            self.assertIn(['lake', 'build', 'intervalDiff'], calls)
            artifact_calls = [call for call in calls if call[:3] ==
                              ['python3', '-B', 'scripts/check/formal_interval.py']]
            self.assertEqual([call[3] for call in artifact_calls], ['prepare', 'collect', 'manifest', 'verify'])
            self.assertEqual(calls[-2:], artifact_calls[-2:])
            # 旧六入口の全体と各交換を残し、新しい途中失敗も後の成功で隠さない。
            for tool in ('coverageDiff', 'coverageProgramDiff', 'desugarDiff', 'builtinCheck', 'surfaceCheckAll'):
                self.assertTrue(any(call[0] == tool for call in calls))
            for call in (independent, batch4, *range_calls, rust[0], *checker, *exports, interval[0], *artifact_calls,
                         ['lake', 'build', 'intervalDiff'], ['cargo', 'build', '-p', 'benitoite', '--bin', 'benitoite']):
                with self.subTest(failure=call):
                    log.unlink()
                    failed = execute(['bash', 'scripts/check-formal.sh'], root,
                                     dict(env, POLICY_FAIL=str(calls.index(call) + 1)))
                    self.assertEqual(failed.returncode, 17, failed.stderr)
                    self.assertEqual(len(log.read_text().splitlines()), calls.index(call) + 1)
                    self.assertEqual([json.loads(line) for line in log.read_text().splitlines()],
                                     calls[:calls.index(call) + 1])

    def test_formal_remaining_batch3_main_order(self):
        # 四群の直接検査とは別に、最終入口からの呼び忘れと順序の退行を検出する。
        source = ROOT / 'crates/benitoite/tests/desugar_export/check_named.py'
        tree = ast.parse(source.read_text(encoding='utf-8'))
        main = next(node for node in tree.body
                    if isinstance(node, ast.FunctionDef) and node.name == 'main')
        calls = [node.value for node in main.body
                 if isinstance(node, ast.Expr) and isinstance(node.value, ast.Call)
                 and isinstance(node.value.func, ast.Name)]
        remaining = [call for call in calls if call.func.id == 'check_remaining_batch3']
        routing = [call for call in calls if call.func.id == 'check_routing']
        self.assertEqual(len(remaining), 1, 'main must call check_remaining_batch3 once')
        self.assertEqual(len(routing), 1, 'main must call check_routing once')
        self.assertEqual([ast.dump(arg) for arg in remaining[0].args],
                         [ast.dump(ast.Name(id='directory', ctx=ast.Load()))])
        self.assertFalse(remaining[0].keywords)
        self.assertLess(calls.index(remaining[0]), calls.index(routing[0]),
                        'check_remaining_batch3 must precede check_routing')

    def test_formal_remaining_batch3_profiles_and_failure_propagation(self):
        # 実際の最終読者とbatch3読者をつなぎ、外部の比較実行ファイルだけを代える。
        # 表層・コアの意味は全比較の責任であり、ここでは四群の欠落と失敗の隠蔽を拒む。
        with tempfile.TemporaryDirectory(prefix='benitoite-final-batch3-policy-') as temporary:
            root = Path(temporary).resolve()
            for name in ('crates/benitoite/tests/desugar_export/check_named.py',
                         'crates/benitoite/tests/desugar_export/check_batch3.py',
                         'crates/benitoite/tests/desugar_export/batch3/manifest.json',
                         'formal/tests/test_batch3_exchange.py', 'formal/tests/test_named_exchange.py'):
                target = root / name
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(ROOT / name, target)
            output = root / 'target/desugar-diff/policy'
            # 期待する四群と件数は読者の列挙から算出しない。
            profiles = {
                'k3': {'scope': 5}, 'k4': {'range': 7},
                'm1': {'binary-minimal': 4, 'result': 13, 'user-result': 14},
                't3': {'higher-order': 3, 'super-paths': 3, 'failure': 3},
            }
            for profile, names in profiles.items():
                directory = output / 'batch3' / profile
                directory.mkdir(parents=True)
                inputs = []
                for name, count in names.items():
                    definitions = [{'scope': {'inScope': {'surface': {
                        'implementation': 'shared' if profile == 'm1' and name == 'result' and index < 6 else None
                    }}}} for index in range(count)]
                    inputs.append(dict(group='golden', name=name, excluded=[], definitions=definitions))
                keys = [dict(group='golden', name=name) for name in names]
                program = [dict(item, matches=[], bindings=[]) for item in keys]
                coverage_count = {'k3': 0, 'k4': 1, 'm1': 7, 't3': 1}[profile]
                program[0]['matches'] = [{} for _ in range(coverage_count)]
                for name, data in {
                    'corpus': dict(version=15, inputs=inputs),
                    'builtins': dict(version=7, inputs=keys),
                    'stdlib': dict(version=7, inputs=keys),
                    'coverage': dict(version=7, cases=[{}]),
                    'coverage-program': dict(version=7, inputs=program),
                }.items():
                    (directory / (name + '.json')).write_text(json.dumps(data))
            bin_dir = root / 'formal/.lake/build/bin'
            bin_dir.mkdir(parents=True)
            observer = '''
import json, os, sys
from pathlib import Path
tool = Path(sys.argv[0]).name
source = Path(sys.argv[1])
profile = source.parent.name
with open(os.environ['POLICY_LOG'], 'a') as log:
    log.write(json.dumps([profile, tool, *sys.argv[1:]]) + '\\n')
if os.environ.get('POLICY_FAIL_PROFILE') == profile:
    sys.exit(17)
data = json.loads(source.read_text())
if tool == 'desugarDiff':
    count = sum(len(i['definitions']) for i in data['inputs'])
    report = dict(mismatches=[], golden=dict(definitions=dict(matched=count, mismatched=0, outside=0, excluded=0)))
elif tool == 'builtinCheck':
    report = dict(errors=[], summaryMismatchCount=0, checkedInputs=len(data['inputs']))
elif tool == 'surfaceCheckAll':
    count = sum(sum(d['scope']['inScope']['surface']['implementation'] is None for d in i['definitions'])
                + len({d['scope']['inScope']['surface']['implementation'] for d in i['definitions']
                       if d['scope']['inScope']['surface']['implementation'] is not None}) for i in data['inputs'])
    report = dict(counts=dict(matched=count, mismatched=0, outOfScope=0, q11=0, lazyRestriction=0, preparationFailure=0))
elif tool == 'surfaceCheck':
    report = dict(result=dict(ok=True))
else:
    count = len(data['cases']) if tool == 'coverageDiff' else sum(len(i['matches']) + len(i['bindings']) for i in data['inputs'])
    report = dict(matched=count, mismatched=0, outOfScope=0, fuelExhausted=0)
Path(sys.argv[-1]).write_text(json.dumps(report))
sys.exit(1 if tool == 'coverageProgramDiff' and count == 0 else 0)
'''
            tools = ('coverageDiff', 'coverageProgramDiff', 'desugarDiff', 'builtinCheck',
                     'surfaceCheck', 'surfaceCheckAll')
            for tool in tools:
                target = bin_dir / tool
                target.write_text('#!' + sys.executable + '\n' + observer)
                target.chmod(0o755)
            log = root / 'calls.jsonl'
            env = dict(os.environ, POLICY_LOG=str(log))
            env.pop('POLICY_FAIL_PROFILE', None)
            command = [sys.executable, '-B', '-c',
                       "import runpy,sys; from pathlib import Path; "
                       "runpy.run_path(sys.argv[1])['check_remaining_batch3'](Path(sys.argv[2]))",
                       str(root / 'crates/benitoite/tests/desugar_export/check_named.py'), str(output)]
            result = execute(command, root, env)
            self.assertEqual(result.returncode, 0, result.stderr)
            calls = [json.loads(line) for line in log.read_text().splitlines()]
            for profile, names in profiles.items():
                selected = [call for call in calls if call[0] == profile]
                self.assertEqual([call[1] for call in selected],
                                 [*tools[:4], *(['surfaceCheck'] * len(names)), 'surfaceCheckAll'])
                for call in selected:
                    self.assertEqual(Path(call[2]).parent, output / 'batch3' / profile)
            for profile in profiles:
                with self.subTest(failure=profile):
                    log.unlink()
                    result = execute(command, root, dict(env, POLICY_FAIL_PROFILE=profile))
                    self.assertNotEqual(result.returncode, 0, result.stderr)
                    self.assertIn('got 17', result.stderr)
                    actual = [json.loads(line) for line in log.read_text().splitlines()]
                    first = next(index for index, call in enumerate(calls) if call[0] == profile)
                    # 一時の報告先は毎回変わるため、入力とツールの呼び出し列を照合する。
                    self.assertEqual([call[:-1] for call in actual], [call[:-1] for call in calls[:first + 1]])

    def test_formal_output_directory_isolation(self):
        # 本物の準備入口へ、.. とリンクを含む出力先を渡す。内容の字面は検査しない。
        with tempfile.TemporaryDirectory(prefix='benitoite-formal-paths-') as temporary:
            root = Path(temporary).resolve()
            helper = root / 'scripts/check/formal_interval.py'
            helper.parent.mkdir(parents=True)
            shutil.copy2(ROOT / 'scripts/check/formal_interval.py', helper)
            shutil.copy2(ROOT / 'scripts/check/interval_artifacts.py', helper.with_name('interval_artifacts.py'))
            interval = root / 'target/interval-diff/run'
            desugar = root / 'target/desugar-diff/run'
            coverage = root / 'target/coverage-diff/run'
            def prepare(path, other=desugar):
                return execute([sys.executable, '-B', str(helper), 'prepare', '--interval-dir', str(path),
                                '--desugar-dir', str(other), '--coverage-dir', str(coverage)], root)
            for path, other in [(interval, interval), (interval, interval/'nested'),
                                (interval, interval.parent), (root/'elsewhere', desugar),
                                (interval/'../../desugar-diff/run', desugar)]:
                with self.subTest(path=path, other=other):
                    self.assertNotEqual(prepare(path, other).returncode, 0)
                    self.assertFalse(interval.exists())
            self.assertEqual(prepare(interval).returncode, 0)
            (root/'target/interval-diff/link').symlink_to(desugar, target_is_directory=True)
            self.assertNotEqual(prepare(root/'target/interval-diff/link').returncode, 0)
            (interval/'old-report.json').write_text('{}')
            self.assertNotEqual(prepare(interval).returncode, 0)

    def test_formal_input_manifest_rejects_changed_and_missing_files(self):
        # 実ファイルの同定を境界にする。比較器は起動せず、入力を実際に壊して検査する。
        helper = runpy.run_path(str(ROOT/'scripts/check/formal_interval.py'))
        with tempfile.TemporaryDirectory(prefix='benitoite-formal-inputs-') as temporary:
            root = Path(temporary).resolve()
            roots = {name: root/name for name in ('interval', 'desugar', 'coverage')}
            for directory in roots.values():
                directory.mkdir()
            source = roots['desugar']/'corpus.json'
            source.write_text('{"inputs":[1]}')
            report = roots['interval']/'report.json'
            report.write_text('{"matched":true}')
            artifacts = helper['inventory'](roots)
            helper['write'](roots['interval']/'input-manifest.json',
                            dict(kind='formal-interval-inputs', version=1, artifacts=artifacts))
            helper['verify_inputs'](roots)
            for path in (source, report):
                original = path.read_bytes()
                path.write_bytes(original + b' ')
                with self.assertRaisesRegex(AssertionError, 'hash differs'):
                    helper['verify_inputs'](roots)
                path.unlink()
                with self.assertRaisesRegex(AssertionError, 'missing'):
                    helper['verify_inputs'](roots)
                path.write_bytes(original)
            helper['verify_inputs'](roots)

    def test_formal_collect_preserves_shared_inputs_without_copying(self):
        helper = runpy.run_path(str(ROOT/'scripts/check/formal_interval.py'))
        with tempfile.TemporaryDirectory(prefix='benitoite-formal-shared-') as temporary:
            root = Path(temporary).resolve()
            roots = {name: root/name for name in ('interval', 'desugar', 'coverage')}
            for directory in roots.values():
                directory.mkdir()
            for stem in ('named-programs', 'independent-program'):
                directory = roots['desugar']/(stem+'-interval')
                directory.mkdir()
                row = dict(group='golden', name=stem, payload='x'*32768)
                helper['write'](roots['desugar']/(stem+'-corpus.json'), dict(inputs=[row]))
                for filename in helper['SOURCE_FILES']:
                    helper['write'](directory/filename, dict(kind=filename, inputs=[row]))
            helper['collect'](roots)
            for filename in helper['SOURCE_FILES']:
                shared = roots['interval']/'programs'/filename
                self.assertEqual(helper['read'](shared)['inputs'],
                                 [dict(group='golden', name=stem, payload='x'*32768)
                                  for stem in ('named-programs', 'independent-program')])
                self.assertEqual(list(helper['input_rows'](shared)), helper['read'](shared)['inputs'])
                self.assertLess(shared.stat().st_size, 1024)
            # 最終照合の要約とfuelの記録は配列であり、索引と取り違えない。
            summary = roots['interval']/'real-source-summary.json'
            helper['write'](summary, [dict(comparedBodies='1')])
            self.assertEqual(helper['read'](summary), [dict(comparedBodies='1')])
            helper['verify_inputs'](roots)
            source = roots['desugar']/'named-programs-interval/interval-material.json'
            source.write_text(source.read_text().replace('x', 'y'))
            with self.assertRaisesRegex(AssertionError, 'hash differs'):
                helper['verify_inputs'](roots)

    def test_formal_source_evidence_and_negative_requirements(self):
        # 外部成果物の関門。Bottom だけ・警告だけ・独立入力だけの根拠を区別する。
        helper = runpy.run_path(str(ROOT/'scripts/check/formal_interval.py'))
        sources, evidence = [], []
        for name in helper['SOURCE_DIRS']:
            sources.append(dict(nonBottomInformativeBodies=0, userWarnings=1,
                negativeCases=sorted(helper['NEGATIVE_ALL']-helper['NEGATIVE_ABSENT'][name]),
                independentCandidates=0, phaseStops=[], excluded=[]))
            evidence.append(dict(nonBottomInformativeBodies=0, userWarnings=1, nonTopIndependentInputs=0))
        sources[0]['nonBottomInformativeBodies'] = evidence[0]['nonBottomInformativeBodies'] = 1
        check = helper['require_source_evidence']
        check(sources, evidence)
        sources[0]['nonBottomInformativeBodies'] = evidence[0]['nonBottomInformativeBodies'] = 0
        with self.assertRaisesRegex(AssertionError, 'across source collections'):
            check(sources, evidence)
        sources[0]['nonBottomInformativeBodies'] = evidence[0]['nonBottomInformativeBodies'] = 1
        sources[1]['userWarnings'] = evidence[1]['userWarnings'] = 0
        with self.assertRaisesRegex(AssertionError, 'identity: no non-Bottom'):
            check(sources, evidence)
        evidence[1]['nonTopIndependentInputs'] = 1
        check(sources, evidence)
        for index, source in enumerate(sources):
            for case in list(source['negativeCases']):
                with self.subTest(directory=helper['SOURCE_DIRS'][index], case=case):
                    source['negativeCases'].remove(case)
                    with self.assertRaisesRegex(AssertionError, 'required negative cases missing'):
                        check(sources, evidence)
                    source['negativeCases'].append(case)

    def test_legacy_contract(self):
        fixture = json.loads(FIXTURE.read_text())
        for name, arguments, change in legacy_cases():
            with self.subTest(name=name):
                if change:
                    self.box.put(change, '// fixture\n')
                base = 'missing-policy-base' if name.startswith('auto-missing-base') else self.box.base
                try:
                    actual = self.box.observe(['--base', base, *arguments])
                    self.assertEqual(actual, fixture['cases'][name])
                finally:
                    if change:
                        (self.box.root / change).unlink()

    def test_python_syntax_excludes_historical_tools(self):
        # 保管資料は実行対象に含めず、現役の構文エラーは引き続き拒否する。
        historical = 'docs/2026-10-19-test/historical-tools/named-arguments-migrate/tools/named-arguments-migrate/broken.py'
        live = 'tools/source-migrate/broken.py'
        self.box.put(historical, 'def broken(\n')
        try:
            result = self.box.check('--level', 'work', '--only', 'python_syntax')
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.box.put(live, 'def broken(\n')
            result = self.box.check('--level', 'work', '--only', 'python_syntax')
            self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
            self.assertIn(live, result.stderr)
        finally:
            (self.box.root / historical).unlink()
            (self.box.root / live).unlink(missing_ok=True)

    def test_policy_selection_and_shell_syntax(self):
        for name in ('check.sh', 'check-heap.sh', 'check-formal.sh'):
            result = execute(['bash', '-n', str(ROOT / 'scripts' / name)], ROOT)
            self.assertEqual(result.returncode, 0, result.stderr)
        for changed in ('scripts/check.sh', 'scripts/check/run_ignored.py',
                        'scripts/check/fixtures/new-fixture.json', 'scripts/check-heap.sh',
                        'scripts/check-formal.sh'):
            with self.subTest(changed=changed):
                path = self.box.root / changed
                before = path.read_bytes() if path.exists() else None
                self.box.put(changed, (before.decode() if before else '') + '\n# change\n')
                try:
                    result = self.box.check('--base', self.box.base, '--dry-run')
                    self.assertEqual(result.returncode, 3 if changed == 'scripts/check-heap.sh' else 0,
                                     result.stderr)
                    if changed in ('scripts/check.sh', 'scripts/check/run_ignored.py',
                                   'scripts/check/fixtures/new-fixture.json'):
                        self.assertIn('[policy_selftest]', result.stdout)
                        self.assertNotIn('== stop:', result.stdout)
                    elif changed == 'scripts/check-heap.sh':
                        self.assertIn('== stop:', result.stdout)
                    else:
                        self.assertIn('[formal_build]', result.stdout)
                    self.assertEqual(self.box.calls(), [])
                finally:
                    if before is None:
                        path.unlink()
                    else:
                        path.write_bytes(before)
        result = self.box.check('--base', 'missing-base', '--only', 'policy_selftest', '--dry-run')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('[policy_selftest]', result.stdout)
        self.assertEqual(self.box.calls(), [])

    def test_stop_guidance_preserves_units_base_and_targets(self):
        changes = ('unknown.input', 'crates/benitoite/src/change.rs', 'Cargo.toml',
                   'tools/source-migrate/change.py')
        for path in changes:
            self.box.put(path, '// changed\n')
        try:
            for level in ('work', 'change'):
                args = ['--test', 'golden'] if level == 'work' else []
                result = self.box.check('--level', level, '--base', self.box.base, *args, '--dry-run')
                self.assertEqual(result.returncode, 3, result.stdout + result.stderr)
                self.assertIn('     scripts/check.sh --level ', result.stdout)
                suggested = next(line.strip() for line in result.stdout.splitlines()
                                 if line.startswith('     scripts/check.sh --level '))
                command = shlex.split(suggested)[1:]
                self.assertEqual(command[:4], ['--level', level, '--base', self.box.base])
                selected = set(re.findall(r'^   \[([a-z_]+)\]', result.stdout, re.MULTILINE))
                self.assertEqual(set(command[command.index('--only') + 1].split(',')), selected)
                self.assertTrue({'licenses', 'python_syntax', 'migrate_selftests'} <= selected)
                self.assertIn('legacy set (not the change/release set)', result.stdout)
                self.assertIn(f'Available checks for {level}:', result.stdout)
                self.assertEqual(self.box.calls(), [])
                resumed = self.box.check(*command, '--dry-run')
                self.assertEqual(resumed.returncode, 0, resumed.stdout + resumed.stderr)
                self.assertEqual(set(re.findall(r'^   \[([a-z_]+)\]', resumed.stdout, re.MULTILINE)), selected)
                self.assertEqual(self.box.calls(), [])
        finally:
            for path in changes:
                (self.box.root / path).unlink()

    def test_empty_work_reports_no_changed_files(self):
        result = self.box.check('--level', 'work', '--base', self.box.base, '--dry-run')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('nothing to check: no changed files', result.stdout)
        self.assertEqual(self.box.calls(), [])

    def test_external_failures_stop_execution(self):
        # 最初・途中・最後の失敗を、本物の入口と外部プロセスの記録で観察する。
        success = self.box.observe(['--only', 'rust,release_stack,formal,heap'])
        self.assertEqual(success['exit'], 0, success)
        for index in (1, 3, len(success['calls'])):
            with self.subTest(index=index):
                self.box.env['POLICY_FAIL'] = str(index)
                try:
                    result = self.box.check('--only', 'rust,release_stack,formal,heap')
                    self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                    self.assertNotIn('all checks passed', result.stdout)
                    self.assertEqual(self.box.calls(), success['calls'][:index])
                finally:
                    self.box.env.pop('POLICY_FAIL')

    def test_default_switches_to_work_and_stops_with_three(self):
        expected = [
            ['cargo', 'fmt', '--all', '--check'],
            ['cargo', 'clippy', '-p', 'benitoite', '--lib', '--tests',
             '--examples', '--no-default-features', '--features', 'gc-mark-sweep'],
            ['cargo', 'test', '-p', 'benitoite', '--lib'],
            ['cargo', 'test', '-p', 'benitoite', '--test', '*'],
            ['cargo', 'run', '-q', '-p', 'benitoite', '--example', 'gen_skill'],
        ]
        heap_lint = ['cargo', 'clippy', '--workspace', '--all-targets', '--no-default-features',
                     '--features', 'gc-mark-sweep,heap-verify,alloc-stats']
        fixture = json.loads(FIXTURE.read_text())
        for name, arguments, change in automatic_cases():
            with self.subTest(name=name):
                if change:
                    self.box.put(change, '// fixture\n')
                missing = name.startswith('auto-missing-base')
                stopped = missing or name.startswith('auto-unclassified')
                base = 'missing-policy-base' if missing else self.box.base
                try:
                    actual = self.box.observe(['--base', base, *arguments])
                    self.assertEqual(actual['exit'], 3 if stopped else 0, actual)
                    self.assertIn('level work', actual['plan'])
                    calls = []
                    if not arguments and not stopped:
                        if name == 'auto-rust':
                            calls = expected
                        elif name == 'auto-heap':
                            calls = [*expected[:2], heap_lint, *expected[2:4], ['cargo', 'test', '--workspace', '--doc'], *expected[4:], ['check-heap.sh']]
                    self.assertEqual(actual['calls'], calls)
                    self.assertEqual(bool(actual['stops']), stopped)
                    if name.startswith(('auto-rust', 'auto-heap')):
                        self.assertIn('[lib_default]', actual['plan'])
                        self.assertIn('[tests_related]', actual['plan'])
                        self.assertNotIn('[long', actual['plan'])
                        if not arguments:
                            self.assertEqual(actual['python_commands'], [
                                ['python3', 'tools/spec-coverage/spec_coverage.py', '--self-test'],
                                ['python3', 'tools/spec-coverage/spec_coverage.py'],
                            ])
                    if name.startswith('auto-documents'):
                        self.assertEqual(actual['calls'], fixture['cases'][name]['calls'])
                    if stopped:
                        result = self.box.check('--base', base, *arguments, '--test', 'golden')
                        self.assertEqual(result.returncode, 3, result.stdout + result.stderr)
                        self.assertEqual(self.box.calls(), [])
                finally:
                    if change:
                        (self.box.root / change).unlink()

    def test_argument_errors_are_two_without_execution(self):
        invalid = [
            ['--level'], ['--only'], ['--base'], ['--test'],
            ['--level', ''], ['--only', ''], ['--base', ''], ['--test', ''],
            ['--level', 'unknown'],
            ['--level', 'change', '--test', 'golden'],
            ['--level', 'release', '--test', 'golden'],
            ['--level', 'change', '--only', 'lib_default'],
            ['--level', 'change', '--only', 'rust'],
            ['--level', 'change', '--only', 'heap_local'],
            ['--level', 'release', '--only', 'test_default_all'],
            ['--level', 'release', '--full'],
            ['--full', '--only', 'rust'], ['--full', '--none'],
            ['--only', 'rust', '--none'], ['--level', 'work', '--full'],
            ['--level', 'work', '--none'], ['--none', '--test', 'a'],
            ['--full', '--test', 'a'], ['--only', 'rust', '--test', 'a'],
            ['--only', ',rust'], ['--only', 'rust,'], ['--only', 'rust,,heap'],
            ['--level', 'work', '--only', 'fmt lint_default'],
            ['--level', 'stage'], ['--level', 'stage', '--only', 'lib_default'],
            ['--level', 'work', '--only', 'rust'],
            ['--level', 'work', '--only', 'test_default_all'],
            ['--level', 'work', '--only', 'tests_related'],
            ['--level', 'stage', '--only', 'tests_related'],
            ['--level', 'work', '--only', 'heap_local'],
            ['--level', 'stage', '--only', 'stress_local'],
            ['--level', 'work', '--only', 'fmt', '--test', 'a'],
            ['--level', 'stage', '--only', 'policy_selftest', '--test', 'a'],
            ['--level', 'work', '--only', 'tests_related', '--test', 'a', '--test', 'a'],
            ['--test', 'unused', '--base', self.box.base],
        ]
        for option, value in [('--full', None), ('--none', None), ('--dry-run', None),
                              ('--only', 'rust'), ('--base', self.box.base), ('--level', 'work')]:
            pair = [option] if value is None else [option, value]
            invalid.append(pair + pair)
        for arguments in invalid:
            for dry in ([], ['--dry-run']) if '--dry-run' not in arguments else ([],):
                with self.subTest(arguments=arguments, dry=dry):
                    result = self.box.check(*arguments, *dry)
                    self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
                    self.assertNotIn('== stop:', result.stdout)
                    self.assertTrue(result.stderr.startswith(('error: ', 'unknown check name: ')), result.stderr)
                    self.assertEqual(self.box.calls(), [])

    def test_named_targets_partial_selection_and_containment(self):
        arguments = ['--level', 'work', '--base', 'missing-base', '--only',
                     'lib_default,tests_related,spec_examples,reference_examples,skill_docs,fmt,fmt',
                     '--test', 'spec_examples', '--test', 'skill_docs']
        self.box.put('unknown.input', 'unclassified\n')
        try:
            plan = self.box.check(*arguments, '--dry-run')
            self.assertEqual(plan.returncode, 0, plan.stderr)
            self.assertIn('partial selection', plan.stdout)
            self.assertIn('changed files not classified', plan.stdout)
            self.assertIn('omitted: spec_examples skill_docs', plan.stdout)
            self.assertEqual(self.box.calls(), [])
            result = self.box.check(*arguments)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(self.box.calls(), [
                ['cargo', 'fmt', '--all', '--check'],
                ['cargo', 'test', '-p', 'benitoite', '--lib'],
                ['cargo', 'test', '-p', 'benitoite', '--test', 'spec_examples', '--test', 'skill_docs'],
                ['cargo', 'test', '-q', '-p', 'benitoite', '--test', 'reference_examples'],
            ])
            for level in ('work', 'stage'):
                args = ['--level', level, '--only', 'tests_related,heap_local,stress_local',
                        '--test', 'not_a_real_target', '--test', 'name with spaces;$(false)']
                result = self.box.check(*args, '--dry-run')
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(self.box.calls(), [])
                result = self.box.check(*args)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(self.box.calls(), [
                    ['cargo', 'test', '-p', 'benitoite', *config, '--test', 'not_a_real_target',
                     '--test', 'name with spaces;$(false)']
                    for config in ([], ['--no-default-features', '--features', 'gc-mark-sweep,heap-verify'],
                                   ['--no-default-features', '--features', 'gc-mark-sweep,heap-verify,gc-stress'])
                ])
            self.box.env['POLICY_FAIL'] = '1'
            try:
                result = self.box.check('--level', 'stage', '--only', 'tests_related',
                                        '--test', 'missing_target')
                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertNotIn('selected checks passed', result.stdout)
                self.assertEqual(len(self.box.calls()), 1)
            finally:
                self.box.env.pop('POLICY_FAIL')
        finally:
            (self.box.root / 'unknown.input').unlink()

    def test_work_diff_range_includes_staged_untracked_deleted_and_renamed(self):
        # 改名の旧パスを分類しない実装なら、spec_tally と spec_examples が消える。
        path = 'docs/design/01-spec/01-02-syntax.md'
        renamed = 'docs/moved-syntax.md'
        self.box.git('mv', path, renamed)
        self.box.put('crates/benitoite/src/staged.rs', '// staged\n')
        self.box.git('add', 'crates/benitoite/src/staged.rs')
        self.box.put('docs/reference/benitoite.md', 'untracked input\n')
        self.box.git('rm', 'deny.toml')
        try:
            for level in ('work', 'change'):
                args = ['--test', 'golden'] if level == 'work' else []
                result = self.box.check('--level', level, '--base', self.box.base, *args, '--dry-run')
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertIn('(5 changed file(s))', result.stdout)
                units = ('fmt', 'lint_default', 'lib_default', 'tests_related', 'source_rules',
                         'skill_generated', 'spec_tally', 'spec_examples', 'reference_examples',
                         'skill_docs', 'licenses') if level == 'work' else (
                             'fmt', 'lint_default', 'lint_heap', 'test_default_all', 'test_heap_all',
                             'test_stress', 'doc_default', 'source_rules', 'skill_generated',
                             'spec_tally', 'licenses', 'long_only')
                for unit in units:
                    self.assertIn('[' + unit + ']', result.stdout)
                if level == 'work':
                    self.assertIn('because of ' + path, result.stdout)
                else:
                    # 改名の旧パスの分類で選ばれた文書例は、全件検査へ包含される。
                    self.assertIn('omitted: spec_examples reference_examples skill_docs (included by test_default_all', result.stdout)
                self.assertEqual(self.box.calls(), [])
        finally:
            self.box.git('reset', '--hard', self.box.base)
            for extra in ('crates/benitoite/src/staged.rs', 'docs/reference/benitoite.md'):
                (self.box.root / extra).unlink(missing_ok=True)

        self.box.put('crates/benitoite/src/committed.rs', '// committed\n')
        self.box.git('add', 'crates/benitoite/src/committed.rs')
        self.box.git('-c', 'user.name=Policy Test', '-c', 'user.email=policy@example.invalid',
                     '-c', 'commit.gpgsign=false', 'commit', '-qm', 'second fixture base')
        newer = self.box.git('rev-parse', 'HEAD').stdout.strip()
        try:
            for base, count in ((self.box.base, 1), (newer, 0)):
                for level, check in (('work', 'lib_default'), ('change', 'test_default_all')):
                    result = self.box.check('--level', level, '--base', base, '--dry-run')
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertIn(f'({count} changed file(s))', result.stdout)
                    self.assertEqual('[' + check + ']' in result.stdout, bool(count))
                    self.assertEqual(self.box.calls(), [])
        finally:
            self.box.git('reset', '--hard', self.box.base)

    def test_work_failures_at_first_middle_and_last_command(self):
        args = ['--level', 'work', '--only', 'fmt,lib_default,tests_related,skill_generated,heap_local,formal_build,heap_checks',
                '--test', 'golden']
        success = self.box.check(*args)
        self.assertEqual(success.returncode, 0, success.stderr)
        calls = self.box.calls()
        self.assertEqual(len(calls), 7)
        for index in (1, 4, len(calls)):
            self.box.env['POLICY_FAIL'] = str(index)
            try:
                result = self.box.check(*args)
                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertNotIn('selected checks passed', result.stdout)
                self.assertEqual(self.box.calls(), calls[:index])
            finally:
                self.box.env.pop('POLICY_FAIL')

    def test_work_mapping_and_all_integration_containment(self):
        rust = {'fmt', 'lint_default', 'lib_default', 'tests_related', 'source_rules',
                'skill_generated', 'spec_tally'}
        cases = [
            ('docs/design/00-overview/00-03-roadmap.md', {'spec_tally'}),
            ('crates/benitoite/src/sample.rs', rust),
            ('crates/benitoite/examples/sample.rs', rust),
            ('fuzz/src/sample.rs', rust),
            *[(name, rust | {'licenses', 'advisories'}) for name in
              ('Cargo.toml', 'Cargo.lock', 'crates/benitoite/Cargo.toml', 'deny.toml')],
            *[(name, rust | {'advisories'}) for name in ('fuzz/Cargo.toml', 'fuzz/Cargo.lock')],
            ('formal/sample.lean', {'formal_build'}),
            ('formal/reviews/sample.md', set()),
            ('scripts/release/about.hbs', {'licenses'}),
            ('tools/skill-eval/sample.py', {'python_syntax', 'migrate_selftests', 'skill_eval_selftest'}),
            ('tools/source-migrate/sample.py', {'python_syntax', 'migrate_selftests'}),
            ('docs/2026-10-19-test/historical-tools/named-arguments-migrate/tools/named-arguments-migrate/old.py', set()),
            ('docs/2026-10-19-test/historical-tools/named-arguments-migrate/crates/benitoite/examples/named_arguments_inventory.rs', set()),
            ('tools/spec-coverage/sample.py', {'python_syntax', 'migrate_selftests', 'spec_tally'}),
            ('docs/design/01-spec/01-02-syntax.md', {'spec_examples', 'spec_tally', 'skill_generated', 'skill_docs'}),
            ('docs/reference/benitoite.md', {'reference_examples'}),
        ]
        for path, units in cases:
            file = self.box.root / path
            before = file.read_bytes() if file.exists() else None
            self.box.put(path, (before.decode() if before else '') + '\n# changed\n')
            try:
                result = self.box.check('--level', 'work', '--base', self.box.base, '--dry-run')
                self.assertEqual(result.returncode, 0, result.stderr)
                selected = set(re.findall(r'^   \[([a-z_]+)\]', result.stdout, re.MULTILINE))
                self.assertEqual(selected, units, result.stdout)
                self.assertEqual(self.box.calls(), [])
            finally:
                if before is None:
                    file.unlink()
                else:
                    file.write_bytes(before)

        self.box.put('crates/benitoite/src/change.rs', '// rust\n')
        self.box.put('docs/reference/benitoite.md', 'changed\n')
        syntax = self.box.root / 'docs/design/01-spec/01-02-syntax.md'
        before = syntax.read_bytes()
        syntax.write_bytes(before + b'\nchanged\n')
        try:
            result = self.box.check('--base', self.box.base)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn('omitted: spec_examples reference_examples skill_docs', result.stdout)
            self.assertEqual([c for c in self.box.calls() if c[1] == 'test'], [
                ['cargo', 'test', '-p', 'benitoite', '--lib'],
                ['cargo', 'test', '-p', 'benitoite', '--test', '*'],
            ])
            self.assertIn('selected checks passed', result.stdout)
        finally:
            syntax.write_bytes(before)
            (self.box.root / 'crates/benitoite/src/change.rs').unlink()
            (self.box.root / 'docs/reference/benitoite.md').unlink()


    def test_change_mapping_conditional_checks_and_stops(self):
        rust = {'fmt', 'lint_default', 'lint_heap', 'test_default_all', 'test_heap_all',
                'test_stress', 'doc_default', 'source_rules', 'skill_generated', 'spec_tally', 'long_only'}
        cases = [
            ('notes.md', set()),
            ('crates/benitoite/src/change.rs', rust),
            ('crates/benitoite/src/vm/change.rs', rust),
            ('crates/benitoite/src/runtime/heap/change.rs', rust | {'heap_checks'}),
            ('Cargo.toml', rust | {'licenses'}),
            ('Cargo.lock', rust | {'licenses'}),
            ('deny.toml', rust | {'licenses'}),
            ('crates/benitoite/Cargo.toml', rust | {'licenses'}),
            ('fuzz/src/change.rs', rust),
            ('fuzz/Cargo.toml', rust),
            ('fuzz/Cargo.lock', rust),
            ('formal/change.lean', {'formal_build'}),
            ('formal/reviews/change.md', set()),
            ('scripts/check-formal.sh', {'formal_build'}),
            ('scripts/check.sh', {'policy_selftest'}),
            ('scripts/check/test_policy.py', {'policy_selftest'}),
            ('scripts/release/about.hbs', {'licenses'}),
            ('scripts/release/about.toml', {'licenses'}),
            ('tools/skill-eval/change.py', {'python_syntax', 'migrate_selftests', 'skill_eval_selftest'}),
            ('tools/source-migrate/change.py', {'python_syntax', 'migrate_selftests'}),
            ('docs/2026-10-19-test/historical-tools/named-arguments-migrate/tools/named-arguments-migrate/old.py', set()),
            ('docs/2026-10-19-test/historical-tools/named-arguments-migrate/crates/benitoite/examples/named_arguments_inventory.rs', set()),
            ('tools/spec-coverage/change.py', {'python_syntax', 'migrate_selftests', 'spec_tally'}),
            ('docs/design/01-spec/01-02-syntax.md', {'spec_examples', 'spec_tally', 'skill_generated', 'skill_docs'}),
            ('docs/design/01-spec/change.md', {'spec_examples', 'spec_tally'}),
            ('docs/design/00-overview/00-03-roadmap.md', {'spec_tally'}),
            ('docs/reference/benitoite.md', {'reference_examples'}),
            ('scripts/check-heap.sh', set()),
            ('unknown.input', set()),
        ]
        for path, units in cases:
            with self.subTest(path=path):
                file = self.box.root / path
                before = file.read_bytes() if file.exists() else None
                self.box.put(path, (before.decode() if before else '') + '\n# changed\n')
                try:
                    stopped = path in ('scripts/check-heap.sh', 'unknown.input')
                    result = self.box.check('--level', 'change', '--base', self.box.base, '--dry-run')
                    self.assertEqual(result.returncode, 3 if stopped else 0, result.stdout + result.stderr)
                    selected = set(re.findall(r'^   \[([a-z_]+)\]', result.stdout, re.MULTILINE))
                    self.assertEqual(selected, units | {'advisories'}, result.stdout)
                    self.assertEqual('== stop:' in result.stdout, stopped)
                    self.assertEqual(self.box.calls(), [])
                    if stopped:
                        result = self.box.check('--level', 'change', '--base', self.box.base)
                        self.assertEqual(result.returncode, 3, result.stdout + result.stderr)
                        self.assertIn(path, result.stdout)
                        self.assertEqual(self.box.calls(), [])
                finally:
                    if before is None:
                        file.unlink()
                    else:
                        file.write_bytes(before)
        for dry in ([], ['--dry-run']):
            result = self.box.check('--level', 'change', '--base', 'missing-base', *dry)
            self.assertEqual(result.returncode, 3, result.stdout + result.stderr)
            self.assertIn('== stop: base missing-base is not a commit', result.stdout)
            self.assertEqual(self.box.calls(), [])

    def test_change_execution_configurations_and_containment(self):
        self.box.put('crates/benitoite/src/change.rs', '// rust\n')
        self.box.put('docs/reference/benitoite.md', 'changed\n')
        syntax = self.box.root / 'docs/design/01-spec/01-02-syntax.md'
        before = syntax.read_bytes()
        syntax.write_bytes(before + b'\nchanged\n')
        try:
            with self.box.ignored() as base:
                args = ['--level', 'change', '--base', base]
                plan = self.box.check(*args, '--dry-run')
                self.assertEqual(plan.returncode, 0, plan.stderr)
                self.assertEqual(self.box.calls(), [])
                self.assertIn('omitted: spec_examples reference_examples skill_docs (included by test_default_all', plan.stdout)
                self.assertNotIn('[lib_default]', plan.stdout)
                self.assertNotIn('[tests_related]', plan.stdout)
                self.assertIn('estimate: long:', plan.stdout)
                result = self.box.check(*args)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                ordinary = [c for c in self.box.calls() if '--ignored' not in c]
                self.assertEqual(ordinary, [
                    ['cargo', 'fmt', '--all', '--check'],
                    ['cargo', 'clippy', '-p', 'benitoite', '--lib', '--tests', '--examples', '--no-default-features', '--features', 'gc-mark-sweep'],
                    ['cargo', 'clippy', '--workspace', '--all-targets', '--no-default-features', '--features', 'gc-mark-sweep,heap-verify,alloc-stats'],
                    ['cargo', 'test', '--workspace', '--all-targets'],
                    ['cargo', 'test', '--workspace', '--all-targets', '--no-default-features', '--features', 'gc-mark-sweep,heap-verify'],
                    ['cargo', 'test', '--workspace', '--lib', '--tests', '--no-default-features', '--features', 'gc-mark-sweep,heap-verify,gc-stress'],
                    ['cargo', 'test', '--workspace', '--doc'],
                    ['cargo', 'run', '-q', '-p', 'benitoite', '--example', 'gen_skill'],
                    ['cargo', 'deny', '--version'],
                    *[['cargo', 'deny', '--format', 'json', '--log-level', 'debug',
                       '--manifest-path', manifest, '--config', 'deny.toml', '--locked', 'check', 'advisories']
                      for manifest in ('Cargo.toml', 'fuzz/Cargo.toml')],
                ])
                executions = [c for c in self.box.calls() if '--ignored' in c]
                self.assertEqual([c[c.index('--') + 1:] for c in executions],
                                 [['--ignored', '--skip', 'export_coverage', '--skip', 'export_desugar_corpus']] * 2)
                self.assertEqual([c[c.index('--features') + 1] for c in executions],
                                 ['gc-mark-sweep,heap-verify', 'gc-mark-sweep,heap-verify,gc-stress'])
                self.assertEqual(result.stdout.count('completed 2 long tests'), 2)
                self.assertIn('selected checks passed', result.stdout)
        finally:
            syntax.write_bytes(before)
            (self.box.root / 'crates/benitoite/src/change.rs').unlink()
            (self.box.root / 'docs/reference/benitoite.md').unlink()

    def test_change_partial_selection_preserves_configurations_and_failures(self):
        args = ['--level', 'change', '--base', 'missing-base', '--only',
                'test_default_all,test_heap_all,test_stress,doc_default,lint_heap,heap_checks,formal_build,licenses,spec_examples,reference_examples,skill_docs']
        self.box.put('unknown.input', 'unclassified\n')
        try:
            plan = self.box.check(*args, '--dry-run')
            self.assertEqual(plan.returncode, 0, plan.stderr)
            self.assertIn('partial selection', plan.stdout)
            self.assertNotIn('== stop:', plan.stdout)
            self.assertNotIn('[long_only]', plan.stdout)
            self.assertEqual(self.box.calls(), [])
            result = self.box.check(*args)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            calls = self.box.calls()
            self.assertEqual(calls, [
                ['cargo', 'clippy', '--workspace', '--all-targets', '--no-default-features', '--features', 'gc-mark-sweep,heap-verify,alloc-stats'],
                ['cargo', 'test', '--workspace', '--all-targets'],
                ['cargo', 'test', '--workspace', '--all-targets', '--no-default-features', '--features', 'gc-mark-sweep,heap-verify'],
                ['cargo', 'test', '--workspace', '--lib', '--tests', '--no-default-features', '--features', 'gc-mark-sweep,heap-verify,gc-stress'],
                ['cargo', 'test', '--workspace', '--doc'],
                ['cargo', 'deny', '--version'], ['cargo', 'deny', 'check', 'licenses'],
                ['check-heap.sh'], ['lake', 'build'],
            ])
            for index in (1, 4, len(calls)):
                self.box.env['POLICY_FAIL'] = str(index)
                try:
                    result = self.box.check(*args)
                    self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                    self.assertEqual(self.box.calls(), calls[:index])
                    self.assertNotIn('selected checks passed', result.stdout)
                finally:
                    self.box.env.pop('POLICY_FAIL')
            self.box.env['POLICY_LAKE_OUTPUT'] = "warning: declaration uses 'sorry'\n"
            try:
                result = self.box.check('--level', 'change', '--only', 'formal_build')
                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertIn('formal/ has sorry', result.stderr)
                self.assertNotIn('selected checks passed', result.stdout)
            finally:
                self.box.env.pop('POLICY_LAKE_OUTPUT')
            # heap/stressだけでは既定構成の文書例を包含しない。
            args = ['--level', 'change', '--only',
                    'test_heap_all,test_stress,spec_examples,reference_examples,skill_docs']
            plan = self.box.check(*args, '--dry-run')
            self.assertEqual(plan.returncode, 0, plan.stderr)
            self.assertNotIn('omitted:', plan.stdout)
            self.assertEqual(self.box.calls(), [])
            result = self.box.check(*args)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(self.box.calls(), [
                calls[2], calls[3],
                *[['cargo', 'test', '-q', '-p', 'benitoite', '--test', name]
                  for name in ('spec_examples', 'reference_examples', 'skill_docs')],
            ])
        finally:
            (self.box.root / 'unknown.input').unlink()

    def test_release_and_long_runner_connections(self):
        with self.box.ignored():
            # 未知のファイルと存在しない基準もreleaseでは分類しない。
            self.box.put('unknown.input', 'unclassified\n')
            try:
                for level, only, call_count in [
                    ('work', 'release_stack', 1),
                    ('change', 'release_stack', 1),
                    ('change', 'long_only', 2),
                    ('release', '', 1),
                    ('release', 'release_stack', 1),
                ]:
                    with self.subTest(level=level, only=only):
                        args = ['--level', level, '--base', 'missing-base', *(['--only', only] if only else [])]
                        plan = self.box.check(*args, '--dry-run')
                        self.assertEqual(plan.returncode, 0, plan.stderr)
                        self.assertEqual(self.box.calls(), [])
                        self.assertIn('scripts/check/run_ignored.py', plan.stdout)
                        self.assertNotIn('== stop:', plan.stdout)
                        self.assertEqual(re.findall(r'^   \[([a-z_]+)\]', plan.stdout, re.MULTILINE), [only] if only else ['release_stack', 'advisories'])
                        result = self.box.check(*args)
                        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                        calls = self.box.calls()
                        executions = [c for c in calls if c[1] == 'test']
                        self.assertEqual(len(executions), call_count)
                        if only != 'long_only':
                            self.assertTrue(all('--release' in c and '--lib' in c for c in executions))
                        if level == 'release':
                            self.assertIn('manual verification required:', plan.stdout)
                            self.assertIn('Release acceptance remains pending', result.stdout)
                            self.assertNotIn('all checks passed', result.stdout)
                        for index in (1, len(calls)):
                            self.box.env['POLICY_FAIL'] = str(index)
                            try:
                                failed = self.box.check(*args)
                                self.assertEqual(failed.returncode, 1, failed.stdout + failed.stderr)
                                self.assertEqual(self.box.calls(), calls[:index])
                                self.assertNotIn('selected checks passed', failed.stdout)
                            finally:
                                self.box.env.pop('POLICY_FAIL')
            finally:
                (self.box.root / 'unknown.input').unlink()


class AdvisoriesTests(unittest.TestCase):
    def setUp(self):
        self.box = Sandbox()
        self.args = ['--level', 'work', '--only', 'advisories', '--base', self.box.base]

    def tearDown(self):
        self.box.close()

    def run_cases(self, workspace, fuzz):
        self.box.put('.external/advisories.json', json.dumps(dict(workspace=workspace, fuzz=fuzz)))
        self.box.env['POLICY_ADVISORIES'] = str(self.box.bin / 'advisories.json')
        result = self.box.check(*self.args)
        reports = sorted((self.box.root / 'target/check-advisories').glob('*/report.json'),
                         key=lambda path: path.stat().st_mtime_ns)
        return result, json.loads(reports[-1].read_text())

    def test_selection_without_changes_explicit_levels_and_dry_run(self):
        for level in ('work', 'stage', 'change', 'release'):
            with self.subTest(level=level):
                args = ['--level', level, '--only', 'advisories', '--base', 'missing-base']
                plan = self.box.check(*args, '--dry-run')
                self.assertEqual(plan.returncode, 0, plan.stderr)
                self.assertIn('--manifest-path Cargo.toml --config deny.toml --locked check advisories', plan.stdout)
                self.assertIn('--manifest-path fuzz/Cargo.toml --config deny.toml --locked check advisories', plan.stdout)
                self.assertEqual(self.box.calls(), [])
                self.assertFalse((self.box.root / 'target').exists())
        for level, expected in [('work', []), ('change', ['advisories']),
                                ('release', ['release_stack', 'advisories'])]:
            plan = self.box.check('--level', level, '--base', self.box.base, '--dry-run')
            self.assertEqual(plan.returncode, 0, plan.stderr)
            self.assertEqual(re.findall(r'^   \[([a-z_]+)\]', plan.stdout, re.MULTILINE), expected)
            self.assertEqual(self.box.calls(), [])
        # 名指し以外の既存検査の集合は、固定legacy記録でも引き続き検査する。
        self.assertEqual(self.box.check('--only', 'advisories', '--dry-run').returncode, 2)

    def test_target_states_raw_evidence_and_exit_status(self):
        def record(kind, fields):
            return json.dumps(dict(type=kind, fields=fields)) + '\n'
        clear = dict(stderr=record('summary', dict(advisories=dict(errors=0, warnings=0, notes=0, helps=0))))
        finding = dict(exit=1, stderr=record('diagnostic', dict(
            severity='error', code='vulnerability', message='fixture advisory',
            advisory=dict(id='RUSTSEC-2099-0001', package='fixture'),
            graphs=[dict(Krate=dict(name='fixture', version='1.2.3'))],
            notes=['Solution: Upgrade to >=1.2.4', 'Announcement: https://example.invalid/advisory']))
            + record('summary', dict(advisories=dict(errors=1, warnings=0, notes=0, helps=0))))
        unavailable = dict(exit=1, stderr=record('log', dict(level='ERROR', message='failed to fetch advisory database: network unavailable')))
        config = dict(exit=1, stderr=record('log', dict(level='ERROR', message="failed to parse config from 'deny.toml'")))
        locked = dict(exit=1, stderr=record('log', dict(level='ERROR', message=
            '`cargo metadata` exited with an error: error: cannot update the lock file fuzz/Cargo.lock because --locked was passed to prevent this')))
        locked_legacy = dict(exit=1, stderr=record('log', dict(level='ERROR', message=
            'the lock file needs to be updated but --locked was passed to prevent this')))
        index = dict(stderr=record('diagnostic', dict(code='index-failure', severity='warning'))
                     + record('summary', dict(advisories=dict(errors=0, warnings=1, notes=0, helps=0))))
        cases = [
            (clear, clear, ['clear', 'clear'], 0),
            (finding, clear, ['advisories', 'clear'], 0),
            (clear, finding, ['clear', 'advisories'], 0),
            (finding, finding, ['advisories', 'advisories'], 0),
            (unavailable, clear, ['unverified', 'clear'], 0),
            (clear, unavailable, ['clear', 'unverified'], 0),
            (unavailable, unavailable, ['unverified', 'unverified'], 0),
            (finding, unavailable, ['advisories', 'unverified'], 0),
            (dict(exit=1, stderr='unknown output containing RUSTSEC-2099-0001'), clear, ['unverified', 'clear'], 0),
            (dict(stderr=''), clear, ['unverified', 'clear'], 0),
            (dict(stderr=record('diagnostic', dict(severity='warning', code='future-code'))),
             clear, ['unverified', 'clear'], 0),
            (dict(stderr=record('log', dict(level='ERROR', message=[]))),
             clear, ['unverified', 'clear'], 0),
            (dict(exit=0, stderr=finding['stderr']), clear, ['unverified', 'clear'], 0),
            (index, clear, ['unverified', 'clear'], 0),
            (locked, clear, ['error', 'clear'], 1),
            (clear, locked, ['clear', 'error'], 1),
            (locked_legacy, clear, ['error', 'clear'], 1),
            (config, clear, ['error', 'clear'], 1),
            (clear, config, ['clear', 'error'], 1),
            (dict(exit=17, stderr='executor broke'), clear, ['error', 'clear'], 1),
            (dict(exit=1, stderr="thread 'main' panicked at fixture"), clear, ['error', 'clear'], 1),
        ]
        for first, second, states, code in cases:
            with self.subTest(states=states, code=code, first=first):
                result, report = self.run_cases(first, second)
                self.assertEqual(result.returncode, code, result.stdout + result.stderr)
                if first in (locked, locked_legacy) or second in (locked, locked_legacy):
                    self.assertIn('lock needs update (--locked)', result.stdout)
                self.assertEqual(report['exit'], code)
                self.assertEqual([t['state'] for t in report['targets']], states)
                self.assertEqual('=== ALL TARGETS CHECKED: 0 advisories ===' in result.stdout,
                                 states == ['clear', 'clear'])
                self.assertEqual(self.box.calls(), [
                    ['cargo', 'deny', '--version'],
                    *[['cargo', 'deny', '--format', 'json', '--log-level', 'debug',
                       '--manifest-path', manifest, '--config', 'deny.toml', '--locked', 'check', 'advisories']
                      for manifest in ('Cargo.toml', 'fuzz/Cargo.toml')]])
                evidence = sorted((self.box.root / 'target/check-advisories').glob('*/report.json'),
                                  key=lambda p: p.stat().st_mtime_ns)[-1].parent
                for target, case in zip(report['targets'], (first, second)):
                    self.assertEqual(target['lock_sha256'], target['lock_sha256_after'])
                    self.assertEqual((evidence / target['raw']['stderr']).read_text(), case.get('stderr', ''))
                    if target['state'] == 'advisories':
                        self.assertEqual(target['count'], 1)
                        self.assertEqual(target['ids'], ['RUSTSEC-2099-0001'])
                        self.assertIn('fixture 1.2.3', result.stdout)
                        self.assertIn('Upgrade to >=1.2.4', result.stdout)
                        self.assertIn('https://rustsec.org/advisories/RUSTSEC-2099-0001.html', result.stdout)

    def test_missing_tool_and_writable_db_copy(self):
        self.box.env['POLICY_ADVISORIES_MISSING'] = '1'
        result, report = self.run_cases({}, {})
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual([t['state'] for t in report['targets']], ['unverified', 'unverified'])
        self.assertIn('cargo-deny unavailable', result.stdout)
        self.assertNotIn('ALL TARGETS CHECKED', result.stdout)
        self.box.env.pop('POLICY_ADVISORIES_MISSING')
        original = (self.box.root / 'deny.toml').read_bytes()
        result = execute([sys.executable, '-B', 'scripts/check/advisories.py', '--db-path',
                          str(self.box.root / '.external/db')], self.box.root, self.box.env)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual((self.box.root / 'deny.toml').read_bytes(), original)
        reports = sorted((self.box.root / 'target/check-advisories').glob('*/report.json'),
                         key=lambda p: p.stat().st_mtime_ns)
        report = json.loads(reports[-1].read_text())
        copied = (reports[-1].parent / 'deny.effective.toml').read_text()
        self.assertEqual(copied.replace('[advisories]\ndb-path = '
                         + json.dumps(report['db_path_override']), '[advisories]'), original.decode())
        for target in report['targets']:
            self.assertIn(report['effective_config'], target['raw']['command'])

    def test_saved_evidence_redacts_local_paths_after_database_lookup(self):
        with tempfile.TemporaryDirectory(prefix='benitoite-home-') as home, \
                tempfile.TemporaryDirectory(prefix='benitoite-tmp-') as scratch:
            self.box.env.update(HOME=home, TMPDIR=scratch, TMP=scratch, TEMP=scratch)
            paths = [str(self.box.root), home, scratch]
            def record(message):
                return json.dumps(dict(type='log', fields=dict(level='DEBUG', message=message))) + '\n'
            stdout = record('paths: ' + ' '.join(path + '/source' for path in paths))
            stderr = (record('loading advisory database from ' + str(self.box.root))
                      + json.dumps(dict(type='summary', fields=dict(advisories=dict(
                          errors=0, warnings=0, notes=0, helps=0)))) + '\n')
            self.box.put('.external/advisories.json', json.dumps(dict.fromkeys(
                ('workspace', 'fuzz'), dict(stdout=stdout, stderr=stderr))))
            self.box.env['POLICY_ADVISORIES'] = str(self.box.bin / 'advisories.json')
            self.box.env['BENITOITE_ADVISORY_DB_PATH'] = scratch + '/db'
            result = self.box.check(*self.args)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            evidence = next((self.box.root / 'target/check-advisories').iterdir())
            # 表示と実際のコマンドは元のパスを使い、保存された全ファイルだけを検査する。
            self.assertIn(stdout, result.stdout)
            for path in evidence.iterdir():
                saved = path.read_text()
                for original in paths:
                    self.assertNotIn(original, saved, path.name)
            self.assertIn('<repo>/source <home>/source <tmp>/source',
                          (evidence / 'workspace.stdout').read_text())
            self.assertIn('loading advisory database from <repo>',
                          (evidence / 'fuzz.stderr').read_text())
            self.assertIn('db-path = "<tmp>/db"', (evidence / 'deny.effective.toml').read_text())
            report = json.loads((evidence / 'report.json').read_text())
            self.assertTrue(report['path_redaction']['applied'])
            self.assertEqual(report['db_path_override'], '<tmp>/db')
            for target in report['targets']:
                self.assertEqual(target['state'], 'clear')
                self.assertEqual(target['databases'], [dict(path='<repo>', commit=self.box.base)])
            commands = self.box.calls()
            effective = str(evidence.resolve() / 'deny.effective.toml')
            for command in commands[1:]:
                self.assertEqual(command[command.index('--config') + 1], effective)


class IgnoredTests(unittest.TestCase):
    def setUp(self):
        self.box = Sandbox()
        self.scenario = ignored_fixture()

    def tearDown(self):
        self.box.close()

    def run_runner(self, *args):
        self.box.put('.external/scenario.json', json.dumps(self.scenario))
        self.box.env['POLICY_CARGO'] = str(self.box.bin / 'scenario.json')
        self.box.log.unlink(missing_ok=True)
        return execute([sys.executable, '-B', 'scripts/check/run_ignored.py', *args],
                       self.box.root, self.box.env)

    def test_selection_and_batch_execution(self):
        for configuration in ('heap', 'stress'):
            with self.subTest(configuration=configuration):
                result = self.run_runner('--kind', 'long', '--configuration', configuration)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertEqual(self.box.calls(), [[
                    'cargo', 'test', '--workspace', '--no-default-features', '--features',
                    'gc-mark-sweep,heap-verify' + (',gc-stress' if configuration == 'stress' else ''),
                    '--lib', '--tests', '--', '--ignored', '--skip', 'export_coverage',
                    '--skip', 'export_desugar_corpus',
                ]])
                self.assertIn('completed 2 long tests', result.stdout)
                self.assertIn('cargo progress', result.stderr)
        result = self.run_runner('--kind', 'release-stack', '--configuration', 'release')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.box.calls(), [[
            'cargo', 'test', '--release', '-p', 'benitoite', '--lib', '--',
            'pipeline::tests::stages_fit_the_measured_stack_', '--include-ignored',
        ]])
        self.assertIn('completed 10 release-stack tests', result.stdout)

    def test_invalid_execution_configuration(self):
        for kind, configuration in [('long', 'release'), ('release-stack', 'heap'),
                                     ('release-stack', 'stress')]:
            result = self.run_runner('--kind', kind, '--configuration', configuration)
            self.assertEqual(result.returncode, 1, result.stderr)
            self.assertEqual(self.box.calls(), [])

    def test_missing_and_invalid_summaries(self):
        valid = self.scenario['long'][0]
        for summaries in ([], ['truncated output'], [valid.replace('0 failed', '1 failed')],
                          [valid.replace('0 ignored', '1 ignored')],
                          [valid.replace('0 measured', '1 measured')],
                          [valid.replace('1 passed', '0 passed')]):
            with self.subTest(summaries=summaries):
                self.scenario['long'] = summaries
                result = self.run_runner('--kind', 'long', '--configuration', 'heap')
                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertIn('FAILED:', result.stderr)
                self.assertEqual(len(self.box.calls()), 1)
                self.assertNotIn('completed ', result.stdout)

    def test_release_stack_requires_exactly_ten(self):
        valid = self.scenario['stack'][0]
        for count in (0, 9, 11):
            with self.subTest(count=count):
                self.scenario['stack'] = [valid.replace('10 passed', f'{count} passed')]
                result = self.run_runner('--kind', 'release-stack', '--configuration', 'release')
                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertIn('exactly 10', result.stderr)
                self.assertEqual(len(self.box.calls()), 1)

    def test_execution_failures_even_with_success_summary(self):
        self.scenario['execution'] = 'exit'
        result = self.run_runner('--kind', 'long', '--configuration', 'heap')
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn('external command exited 19', result.stderr)
        self.assertEqual(len(self.box.calls()), 1)
        self.assertNotIn('completed ', result.stdout)
        self.scenario.pop('execution')
        self.box.env['POLICY_FAIL'] = '1'
        result = self.run_runner('--kind', 'long', '--configuration', 'heap')
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn('external command exited 17', result.stderr)


if __name__ == '__main__':
    unittest.main()
