"""本物の parser と移行 CLI を使い、候補と確認後の適用を検査する。"""
import copy
import json
import pathlib
import subprocess
import sys
import tempfile
import unittest

from migrate import REPO, shared

HELPER = REPO / 'target/debug/examples/try_actions_inventory'
SCRIPT = pathlib.Path(__file__).with_name('migrate.py')
SOURCE = '''function read(r: Result[Integer, String]) -> Result[Integer, String]
  bind value <- try r
  return Result.Ok(value)
end function
'''


class TryMigrationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.temp.name)
        self.out = self.root / 'review'

    def tearDown(self):
        self.temp.cleanup()

    def put(self, path, source):
        target = self.root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(source.encode() if isinstance(source, str) else source)

    def cli(self, *args, success=True):
        result = subprocess.run([sys.executable, '-B', str(SCRIPT), '--root', str(self.root),
                                 '--helper', str(HELPER), *map(str, args)],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0 if success else 1, result.stdout + result.stderr)
        return result

    def scan(self, *paths):
        self.cli('inventory', '--out', self.out, *paths)
        return json.loads((self.out / 'manifest.json').read_text())

    def save(self, manifest):
        path = self.out / 'manifest.json'
        path.write_text(shared.dump(manifest))
        return path, shared.sha(path.read_bytes())

    def test_operand_boundaries_through_parser_and_host_edits(self):
        cases = [
            ('pipe', '''function read(r: Result[Integer, String]) -> Result[Integer, String]
  bind value <- try r
    |> Result.map(f: lambda(value) return value + 1)
  return Result.Ok(value)
end function
''', 'Result.map(f: lambda(value) return value + 1)', 'Result.map(f: lambda(value) return value + 1) or return'),
            ('lambda', '''function read(r: Result[Integer, String]) -> Result[Integer, String]
  bind f <- lambda() -> Result[Integer, String] return Result.Ok(try r)
  return f()
end function
''', 'Result.Ok(try r)', 'Result.Ok(try r or return)'),
            ('nested', '''function read(r: Result[Result[Integer, String], String]) -> Result[Integer, String]
  return Result.Ok(try try r)
end function
''', 'try try r', 'try try r or return or return'),
            ('interpolation', '''function read(r: Result[Integer, String]) -> Result[String, String]
  return Result.Ok("value: ${try r}")
end function
''', '${try r}', '${try r or return}'),
        ]
        for name, source, before, after in cases:
            with self.subTest(name=name):
                self.put('example.bnt', source)
                manifest = self.scan('example.bnt')
                rows = manifest['candidates']
                self.assertEqual(len(rows), 2 if name == 'nested' else 1)
                self.assertTrue(all(r['typed'] and r['classification'] == 'change' for r in rows), rows)
                self.assertTrue(all(r['proposed_action'] == 'return' for r in rows))
                self.assertEqual((self.root / 'example.bnt').read_text(), source)
                if name == 'nested':
                    (self.out / 'manifest.applied.json').unlink(missing_ok=True)
                    partial = copy.deepcopy(manifest)
                    partial['candidates'][0]['confirmation'] = 'approved'
                    path, digest = self.save(partial)
                    self.assertIn('nested try action dependency', self.cli('apply', '--manifest', path,
                                  '--reviewed-sha256', digest, success=False).stderr)
                    self.assertEqual((self.root / 'example.bnt').read_text(), source)
                for row in rows:
                    row['confirmation'] = 'approved'
                path, digest = self.save(manifest)
                receipt = path.with_suffix('.applied.json')
                receipt.unlink(missing_ok=True)
                self.cli('apply', '--manifest', path, '--reviewed-sha256', digest)
                self.assertEqual((self.root / 'example.bnt').read_text(), source.replace(before, after))
                # 道具で期待値を作らず、独立に指定したソースを実際に再解析・型検査する。
                migrated = self.scan('example.bnt')
                self.assertTrue(all(r['typed'] and r['action'] == 'return' for r in migrated['candidates']))

    def test_markdown_inline_multiline_and_rust_escapes(self):
        escaped = json.dumps(SOURCE.replace('try r', 'try (r)'), ensure_ascii=False)
        hosts = {
            'guide.md': '説明\r\n```bnt\r\n' + SOURCE.replace('\n', '\r\n') + '```\r\n',
            'inline.md': 'Run `' + SOURCE + '` here. `try e` is notation.\n',
            'crates/benitoite/examples/raw.rs': 'const SAMPLE: &str = r##"' + SOURCE + '"##;\n',
            'crates/benitoite/examples/escaped.rs': 'const SAMPLE: &str = ' + escaped.replace('(r)', '(\\u{72})') + ';\n',
        }
        for name, host in hosts.items():
            self.put(name, host)
        manifest = self.scan(*hosts)
        rows = manifest['candidates']
        actual = [r for r in rows if r['classification'] == 'change']
        self.assertEqual(len(actual), 4, rows)
        self.assertEqual([r['before'] for r in actual], ['try (\\u{72})', 'try r', 'try r', 'try r'])
        self.assertEqual(len([r for r in rows if r['classification'] == 'notation']), 1)
        for row in actual:
            row['confirmation'] = 'approved'
        path, digest = self.save(manifest)
        self.cli('apply', '--manifest', path, '--reviewed-sha256', digest)
        for name, host in hosts.items():
            expected = host.replace('try r', 'try r or return').replace(
                'try (\\u{72})', 'try (\\u{72}) or return')
            self.assertEqual((self.root / name).read_bytes(), expected.encode())

    def test_classification_and_conservative_holds(self):
        hosts = {
            'crates/benitoite/tests/input.rs': 'const S: &str = r"' + SOURCE + '";',
            'docs/archive/old.md': '`try old`\n',
            'docs/archive/old.rs': '#[test]\nfn old() { let s = r"' + SOURCE + '"; }',
            'notation.md': '`try e`\n```ebnf\nTry = "try" Expr\n```\n',
            'test-guide.md': '```benitoite test\n' + SOURCE + '```\n',
            'generated.rs': 'let s = format!(r"' + SOURCE + '");',
            'negative.bnt': SOURCE.replace('Result.Ok(value)', 'missing(value)'),
            'comment.bnt': '// Example: try f()\nfunction main() -> Unit\nend function\n',
            'docs/reference/benitoite-minimal.md': '```bnt\n' + SOURCE + '```\n',
            'migration.md': 'Before\n```bnt\n' + SOURCE + '```\n',
        }
        for name, source in hosts.items():
            self.put(name, source)
        manifest = self.scan(*hosts)
        by_path = {}
        for row in manifest['candidates']:
            by_path.setdefault(row['path'], []).append(row)
            self.assertEqual(row['edits'], [])
            self.assertEqual(row['confirmation'], 'pending')
        self.assertEqual(by_path['crates/benitoite/tests/input.rs'][0]['classification'], 'keep_test')
        self.assertEqual(by_path['docs/archive/old.md'][0]['classification'], 'history')
        self.assertEqual(by_path['docs/archive/old.rs'][0]['classification'], 'history')
        self.assertEqual({r['classification'] for r in by_path['notation.md']}, {'notation'})
        self.assertEqual(by_path['test-guide.md'][0]['classification'], 'hold')
        self.assertIn('non_executable_fence', by_path['test-guide.md'][0]['holds'])
        self.assertIn('generated_or_concatenated_rust', by_path['generated.rs'][0]['holds'])
        self.assertIn('parse_or_type_errors', by_path['negative.bnt'][0]['holds'])
        self.assertIn('non_ast_example_or_text', by_path['comment.bnt'][0]['holds'])
        self.assertIn('link_current_reference', by_path['docs/reference/benitoite-minimal.md'][0]['holds'])
        self.assertEqual(by_path['migration.md'][0]['classification'], 'pre_migration')
        self.assertEqual(sum(manifest['counts'].values()), len(manifest['candidates']))

    def test_die_contract_and_reusable_benchmark_choices(self):
        source = '''function main() -> Result[Unit, String]
  bind r: Result[Integer, String] <- Result.Ok(7)
  bind value <- try r
  return Result.Ok(())
end function
'''
        self.put('example.bnt', source)
        manifest = self.scan('example.bnt')
        row, = manifest['candidates']
        self.assertEqual(row['proposed_action'], 'die')
        self.assertEqual(row['owner']['return_type'], 'Result[Unit, String]')
        self.assertEqual(row['classification'], 'hold')
        self.assertIn('contract_review_required', row['holds'])
        row['confirmation'] = 'approved'
        path, digest = self.save(manifest)
        self.assertIn('die contract review required', self.cli('apply', '--manifest', path,
                      '--reviewed-sha256', digest, success=False).stderr)
        self.assertEqual((self.root / 'example.bnt').read_text(), source)
        row['holds'] = []
        row['classification'] = 'change'
        row['contract_reviewed'] = True
        row['contract_changes'] = {'uses': 'Add Process.Exit and its import.',
                                   'return': 'Keep Result[Unit, String].',
                                   'output': 'Explicit failure exit 1 with the original cause.'}
        end = source.index('\n')
        row['edits'].extend([
            {'start': 0, 'end': 0, 'before': '',
             'after': 'import Benitoite.Unofficial.IO.Process\n'},
            {'start': end, 'end': end, 'before': '', 'after': ' uses Process.Exit'}])
        path, digest = self.save(manifest)
        self.cli('apply', '--manifest', path, '--reviewed-sha256', digest)
        expected = ('import Benitoite.Unofficial.IO.Process\n' + source.replace(
            'function main() -> Result[Unit, String]',
            'function main() -> Result[Unit, String] uses Process.Exit').replace('try r', 'try r or die'))
        self.assertEqual((self.root / 'example.bnt').read_text(), expected)
        migrated = self.scan('example.bnt')
        self.assertTrue(migrated['candidates'][0]['typed'])
        self.assertEqual(migrated['candidates'][0]['action'], 'die')
        # main という名前でもベンチマークは戻り値と仕事量を保つ提案にする。
        self.put('tools/bench/work.bnt', source)
        benchmark = self.scan('tools/bench/work.bnt')
        self.assertEqual(benchmark['candidates'][0]['proposed_action'], 'return')

    def test_review_hash_all_inputs_ranges_diff_and_reapply(self):
        self.put('example.bnt', SOURCE)
        self.put('untouched.bnt', 'function main() -> Unit\nend function\n')
        manifest = self.scan('example.bnt', 'untouched.bnt')
        row, = manifest['candidates']
        row['confirmation'] = 'approved'
        path, digest = self.save(manifest)
        result = self.cli('apply', '--manifest', path, '--reviewed-sha256', '0' * 64, success=False)
        self.assertIn('reviewed manifest hash mismatch', result.stderr)
        unchanged = (self.root / 'untouched.bnt').read_bytes()
        self.put('untouched.bnt', unchanged + b'\n')
        result = self.cli('apply', '--manifest', path, '--reviewed-sha256', digest, success=False)
        self.assertIn('input hash mismatch', result.stderr)
        self.assertEqual((self.root / 'example.bnt').read_text(), SOURCE)
        self.put('untouched.bnt', unchanged)
        invalid = copy.deepcopy(manifest)
        invalid['candidates'][0]['edits'][0]['end'] = 99999
        path, bad_digest = self.save(invalid)
        self.assertIn('invalid range', self.cli('apply', '--manifest', path,
                      '--reviewed-sha256', bad_digest, success=False).stderr)
        self.assertEqual((self.root / 'example.bnt').read_text(), SOURCE)
        mismatch = copy.deepcopy(manifest)
        candidate = mismatch['candidates'][0]
        candidate['proposed_action'] = 'die'
        candidate['contract_reviewed'] = True
        candidate['contract_changes'] = {'uses': 'Checked.', 'return': 'Checked.', 'output': 'Checked.'}
        path, bad_digest = self.save(mismatch)
        self.assertIn('action edit mismatch', self.cli('apply', '--manifest', path,
                      '--reviewed-sha256', bad_digest, success=False).stderr)
        path, digest = self.save(manifest)
        diff = self.out / 'approved.diff'
        self.cli('diff', '--manifest', path, '--out', diff)
        self.assertIn('+  bind value <- try r or return\n', diff.read_text())
        self.cli('apply', '--manifest', path, '--reviewed-sha256', digest)
        expected = SOURCE.replace('try r', 'try r or return')
        self.assertEqual((self.root / 'example.bnt').read_text(), expected)
        result = self.cli('apply', '--manifest', path, '--reviewed-sha256', digest)
        self.assertEqual(result.stdout, 'already applied; no diff\n')
        self.assertEqual((self.root / 'example.bnt').read_text(), expected)
        self.put('untouched.bnt', unchanged + b'\n')
        self.assertIn('applied receipt mismatch', self.cli('apply', '--manifest', path,
                      '--reviewed-sha256', digest, success=False).stderr)

    # 関門: 元の個別契約と合併した上限、ホスト位置、共通宣言の編集禁止を実CLIで守る。
    def test_file_contracts_map_host_spans_and_preserve_shared_declaration(self):
        declaration = 'uses Log, Console.Write'
        source = ('// 日本語の説明\nimport Benitoite.Unofficial.IO.Console\n' + declaration + '\n' +
                  SOURCE.replace('String]\n', 'String] uses State\n', 1) + SOURCE.replace('read(', 'other('))
        hosts = {
            'effects.bnt': source,
            'guide.md': '説明\r\n```bnt\r\n' + source.replace('\n', '\r\n') + '```\r\n',
            'crates/benitoite/examples/escaped.rs': 'const S: &str = ' + json.dumps(source, ensure_ascii=False) + ';\n',
        }
        for name, host in hosts.items():
            self.put(name, host)
        manifest = self.scan(*hosts)
        self.assertEqual(manifest['version'], 2)
        for row in manifest['candidates']:
            owner = row['owner']
            self.assertEqual(row['classification'], 'change', row)
            self.assertEqual(owner['uses'], 'uses State' if owner['name'] == 'read' else '')
            self.assertEqual(owner['effective_effects'], ['Console.Write', 'Log', 'State'] if owner['name'] == 'read'
                             else ['Console.Write', 'Log'])
            self.assertEqual(owner['file_uses']['text'], declaration)
            span = owner['file_uses']['span']
            host = hosts[row['path']].encode()
            self.assertEqual(span, {'path': row['path'], 'start': host.index(declaration.encode()),
                                    'end': host.index(declaration.encode()) + len(declaration)})
            row['confirmation'] = 'approved'
        invalid = copy.deepcopy(manifest)
        row = invalid['candidates'][0]
        span = row['owner']['file_uses']['span']
        row['edits'].append({'start': span['start'], 'end': span['end'],
                             'before': declaration, 'after': 'uses Log'})
        path, digest = self.save(invalid)
        self.assertIn('shared file uses cannot be edited', self.cli('apply', '--manifest', path,
                      '--reviewed-sha256', digest, success=False).stderr)
        path, digest = self.save(manifest)
        self.cli('apply', '--manifest', path, '--reviewed-sha256', digest)
        for name, host in hosts.items():
            self.assertEqual((self.root / name).read_bytes(), host.replace('try r', 'try r or return').encode())

    def test_file_effects_do_not_enter_implementation_or_callback_contracts(self):
        source = ("uses Log\ntrait Echo[T]\n  function echo(r: Result[T, String]) -> Result[T, String]\nend trait\n"
                  "implement Echo[Integer]\n"
                  "  function echo(r: Result[Integer, String]) -> Result[Integer, String]\n"
                  "    return Result.Ok(try r)\n  end function\nend implement\n" +
                  SOURCE.replace('  bind value <- try r',
                                 '  bind f <- lambda() -> Result[Integer, String] return Result.Ok(try r)\n  bind value <- 1'))
        self.put('contracts.bnt', source)
        manifest = self.scan('contracts.bnt')
        self.assertEqual(len(manifest['candidates']), 2)
        for row in manifest['candidates']:
            self.assertEqual(row['classification'], 'change', row)
            self.assertIn(row['owner']['kind'], ('implementation', 'callback'))
            self.assertEqual(row['owner']['file_uses']['text'], 'uses Log')
            self.assertEqual(row['owner']['effective_effects'], [])

    def test_unknown_and_old_contracts_are_not_applicable(self):
        self.put('fragment.md', '```bnt\nbind value <- try r\n```\n')
        self.put('bad.bnt', 'uses Missing\n' + SOURCE)
        for row in self.scan('fragment.md', 'bad.bnt')['candidates']:
            self.assertIsNone(row['owner']['effective_effects'])
            self.assertIn('unknown_effective_contract', row['holds'])
            self.assertEqual(row['edits'], [])
        self.put('example.bnt', SOURCE)
        manifest = self.scan('example.bnt')
        manifest['candidates'][0]['confirmation'] = 'approved'
        old = copy.deepcopy(manifest)
        old['version'] = 1
        path, digest = self.save(old)
        self.assertIn('unsupported manifest version', self.cli('apply', '--manifest', path,
                      '--reviewed-sha256', digest, success=False).stderr)
        missing = copy.deepcopy(manifest)
        del missing['candidates'][0]['owner']['file_uses']
        path, digest = self.save(missing)
        self.assertIn('missing owner contract fields', self.cli('apply', '--manifest', path,
                      '--reviewed-sha256', digest, success=False).stderr)
        manifest['candidates'][0]['owner']['effective_effects'] = None
        path, digest = self.save(manifest)
        self.assertIn('held candidate cannot be applied', self.cli('apply', '--manifest', path,
                      '--reviewed-sha256', digest, success=False).stderr)

    # 関門: --helper のプロセス境界で旧出力を拒否し、空の候補として成功させない。
    def test_old_inventory_response_is_rejected(self):
        self.put('example.bnt', SOURCE)
        helper = self.root / 'old_inventory.py'
        for version in [None, 1]:
            with self.subTest(version=version):
                answer = {'tries': [], 'typed': True, 'parse_errors': [],
                          'check_codes': [], 'fragment': False}
                if version is not None:
                    answer['version'] = version
                helper.write_text(f'#!{sys.executable}\nimport json, sys\n'
                                  f'for request in json.load(sys.stdin):\n'
                                  f'    print({json.dumps(json.dumps(answer))})\n')
                helper.chmod(0o755)
                result = self.cli('--helper', helper, 'inventory', '--out', self.out,
                                  'example.bnt', success=False)
                self.assertIn('unsupported inventory version', result.stderr)
                self.assertFalse((self.out / 'manifest.json').exists())
                self.assertEqual((self.root / 'example.bnt').read_text(), SOURCE)

    def test_held_and_protected_approval_is_rejected(self):
        for name, source in [('negative.bnt', SOURCE.replace('try r', 'try absent')),
                             ('crates/benitoite/testdata/check/input.bnt', SOURCE)]:
            with self.subTest(path=name):
                self.put(name, source)
                manifest = self.scan(name)
                row, = manifest['candidates']
                row['confirmation'] = 'approved'
                path, digest = self.save(manifest)
                self.assertIn('held candidate cannot be applied', self.cli('apply', '--manifest', path,
                              '--reviewed-sha256', digest, success=False).stderr)
                self.assertEqual((self.root / name).read_text(), source)
        # 分類欄の書き換えだけで保護先へ適用できてはならない。
        row['classification'] = 'change'
        row['holds'] = []
        row['edits'] = [{'start': row['operand_host_end'], 'end': row['operand_host_end'],
                         'before': '', 'after': ' or return'}]
        path, digest = self.save(manifest)
        self.assertIn('protected migration target', self.cli('apply', '--manifest', path,
                      '--reviewed-sha256', digest, success=False).stderr)


if __name__ == '__main__':
    unittest.main()
