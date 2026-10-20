#!/usr/bin/env python3
"""check.sh の入口と長い対象の実行器を、一時Gitリポジトリで検査する。"""

from contextlib import contextmanager
import json
import os
from pathlib import Path
import re
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
        for name in ('POLICY_FAIL', 'POLICY_CARGO', 'POLICY_LAKE_OUTPUT'):
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
        self.put('.gitignore', '.external/\n__pycache__/\n')
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

    def test_formal_batch3_entries_and_failure_propagation(self):
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
                path.write_text(EXTERNAL.replace("#!/usr/bin/env python3", "#!" + sys.executable, 1))
                path.chmod(0o755)
            for name in ('coverageDiff', 'coverageProgramDiff', 'desugarDiff', 'builtinCheck', 'surfaceCheckAll'):
                path = root / 'formal/.lake/build/bin' / name
                path.write_text(EXTERNAL.replace("#!/usr/bin/env python3", "#!" + sys.executable, 1))
                path.chmod(0o755)
            log = root / 'calls.jsonl'
            env = dict(os.environ, PATH=str(root / 'external') + os.pathsep + os.environ['PATH'], POLICY_LOG=str(log))
            for name in ('POLICY_FAIL', 'POLICY_CARGO', 'BENITOITE_DESUGAR_DIFF_DIR', 'BENITOITE_COVERAGE_DIFF_DIR'):
                env.pop(name, None)
            # 失敗時の呼び出し列も全引数で比べるため、実行ごとのPIDを含まない出力先にする。
            output_dir = root / 'target/desugar-diff/policy'
            env['BENITOITE_DESUGAR_DIFF_DIR'] = str(output_dir)
            env['BENITOITE_COVERAGE_DIFF_DIR'] = str(root / 'target/coverage-diff/policy')
            result = execute(['bash', 'scripts/check-formal.sh'], root, env)
            self.assertEqual(result.returncode, 0, result.stderr)
            calls = [json.loads(line) for line in log.read_text().splitlines()]
            independent = ['python3', '-B', 'formal/tests/test_batch3_exchange.py']
            self.assertEqual(calls.count(independent), 1)
            batch4 = ['python3', '-B', 'formal/tests/test_batch4_exchange.py']
            self.assertEqual(calls.count(batch4), 1)
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
            for call in (independent, batch4, rust[0], *checker):
                with self.subTest(failure=call):
                    log.unlink()
                    failed = execute(['bash', 'scripts/check-formal.sh'], root,
                                     dict(env, POLICY_FAIL=str(calls.index(call) + 1)))
                    self.assertEqual(failed.returncode, 17, failed.stderr)
                    self.assertEqual(len(log.read_text().splitlines()), calls.index(call) + 1)
                    self.assertEqual([json.loads(line) for line in log.read_text().splitlines()],
                                     calls[:calls.index(call) + 1])

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
             '--no-default-features', '--features', 'gc-mark-sweep'],
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
            ('fuzz/src/sample.rs', rust),
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
                    self.assertEqual(selected, units, result.stdout)
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
                    ['cargo', 'clippy', '-p', 'benitoite', '--lib', '--tests', '--no-default-features', '--features', 'gc-mark-sweep'],
                    ['cargo', 'clippy', '--workspace', '--all-targets', '--no-default-features', '--features', 'gc-mark-sweep,heap-verify,alloc-stats'],
                    ['cargo', 'test', '--workspace', '--all-targets'],
                    ['cargo', 'test', '--workspace', '--all-targets', '--no-default-features', '--features', 'gc-mark-sweep,heap-verify'],
                    ['cargo', 'test', '--workspace', '--lib', '--tests', '--no-default-features', '--features', 'gc-mark-sweep,heap-verify,gc-stress'],
                    ['cargo', 'test', '--workspace', '--doc'],
                    ['cargo', 'run', '-q', '-p', 'benitoite', '--example', 'gen_skill'],
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
                        self.assertEqual(re.findall(r'^   \[([a-z_]+)\]', plan.stdout, re.MULTILINE), [only or 'release_stack'])
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
