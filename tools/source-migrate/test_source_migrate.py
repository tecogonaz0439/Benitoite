"""独立したホストの入力と実ファイルで、共通 API の契約を検査する。"""
import copy
import json
import pathlib
import tempfile
import unittest

from source_extract import snippets
from source_migrate import apply, proposed, reviewed_manifest, safe_path, sha, write_diff


class SourceMigrationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.temp.name)
        self.receipt = self.root / 'reviewed.json.applied.json'

    def tearDown(self):
        self.temp.cleanup()

    def path_for(self, name):
        return safe_path(self.root, name)

    def prepare(self):
        sources = {'first.bnt': b'call(1)\n', 'second.bnt': b'untouched\n'}
        for path, data in sources.items():
            self.path_for(path).write_bytes(data)
        inputs = [{'path': p, 'source_sha256': sha(data)} for p, data in sources.items()]
        rows = [{**inputs[0], 'edits': [
            {'start': 5, 'end': 6, 'before': '1', 'after': '2'}]}]
        return sources, inputs, rows

    def apply_rows(self, inputs, rows):
        return apply(inputs, rows, manifest_sha256='reviewed-test-digest',
                     receipt=self.receipt, path_for=self.path_for)

    def test_host_decode_positions_and_host_edits(self):
        # 元の文字列と独立に期待値を用意し、復号後の位置からホストを編集する。
        hosts = [
            ('direct.bnt', 'try 日本(1)\r\n'.encode(), 'try 日本(1)\r\n', b'1', 'try 日本(2)\r\n'.encode()),
            ('guide.md', '# 説明\r\n```bnt\r\ntry 日本(1)\r\n```\r\n'.encode(), 'try 日本(1)\r\n', b'1', '# 説明\r\n```bnt\r\ntry 日本(2)\r\n```\r\n'.encode()),
            ('raw.rs', 'const S: &str = r##"try 日本(1)"##;'.encode(), 'try 日本(1)', b'1', 'const S: &str = r##"try 日本(2)"##;'.encode()),
            ('escaped.rs', b'const S: &str = "try \\u{65e5}\\u{672c}(\\x31)\\n";', 'try 日本(1)\n', b'\\x31', b'const S: &str = "try \\u{65e5}\\u{672c}(2)\\n";'),
            ('continued.rs', b'const S: &str = "try \\\n   call(1)";', 'try call(1)', b'1', b'const S: &str = "try \\\n   call(2)";'),
        ]
        for name, host, decoded, host_before, expected in hosts:
            with self.subTest(host=name):
                unit, = snippets(name, host)
                self.assertEqual(unit.source, decoded)
                self.assertEqual(len(unit.boundaries), len(decoded.encode()) + 1)
                if name == 'escaped.rs':
                    self.assertEqual(unit.boundaries[5:7], [-1, -1])
                pos = decoded.encode().index(b'1')
                start, end = unit.boundaries[pos:pos + 2]
                self.assertEqual(host[start:end], host_before)
                self.path_for(name).write_bytes(host)
                result = proposed([{'path': name, 'source_sha256': sha(host), 'edits': [
                    {'start': start, 'end': end, 'before': host_before.decode(), 'after': '2'}]}], self.path_for)
                self.assertEqual(result, {name: (host, expected)})
                self.assertEqual(self.path_for(name).read_bytes(), host)

    def test_host_selection_and_generated_holds(self):
        rust = b'''// "ignored()"
/* outer /* "ignored()" */ */
let ch = '"';
let a = format!("try value");
let b = r#"try other"#;
let c = b"try bytes";
let d = "try fragment" + suffix;
'''
        units = list(snippets('hosts.rs', rust))
        self.assertEqual([(u.source, u.kind, u.hold) for u in units], [
            ('try value', 'rust_string', 'generated_or_concatenated_rust'),
            ('try other', 'rust_raw', None),
            ('try bytes', 'rust_string', 'byte_literal'),
            ('try fragment', 'rust_string', 'generated_or_concatenated_rust'),
        ])
        self.assertEqual(list(snippets('hosts.rs', rust, accept=lambda s: s == 'try other')), [units[1]])
        markdown = b'```python\nignore()\n```\n~~~text\ntry value\n~~~\n```bnt\nunclosed\n'
        self.assertEqual([u.source for u in snippets('guide.md', markdown)], ['try value\n'])
        invalid, = snippets('bad.bnt', b'\xff')
        self.assertEqual((invalid.kind, invalid.hold), ('invalid_utf8', 'invalid_utf8'))

    def test_manifest_hash_diff_and_verified_reapplication(self):
        sources, inputs, rows = self.prepare()
        manifest_path = self.root / 'reviewed.json'
        raw = json.dumps({'inputs': inputs, 'candidates': rows}).encode()
        manifest_path.write_bytes(raw)
        with self.assertRaisesRegex(ValueError, 'reviewed manifest hash mismatch'):
            reviewed_manifest(manifest_path, '0' * 64)
        self.assertEqual(reviewed_manifest(manifest_path, sha(raw))['inputs'], inputs)
        diff = self.root / 'review.diff'
        write_diff(proposed(rows, self.path_for), diff)
        self.assertEqual(diff.read_text(), '--- a/first.bnt\n+++ b/first.bnt\n@@ -1 +1 @@\n-call(1)\n+call(2)\n')
        self.assertEqual(self.apply_rows(inputs, rows), 1)
        self.assertEqual(self.path_for('first.bnt').read_bytes(), b'call(2)\n')
        self.assertEqual(self.path_for('second.bnt').read_bytes(), sources['second.bnt'])
        self.assertIsNone(self.apply_rows(inputs, rows))
        self.path_for('second.bnt').write_bytes(b'changed\n')
        with self.assertRaisesRegex(ValueError, 'applied receipt mismatch'):
            self.apply_rows(inputs, rows)
        self.path_for('second.bnt').write_bytes(sources['second.bnt'])
        record = json.loads(self.receipt.read_text())
        for change in ('hash', 'missing', 'extra'):
            with self.subTest(receipt=change):
                broken = copy.deepcopy(record)
                if change == 'hash':
                    broken['manifest_sha256'] = 'other-manifest'
                elif change == 'missing':
                    del broken['files']['second.bnt']
                else:
                    broken['files']['extra.bnt'] = sha(b'')
                self.receipt.write_text(json.dumps(broken))
                with self.assertRaisesRegex(ValueError, 'applied receipt mismatch'):
                    self.apply_rows(inputs, rows)

    def test_all_inputs_and_ranges_checked_before_any_write(self):
        mutations = [
            ('input hash mismatch', lambda i, r: self.path_for('second.bnt').write_bytes(b'stale\n')),
            ('input hash mismatch', lambda i, r: self.path_for('first.bnt').write_bytes(b'call(3)\n')),
            ('conflicting input hashes', lambda i, r: i.append({**i[0], 'source_sha256': '0' * 64})),
            ('candidate input hash mismatch', lambda i, r: r[0].update(source_sha256='0' * 64)),
            ('invalid range', lambda i, r: r[0]['edits'][0].update(start=-1)),
            ('invalid range', lambda i, r: r[0]['edits'][0].update(end=99)),
            ('range content mismatch', lambda i, r: r[0]['edits'][0].update(before='wrong')),
            ('overlapping edits', lambda i, r: r[0]['edits'].append({'start': 5, 'end': 7, 'before': '1)', 'after': '3)'})),
            ('overlapping edits', lambda i, r: r[0].update(edits=[
                {'start': 5, 'end': 5, 'before': '', 'after': 'a: '},
                {'start': 5, 'end': 5, 'before': '', 'after': 'b: '} ])),
        ]
        for message, mutate in mutations:
            with self.subTest(error=message, mutation=mutate):
                sources, inputs, rows = self.prepare()
                # 後のファイルの範囲の誤りでも、先の正しい編集を書き込まない。
                rows.insert(0, {**inputs[1], 'edits': [
                    {'start': 0, 'end': 9, 'before': 'untouched', 'after': 'edited'}]})
                mutate(inputs, rows[1:])
                before = {p: self.path_for(p).read_bytes() for p in sources}
                with self.assertRaisesRegex(ValueError, message):
                    self.apply_rows(inputs, rows)
                self.assertEqual({p: self.path_for(p).read_bytes() for p in sources}, before)
                self.assertFalse(self.receipt.exists())

    def test_identical_edits_and_insertion_at_replacement_start(self):
        sources, inputs, rows = self.prepare()
        rows.append(copy.deepcopy(rows[0]))
        rows[0]['edits'].append({'start': 5, 'end': 5, 'before': '', 'after': 'value: '})
        self.assertEqual(self.apply_rows(inputs, rows), 1)
        self.assertEqual(self.path_for('first.bnt').read_bytes(), b'call(value: 2)\n')

    def test_unsafe_paths_are_rejected(self):
        for path in ('../outside.bnt', '/outside.bnt', '.', ''):
            with self.subTest(path=path), self.assertRaisesRegex(ValueError, 'unsafe path'):
                self.path_for(path)
        (self.root / 'link.bnt').symlink_to(self.root / 'actual.bnt')
        with self.assertRaisesRegex(ValueError, 'unsafe path'):
            self.path_for('link.bnt')


if __name__ == '__main__':
    unittest.main()
