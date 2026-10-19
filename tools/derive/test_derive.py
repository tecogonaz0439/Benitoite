"""Management and JSON conversion tests through the real compiler and VM.

The inventory, formatter, normal check/test, edit protocol, and filesystem are
real. Fixed functions isolate management; JSON tests use production templates.
"""
from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

import derive


# Creation gate: protect reviewed edits, regeneration checks, and handwritten
# bytes. Omitting any input hash, trusting manual regions, skipping formatting,
# or comparing only output (not type/config/dependencies) must fail these tests.
# Existing source-migrate tests cannot see derive's record/marker/template
# decisions. Fixed ordinary function generation is an input to the manager;
# no compiler stage is replaced and no test-only CLI or production flag exists.
def fixed_functions(target, inventory, imports):
    names = target['config'].get('json', {})
    encode, decode = names.get('encode', 'countFields'), names.get('decode', 'unusedDecode')
    prefix = 'public ' if target['public'] else ''
    return derive.Generated(
        f'{prefix}function {encode}()->Integer\nreturn {len(target["fields"])}\nend function\n'
        f'{prefix}function {decode}()->Unit\n()\nend function\n', (encode, decode))


class Project:
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='benitoite-derive-test-')
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name).resolve()
        self.source = self.root / 'People.bnt'
        self.config = self.root / 'derive.json'
        self.config_value = {'version': 1, 'targets': [{
            'source': 'People.bnt', 'type': 'People.Person', 'region': 'person',
            'json': {'encode': 'countFields', 'decode': 'unusedDecode'}}]}
        self.source.write_bytes(b'public record Person\n  name: String\nend record\n')
        self.save_config()
        self.manager = derive.Manager(self.root, self.config, fixed_functions)

    def save_config(self):
        self.config.write_text(json.dumps(self.config_value), encoding='utf-8')

    def preview(self, name='preview'):
        return self.manager.preview(self.root / name)

    def install(self, expected_files=1):
        path, checksum = self.preview()
        self.assertEqual(self.manager.apply(path, checksum), expected_files)
        return path, checksum

    def files(self):
        return {str(p.relative_to(self.root)): p.read_bytes()
                for p in self.root.rglob('*') if p.is_file()}

    def reject_apply_unchanged(self, path, checksum, message):
        before = self.files()
        with self.assertRaisesRegex(ValueError, message):
            self.manager.apply(path, checksum)
        self.assertEqual(self.files(), before)



class Management(Project, unittest.TestCase):
    def test_preview_apply_check_reapply_and_empty_second_diff(self):
        # UTF-8 before the declaration and both original line-ending styles.
        for line_end in ('\n', '\r\n'):
            with self.subTest(line_end=line_end):
                self.source.write_bytes(('// 日本語を含む手書き\npublic record Person\n'
                                         '  name: String\nend record\n'
                                         'function main() -> Unit\n  ()\nend function\n'
                                         '@test\nfunction generatedCount() -> Unit uses Assert.Check\n'
                                         '  Assert.equal(actual: countFields(), expected: 1)\n'
                                         'end function').replace('\n', line_end).encode())
                before = self.source.read_bytes()
                out = 'crlf' if line_end == '\r\n' else 'lf'
                manifest, checksum = self.preview(out)
                self.assertEqual(self.source.read_bytes(), before)
                self.assertFalse(self.manager.record.exists())
                plan = json.loads(manifest.read_bytes())
                edit = plan['rows'][0]['edits'][0]
                self.assertEqual(edit['start'], len(before))
                self.assertEqual(edit['end'], len(before))
                self.assertEqual(self.manager.apply(manifest, checksum), 1)
                after = self.source.read_bytes()
                self.assertTrue(after.startswith(before + b'\n'))
                self.assertIn(b'function countFields() -> Integer\n  return 1\n', after)
                record = json.loads(self.manager.record.read_bytes())
                body = after.split(b'// benitoite-derive:begin person\n')[1].split(
                    b'// benitoite-derive:end person\n')[0]
                self.assertEqual(record['targets'][0]['outputSha256'], hashlib.sha256(body).hexdigest())
                snapshots = self.files()
                self.assertIsNone(self.manager.apply(manifest, checksum))
                self.manager.check()
                self.assertEqual(self.files(), snapshots)
                second, _ = self.preview(out + '-second')
                self.assertEqual((second.parent / 'changes.diff').read_bytes(), b'')
                self.assertTrue(all(not row['edits'] for row in json.loads(second.read_bytes())['rows']))
                for command in ('check', 'test'):
                    result = subprocess.run([derive.BENITOITE, command, self.source], capture_output=True)
                    self.assertEqual(result.returncode, 0, result.stderr.decode())
                self.manager.record.unlink()

    def test_approval_and_every_input_are_verified_before_writing(self):
        self.source.write_bytes(b'import Helpers\n' + self.source.read_bytes())
        helper = self.root / 'Helpers.bnt'
        helper.write_text('public function helper() -> Integer\n  return 1\nend function\n')
        path, checksum = self.preview()
        self.reject_apply_unchanged(path, '0' * 64, 'reviewed manifest hash mismatch')
        original_manifest = path.read_bytes()
        changed = json.loads(original_manifest)
        changed['rows'][0]['edits'] = [{'start': 0, 'end': 0, 'before': '',
                                       'after': '// unrelated handwritten edit\n'}]
        path.write_text(json.dumps(changed))
        reviewed_change = hashlib.sha256(path.read_bytes()).hexdigest()
        self.reject_apply_unchanged(path, reviewed_change, 'differs from current generation plan')
        path.write_bytes(original_manifest)
        path.write_bytes(path.read_bytes() + b' ')
        self.reject_apply_unchanged(path, checksum, 'reviewed manifest hash mismatch')
        path.write_bytes(path.read_bytes()[:-1])
        helper.write_text(helper.read_text().replace('return 1', 'return 2'))
        self.reject_apply_unchanged(path, checksum, 'input hash mismatch')
        helper.write_text(helper.read_text().replace('return 2', 'return 1'))
        self.config.write_text(self.config.read_text() + '\n')
        self.reject_apply_unchanged(path, checksum, 'input hash mismatch')
        self.save_config()
        self.assertEqual(self.manager.apply(path, checksum), 1)
        helper.write_text(helper.read_text() + '\n')
        self.reject_apply_unchanged(path, checksum, 'applied receipt mismatch')

    def test_owned_and_unowned_handwritten_regions_are_protected(self):
        self.source.write_bytes(self.source.read_bytes() +
                                b'// benitoite-derive:begin person\n'
                                b'function manual() -> Unit\n  ()\nend function\n'
                                b'// benitoite-derive:end person\n')
        before = self.files()
        with self.assertRaisesRegex(ValueError, 'no generation record'):
            self.preview()
        self.assertEqual(self.files(), before)
        self.source.write_bytes(b'public record Person\n  name: String\nend record\n')
        path, checksum = self.install()
        self.source.write_bytes(self.source.read_bytes().replace(b'return 1', b'return 9'))
        before = self.files()
        for action in (self.manager.check, lambda: self.preview('manual'),
                       lambda: self.manager.apply(path, checksum)):
            with self.assertRaisesRegex(ValueError, 'handwritten change|applied receipt mismatch'):
                action()
            self.assertEqual(self.files(), before)

    def test_marker_errors_and_record_changes_do_not_write(self):
        original = self.source.read_bytes()
        for text in (
            '// benitoite-derive:begin person\n',
            '// benitoite-derive:end person\n',
            '// benitoite-derive:begin person\n// benitoite-derive:begin other\n',
            '// benitoite-derive:begin person\n// benitoite-derive:end other\n',
            '// benitoite-derive:begin person\n// benitoite-derive:end person\n' * 2,
            '// benitoite-derive:begin person trailing\n',
        ):
            with self.subTest(markers=text):
                self.source.write_bytes(original + text.encode())
                with self.assertRaisesRegex(ValueError, 'region|marker'):
                    self.preview()
                self.assertFalse(self.manager.record.exists())
        self.source.write_bytes(original)
        path, checksum = self.preview()
        self.manager.record.write_text('{}')
        self.reject_apply_unchanged(path, checksum, 'generation record hash mismatch')

    def test_semantic_hashes_ignore_layout_but_detect_declaration_dependency_and_config_changes(self):
        self.source.write_text('import Address\npublic record Person\n  address: Address.Address\nend record\n')
        address = self.root / 'Address.bnt'
        address.write_text('public record Address\n  city: String\nend record\n')
        self.install()
        initial_record = self.manager.record.read_bytes()
        self.source.write_bytes('// 日本語のコメント\n'.encode() + self.source.read_bytes())
        address.write_text('// another comment\npublic record Address\n    city: String\nend record\n')
        self.manager.check()
        self.assertEqual(self.manager.record.read_bytes(), initial_record)
        baseline = self.files()
        for mutation, message in (
            (lambda: address.write_text(address.read_text().replace('city: String', 'city: String\n  zip: Integer')), 'regeneration mismatch'),
            (lambda: self.source.write_bytes(self.source.read_bytes().replace(b'address: Address.Address', b'address: Address.Address\n  age: Integer')), 'regeneration mismatch'),
            (lambda: self.set_keys({'address': 'postal_address'}), 'regeneration mismatch'),
        ):
            with self.subTest(change=message):
                mutation()
                with self.assertRaisesRegex(ValueError, message):
                    self.manager.check()
                for name, data in baseline.items():
                    (self.root / name).write_bytes(data)
        self.set_keys({'address': 'postal_address'})
        manifest, checksum = self.preview('config-change')
        self.assertEqual((manifest.parent / 'changes.diff').read_bytes(), b'')
        self.assertEqual(self.manager.apply(manifest, checksum), 0)
        self.manager.check()

    def set_keys(self, keys):
        self.config_value['targets'][0]['json']['keys'] = keys
        self.save_config()

    def test_custom_signature_changes_are_detected_even_when_output_is_identical(self):
        helper = self.root / 'Helpers.bnt'
        helper.write_text('public function encode(value: String) -> String\n  return value\nend function\n'
                          'public function decode(value: String) -> String\n  return value\nend function\n')
        self.config_value['targets'][0]['fields'] = {
            'name': {'encode': 'Helpers.encode', 'decode': 'Helpers.decode'}}
        self.save_config()
        self.install()
        helper.write_text(helper.read_text().replace('value: String', 'value: Integer'))
        with self.assertRaisesRegex(ValueError, 'regeneration mismatch'):
            self.manager.check()

    def test_name_collisions_and_multiple_regions_use_resolved_import_identity(self):
        original = self.source.read_bytes()
        self.source.write_bytes(original + b'function countFields() -> Unit\n  ()\nend function\n')
        with self.assertRaisesRegex(ValueError, 'generated name collision: countFields'):
            self.preview()
        self.source.write_bytes(b'import Helpers as Existing\n' + original)
        helper = self.root / 'Helpers.bnt'
        helper.write_text('public function value() -> Integer\n  return 3\nend function\n')

        def with_import(target, inventory, imports):
            alias = imports.require('Helpers', 'Preferred')
            value = fixed_functions(target, inventory, imports)
            return derive.Generated(value.body.replace('return 1', f'return {alias}.value()'), value.names)

        self.manager = derive.Manager(self.root, self.config, with_import)
        self.install()
        self.assertEqual(self.source.read_bytes().count(b'import Helpers'), 1)
        self.assertIn(b'Existing.value()', self.source.read_bytes())
        self.manager.check()
        # A later template requirement cannot insert import after the record.
        second_helper = self.root / 'Extra.bnt'
        second_helper.write_text('public function decode(value: String) -> String\n  return value\nend function\n')
        helper.write_text(helper.read_text() + 'public function encode(value: String) -> String\n  return value\nend function\n')
        self.config_value['targets'][0]['fields'] = {
            'name': {'encode': 'Helpers.encode', 'decode': 'Extra.decode'}}
        self.save_config()

        def new_requirement(target, inventory, imports):
            imports.require('Helpers', 'Preferred')
            imports.require('Extra', 'Extra')
            return fixed_functions(target, inventory, imports)

        late = derive.Manager(self.root, self.config, new_requirement)
        before = self.files()
        with self.assertRaisesRegex(ValueError, 'required imports cannot follow declarations'):
            late.preview(self.root / 'late-import')
        self.assertEqual(self.files(), before)

    def test_new_imports_stay_in_the_region_and_alias_collisions_are_rejected(self):
        helper = self.root / 'Helpers.bnt'
        helper.write_text('public function encode(value: String) -> String\n  return value\nend function\n'
                          'public function decode(value: String) -> String\n  return value\nend function\n')
        self.config_value['targets'][0]['fields'] = {
            'name': {'encode': 'Helpers.encode', 'decode': 'Helpers.decode'}}
        self.save_config()

        def with_import(target, inventory, imports):
            imports.require('Helpers', 'Preferred')
            return fixed_functions(target, inventory, imports)

        self.manager = derive.Manager(self.root, self.config, with_import)
        original = self.source.read_bytes()
        missing = derive.Manager(self.root, self.config,
                                 lambda t, i, a: a.require('NotLoaded', 'NotLoaded'))
        with self.assertRaisesRegex(ValueError, 'absent from declaration inventory'):
            missing.preview(self.root / 'missing-module')
        self.assertFalse((self.root / 'missing-module').exists())
        self.source.write_bytes(original + b'record Preferred\n  value: Integer\nend record\n')
        with self.assertRaisesRegex(ValueError, 'import alias collision: Preferred'):
            self.preview()
        self.source.write_bytes(original)
        self.install()
        self.assertTrue(self.source.read_bytes().startswith(
            b'// benitoite-derive:begin person\nimport Helpers as Preferred\n'))
        self.assertTrue(self.source.read_bytes().endswith(original))
        self.manager.check()
        again, _ = self.preview('again')
        self.assertEqual((again.parent / 'changes.diff').read_bytes(), b'')

    def test_multiple_targets_and_regions_apply_together(self):
        second = copy.deepcopy(self.config_value['targets'][0])
        second.update(type='People.Other', region='other', json={'encode': 'countOther', 'decode': 'decodeOther'})
        third = copy.deepcopy(second)
        third.update(source='Other.bnt', type='Other.Other')
        third['json'] = {'encode': 'countOther', 'decode': 'decodeOther'}
        self.source.write_bytes(self.source.read_bytes() + b'public record Other\n  value: Integer\nend record\n')
        (self.root / 'Other.bnt').write_bytes(b'public record Other\n  value: Integer\nend record\n')
        self.config_value['targets'] += [second, third]
        self.save_config()
        manifest, checksum = self.preview()
        self.assertEqual(self.manager.apply(manifest, checksum), 2)
        self.manager.check()
        again, _ = self.preview('again')
        self.assertEqual((again.parent / 'changes.diff').read_bytes(), b'')

    def test_formatter_failure_and_cycles_are_rejected_before_artifacts(self):
        manager = derive.Manager(self.root, self.config,
                                 lambda t, i, a: derive.Generated('function invalid(\n', ('invalid',)))
        before = self.files()
        with self.assertRaisesRegex(ValueError, 'formatting failed'):
            manager.preview(self.root / 'bad')
        self.assertEqual(self.files(), before)
        self.source.write_text('public record Person\n  next: Option[Person]\nend record\n')
        with self.assertRaisesRegex(ValueError, 'cyclic record dependency'):
            self.preview()

    def test_record_io_failure_can_be_completed_using_source_receipt(self):
        manifest, checksum = self.preview()
        original_write = Path.write_bytes

        def failing_record(path, data):
            if path == self.manager.record:
                raise OSError('record disk failure')
            return original_write(path, data)

        with patch.object(Path, 'write_bytes', failing_record):
            with self.assertRaisesRegex(OSError, 'record disk failure'):
                self.manager.apply(manifest, checksum)
        self.assertTrue(Path(str(manifest) + '.receipt.json').is_file())
        self.assertFalse(self.manager.record.exists())
        after = self.source.read_bytes()
        self.assertIsNone(self.manager.apply(manifest, checksum))
        self.assertEqual(self.source.read_bytes(), after)
        self.manager.check()

    def test_paths_artifact_collisions_and_detachment(self):
        manifest, checksum = self.preview()
        before = self.files()
        with self.assertRaisesRegex(ValueError, 'artifact already exists'):
            self.preview()
        self.assertEqual(self.files(), before)
        self.manager.apply(manifest, checksum)
        source = self.source.read_bytes()
        self.source.unlink()
        elsewhere = self.root / 'real.bnt'
        elsewhere.write_bytes(source)
        self.source.symlink_to(elsewhere)
        self.reject_apply_unchanged(manifest, checksum, 'unsafe path')
        self.source.unlink()
        self.source.write_bytes(source)
        self.config_value['targets'] = []
        self.save_config()
        with self.assertRaisesRegex(ValueError, 'removed targets'):
            self.manager.check()
        self.source.write_bytes(source.replace(b'// benitoite-derive:begin person\n', b'').replace(
            b'// benitoite-derive:end person\n', b''))
        record = json.loads(self.manager.record.read_bytes())
        record['targets'] = []
        self.manager.record.write_text(derive.migrate.dump(record))
        self.manager.check()

    def test_public_cli_refuses_unsupported_types_and_invalid_config(self):
        self.source.write_text('public record Person\n  name: Character\nend record\n')
        cases = [
            (json.dumps({'version': 1, 'targets': [{'source': 'People.bnt', 'type': 'People.Person',
                                                  'region': 'person',
                                                  'property': {'generator': 'genPerson', 'shrinker': 'shrinkPerson'}}]}),
             1, 'unsupported Property field type'),
            (json.dumps({'version': 1, 'targets': [{**self.config_value['targets'][0],
                                                  'property': {'generator': 'genPerson', 'shrinker': 'shrinkPerson'}}]}),
             1, 'unsupported JSON field type'),
            ('{"version":1,"version":1,"targets":[]}', 2, 'duplicate key'),
            ('{"version":1,"targets":[],"unknown":true}', 2, 'unknown'),
            ('{"version":2,"targets":[]}', 2, 'version'),
            ('{"version":1,"targets":[', 2, ''),
        ]
        for raw, status, explanation in cases:
            with self.subTest(config=raw):
                self.config.write_text(raw)
                before = self.files()
                result = subprocess.run([sys.executable, '-B', Path(derive.__file__), 'preview',
                                         '--root', self.root, '--config', self.config,
                                         '--out', self.root / 'cli'], capture_output=True)
                self.assertEqual(result.returncode, status, result.stderr.decode())
                self.assertIn(explanation, result.stderr.decode())
                self.assertEqual(result.stdout, b'')
                self.assertEqual(self.files(), before)

    # 四問: 実際の出力を使い、外部JSONの契約と意味ハッシュの境界を確かめる。
    # 未知のタグや番号を通す退行、表示を意味として読む退行で失敗する。
    # VMの既存例はJSONの読者を検査しない。テスト専用の本番APIは加えない。
    def test_v2_reader_and_semantic_hash_contract(self):
        inv = derive.collect(self.root, self.config)
        original = derive.structure(inv['targets'][0], inv)
        changed = copy.deepcopy(inv)
        field = changed['targets'][0]['fields'][0]
        field['span']['start'] += 10
        field['typeSpan']['start'] += 10
        field['metadata'] = {'resolved': 'unrelated display', 'original': 'Text', 'span': {}}
        changed['targets'][0]['package'] = False
        derive.validate_inventory(changed)
        self.assertEqual(derive.structure(changed['targets'][0], changed), original)
        changed['targets'][0]['fields'][0]['type']['head']['name'] = 'Benitoite.Boolean.Boolean'
        derive.validate_inventory(changed)
        self.assertNotEqual(derive.structure(changed['targets'][0], changed)['declarationSha256'], original['declarationSha256'])
        changed = copy.deepcopy(inv)
        changed['functions']['Unrelated.unchecked'] = copy.deepcopy(next(iter(inv['functions'].values())))
        self.assertEqual(derive.structure(changed['targets'][0], changed), original)
        ty = inv['targets'][0]['fields'][0]['type']
        cases = [
            {'tag': 'unsupported', 'resolved': 'Fn(..)'},
            {**ty, 'unknown': True},
            {**ty, 'head': {'tag': 'named', 'name': 'Absent.Type'}},
            {**ty, 'arguments': [copy.deepcopy(ty)]},
            {'tag': 'parameter', 'index': 0},
            {**ty, 'head': {'tag': 'unknown', 'name': 'Benitoite.String.String'}},
            {'tag': 'function', 'params': [{'name': 'x', 'type': ty}, {'name': 'x', 'type': ty}],
             'returnType': ty, 'effects': {'names': [], 'vars': [], 'failures': []}},
            {'tag': 'function', 'params': [], 'returnType': ty,
             'effects': {'names': [], 'vars': [0], 'failures': []}},
        ]
        for bad in cases:
            with self.subTest(bad=bad):
                changed = copy.deepcopy(inv)
                changed['targets'][0]['fields'][0]['type'] = bad
                with self.assertRaisesRegex(ValueError, 'derive.invalid_inventory'):
                    derive.validate_inventory(changed)
        for bad in ('Ctor { arity: 2 }', {'tag': 'constructor', 'arity': 0}, {'tag': 'mystery'}):
            with self.subTest(kind=bad):
                changed = copy.deepcopy(inv)
                c = next(iter(changed['classes'].values()))
                c['paramKind'] = bad
                with self.assertRaisesRegex(ValueError, 'derive.invalid_inventory'):
                    derive.validate_inventory(changed)
        changed = copy.deepcopy(inv)
        changed['targets'][0]['visibility'] = 'private'
        with self.assertRaisesRegex(ValueError, 'inconsistent inventory visibility'):
            derive.validate_inventory(changed)

    def test_opaque_record_and_data_generation_refused_in_owner_module(self):
        for declaration in ('record Person\n  name: String\nend record\n',
                            'data Person\n  Person(String)\nend data\n'):
            for feature in ('json', 'property'):
                with self.subTest(declaration=declaration, feature=feature):
                    self.source.write_text('@opaque\npublic ' + declaration)
                    target = self.config_value['targets'][0]
                    target.pop('json', None)
                    target.pop('property', None)
                    target[feature] = ({'encode': 'encodePerson', 'decode': 'decodePerson'} if feature == 'json'
                                       else {'generator': 'genPerson', 'shrinker': 'shrinkPerson'})
                    self.save_config()
                    before = self.files()
                    result = subprocess.run([sys.executable, '-B', Path(derive.__file__), 'preview',
                                             '--root', self.root, '--config', self.config,
                                             '--out', self.root / 'opaque-preview'], capture_output=True)
                    self.assertEqual(result.returncode, 1, result.stderr.decode())
                    self.assertIn(b'derive.opaque_target', result.stderr)
                    self.assertEqual(result.stdout, b'')
                    self.assertEqual(self.files(), before)
        # 不透明型の欄も、検査付きの作成経路を迂回させない。
        self.source.write_text('@opaque\npublic record Checked\n  value: Integer\nend record\n'
                               'public record Person\n  checked: Checked\nend record\n')
        for feature in ('json', 'property'):
            target.pop('json', None)
            target.pop('property', None)
            target[feature] = ({'encode': 'enc', 'decode': 'dec'} if feature == 'json'
                               else {'generator': 'gen', 'shrinker': 'shrink'})
            self.save_config()
            self.manager = derive.Manager(self.root, self.config)
            with self.assertRaisesRegex(ValueError, 'unsupported .* field type'):
                self.preview('opaque-field')
            self.assertFalse((self.root / 'opaque-field').exists())

    def test_opaque_fields_use_explicit_checked_custom_functions(self):
        self.source.write_text('''import Benitoite.Unofficial.Json as Json
import Benitoite.Unofficial.Json.Codec as Codec
import Benitoite.Unofficial.Test.Property
@opaque
public record Checked
  value: Integer
end record
public record Person
  checked: Checked
end record
public function encodeChecked(value: Checked) -> Result[Json.Value, Codec.ConversionError]
  return Codec.encodeInteger(Checked.value(value))
end function
public function decodeChecked(value: Json.Value) -> Result[Checked, Codec.ConversionError]
  bind raw <- try Codec.decodeInteger(value)
  return Result.Ok(Checked(value: if raw < 0 then 0 else raw end if))
end function
public function genChecked() -> Property.Gen[Checked]
  return Property.constant(Checked(value: 0))
end function
public function shrinkChecked() -> Property.Shrinker[Checked]
  return Property.Shrinker(candidates: lambda(value) return Property.ShrinkStep.Done end lambda)
end function
function main() -> Unit
  ()
end function
@test
function checkedRoundtrip() -> Unit uses Assert.Check
  bind original <- Person(checked: Checked(value: 0))
  Assert.equal(actual: Result.andThen(r: encodePerson(original), f: decodePerson), expected: Result.Ok(original))
end function
''')
        self.config_value['targets'][0].update(
            json={'encode': 'encodePerson', 'decode': 'decodePerson'},
            property={'generator': 'genPerson', 'shrinker': 'shrinkPerson'},
            fields={'checked': {'encode': 'People.encodeChecked', 'decode': 'People.decodeChecked',
                                'gen': 'People.genChecked', 'shrink': 'People.shrinkChecked'}})
        self.save_config()
        self.manager = derive.Manager(self.root, self.config)
        self.install()
        self.manager.check()
        for command in ('check', 'test'):
            result = subprocess.run([derive.BENITOITE, command, self.source], capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr.decode() + result.stdout.decode())

    def test_v1_migration_review_and_modified_region_protection(self):
        self.install()
        old = json.loads(self.manager.record.read_bytes())
        old.update(version=1, generatorVersion='1.2.0-property')
        old.pop('inventoryVersion')
        old.pop('hashVersion')
        self.manager.record.write_text(json.dumps(old))
        before = self.files()
        with self.assertRaisesRegex(ValueError, 'derive.migration_required'):
            self.manager.check()
        self.assertEqual(self.files(), before)
        path, checksum = self.preview('migration')
        plan = json.loads(path.read_bytes())
        self.assertEqual(plan['version'], 2)
        self.assertEqual(plan['recordAfter']['inventoryVersion'], 2)
        self.assertEqual(plan['recordAfter']['hashVersion'], 2)
        self.assertEqual(plan['migration']['previousRecord'], old)
        self.assertFalse(plan['migration']['semanticHashesComparable'])
        self.assertEqual((path.parent / 'changes.diff').read_bytes(), b'')
        self.assertEqual(self.manager.apply(path, checksum), 0)
        self.manager.check()
        self.assertIsNone(self.manager.apply(path, checksum))
        plan['version'] = 1
        path = self.root / 'old-manifest.json'
        path.write_text(json.dumps(plan))
        self.reject_apply_unchanged(path, hashlib.sha256(path.read_bytes()).hexdigest(), 'derive.incompatible_manifest')
        # 新版が本文を置換する場合にも、旧記録と元のbytesを先に照合する。
        self.manager.record.write_text(json.dumps(old))
        self.source.write_bytes(self.source.read_bytes().replace(b'return 1', b'return 2'))
        before = self.files()
        with self.assertRaisesRegex(ValueError, 'derive.modified_region'):
            self.preview('modified-migration')
        self.assertEqual(self.files(), before)

    def test_public_cli_empty_workflow_and_argument_errors(self):
        self.config_value['targets'] = []
        self.save_config()

        def cli(command, *extra):
            return subprocess.run([sys.executable, '-B', Path(derive.__file__), command,
                                   '--root', self.root, '--config', self.config, *extra], capture_output=True)

        self.assertEqual(cli('check').returncode, 0)
        result = cli('preview', '--out', self.root / 'cli')
        self.assertEqual(result.returncode, 0, result.stderr.decode())
        manifest = self.root / 'cli/manifest.json'
        checksum = hashlib.sha256(manifest.read_bytes()).hexdigest()
        self.assertIn(checksum, result.stdout.decode())
        for expected in ('applied 0 source file(s)', 'already applied; inputs match receipt'):
            result = cli('apply', '--manifest', manifest, '--manifest-sha256', checksum)
            self.assertEqual(result.returncode, 0, result.stderr.decode())
            self.assertIn(expected, result.stdout.decode())
        self.assertEqual(cli('check').returncode, 0)
        self.assertEqual(cli('apply').returncode, 2)
        self.assertEqual(cli('preview', '--out', self.root / 'other', '--force').returncode, 2)


# Creation gate: generated functions must actually convert values in normal
# check/test, preserve relative errors and field order, and reject lossy types
# and stale output. Fixed-function management tests cannot exercise those
# contracts. Use the real CLI/compiler/VM without injection or source matching.
class JsonGeneration(Project, unittest.TestCase):
    def setUp(self):
        super().setUp()
        self.config_value['targets'][0]['json'] = {'encode': 'encodePerson', 'decode': 'decodePerson'}
        self.save_config()
        self.manager = derive.Manager(self.root, self.config)

    def normal(self, command='test', expected=0):
        result = subprocess.run([derive.BENITOITE, command, self.source], capture_output=True)
        self.assertEqual(result.returncode, expected, result.stderr.decode() + result.stdout.decode())
        return result

    def test_imports_preserve_module_doc(self):
        prefix = b'//! Keep this module explanation first.\n'
        self.source.write_bytes(prefix + self.source.read_bytes() + b'function main() -> Unit\n  ()\nend function\n')
        self.install()
        self.assertTrue(self.source.read_bytes().startswith(prefix))
        self.normal('check')
        self.normal()
        self.manager.check()

    def test_two_level_records_containers_option_renaming_and_failure_order(self):
        self.source.write_text('''import Address as Place
import Benitoite.Unofficial.Json as J
import Benitoite.Unofficial.Json.Codec as C
public record Person
  name: String
  address: Place.Address
  nickname: Option[String]
  groups: List[Map[String, Integer]]
end record
function main() -> Unit
  ()
end function
@test
function conversions() -> Unit uses Assert.Check
  bind original <- Person(name: "é😀", address: Place.Address(city: "京都"), nickname: Option.Some("n"), groups: [Map.fromList([Pair("a", 1)])])
  Assert.equal(actual: Result.andThen(r: encodePerson(original), f: decodePerson), expected: Result.Ok(original))
  bind missing <- J.Value.Object(Map.fromList([Pair("display_name", J.Value.String("x")), Pair("address", J.Value.Object(Map.fromList([Pair("city", J.Value.String("京都"))]))), Pair("groups", J.Value.Array([]))]))
  bind expected <- Person(..original, name: "x", nickname: Option.None, groups: [])
  Assert.equal(actual: decodePerson(missing), expected: Result.Ok(expected))
  bind members <- Result.unwrapOr(r: C.decodeObject(missing), fallback: Map.empty())
  Assert.equal(actual: decodePerson(J.Value.Object(Map.set(m: members, k: "nickname", value: J.Value.Null))), expected: Result.Ok(expected))
  bind extra <- Map.set(m: Map.set(m: members, k: "z", value: J.Value.Null), k: "a", value: J.Value.Null)
  Assert.equal(actual: errorPath(decodePerson(J.Value.Object(extra))), expected: [C.PathPart.Key("a")])
  bind badName <- Map.set(m: extra, k: "display_name", value: J.Value.Integer(1))
  Assert.equal(actual: errorPath(decodePerson(J.Value.Object(badName))), expected: [C.PathPart.Field("display_name")])
  bind bothBad <- Map.set(m: badName, k: "address", value: J.Value.Null)
  Assert.equal(actual: errorPath(decodePerson(J.Value.Object(bothBad))), expected: [C.PathPart.Field("display_name")])
  Assert.equal(actual: errorPath(decodePerson(J.Value.Object(Map.remove(m: members, k: "display_name")))), expected: [C.PathPart.Field("display_name")])
  bind badAddress <- Map.set(m: extra, k: "address", value: J.Value.Object(Map.fromList([Pair("city", J.Value.Null)])))
  Assert.equal(actual: errorPath(decodePerson(J.Value.Object(badAddress))), expected: [C.PathPart.Field("address"), C.PathPart.Field("city")])
  bind badGroups <- Map.set(m: members, k: "groups", value: J.Value.Array([J.Value.Object(Map.fromList([Pair("z", J.Value.Null), Pair("a", J.Value.Float(1.0))]))]))
  Assert.equal(actual: errorPath(decodePerson(J.Value.Object(badGroups))), expected: [C.PathPart.Field("groups"), C.PathPart.Index(0), C.PathPart.Key("a")])
end function
function errorPath(result: Result[Person, C.ConversionError]) -> List[C.PathPart]
  return match result with
    case Result.Error(e) -> C.ConversionError.path(e)
    case Result.Ok(_) -> []
  end match
end function
''')
        address = self.root / 'Address.bnt'
        address.write_text('public record Address\n  city: String\nend record\n')
        target = self.config_value['targets'][0]
        target['json']['keys'] = {'name': 'display_name'}
        self.config_value['targets'].append({'source': 'Address.bnt', 'type': 'Address.Address',
            'region': 'address', 'json': {'encode': 'encodeAddress', 'decode': 'decodeAddress'}})
        self.save_config()
        self.install(expected_files=2)
        self.normal('check')
        self.normal()
        self.manager.check()
        second, _ = self.preview('second')
        self.assertEqual((second.parent / 'changes.diff').read_bytes(), b'')
        # Existing encode reads a subset of fields and still type-checks after
        # a new field is added. Normal check cannot replace derive check.
        address.write_text(address.read_text().replace('  city: String', '  city: String\n  postal: Option[String]'))
        self.normal('check', expected=2)  # the old decoder now lacks the new field
        with self.assertRaisesRegex(ValueError, 'regeneration mismatch'):
            self.manager.check()

    def test_ordinary_encode_can_stay_valid_after_field_added_but_check_detects_it(self):
        self.source.write_text('''import Benitoite.Unofficial.Json
public record Person
  name: String
end record
function main() -> Unit
  ()
end function
''')
        self.install()
        # Keep a separately copied old encoder as a normal handwritten function
        # after regeneration; it still ignores the newly added field.
        text = self.source.read_text()
        start = text.index('public function encodePerson')
        end = text.index('end function', start) + len('end function')
        old_encoder = text[start:end].replace('encodePerson', 'oldEncodePerson')
        self.source.write_text(text.replace('  name: String', '  name: String\n  age: Integer') + '\n' + old_encoder + '\n')
        with self.assertRaisesRegex(ValueError, 'regeneration mismatch'):
            self.manager.check()
        path, checksum = self.preview('new-field')
        self.manager.apply(path, checksum)
        self.normal('check')
        self.manager.check()
        self.config_value['targets'][0]['json']['keys'] = {'name': 'full_name'}
        self.save_config()
        with self.assertRaisesRegex(ValueError, 'regeneration mismatch'):
            self.manager.check()
        path, checksum = self.preview('new-key')
        self.manager.apply(path, checksum)
        self.normal('check')
        self.manager.check()

    def test_custom_whole_field_missing_and_literal_json_keys(self):
        self.source.write_text('''import Benitoite.Unofficial.Json
import Benitoite.Unofficial.Json.Codec
public record Person
  number: Integer
  nested: Option[Option[String]]
end record
function main() -> Unit
  ()
end function
@test
function conversions() -> Unit uses Assert.Check
  bind original <- Person(number: 7, nested: Option.Some(Option.None))
  Assert.equal(actual: Result.andThen(r: encodePerson(original), f: decodePerson), expected: Result.Ok(original))
  Assert.equal(actual: decodePerson(Json.Value.Object(Map.empty())), expected: Result.Ok(Person(number: 7, nested: Option.Some(Option.None))))
  bind bad <- Json.Value.Object(Map.fromList([Pair("number", Json.Value.Boolean(true))]))
  Assert.equal(actual: Result.isError(decodePerson(bad)), expected: true)
end function
''')
        (self.root / 'Custom.bnt').write_text('''import Benitoite.Unofficial.Json
import Benitoite.Unofficial.Json.Codec
public function encodeNumber(n: Integer) -> Result[Json.Value, Codec.ConversionError]
  return Codec.encodeString(Integer.toString(n))
end function
public function decodeNumber(input: Json.Value) -> Result[Integer, Codec.ConversionError]
  bind text <- try Codec.decodeString(input)
  return Option.okOr(o: Integer.parse(text), error: Codec.error(expected: "decimal", found: "string", reason: "invalid number"))
end function
public function defaultNumber() -> Result[Integer, Codec.ConversionError]
  return Result.Ok(7)
end function
public function encodeNested(nested: Option[Option[String]]) -> Result[Json.Value, Codec.ConversionError]
  return match nested with
    case Option.None -> Result.Ok(Json.Value.Null)
    case Option.Some(Option.None) -> Result.Ok(Json.Value.Array([]))
    case Option.Some(Option.Some(text)) -> Result.Ok(Json.Value.Array([Json.Value.String(text)]))
  end match
end function
public function decodeNested(input: Json.Value) -> Result[Option[Option[String]], Codec.ConversionError]
  return match input with
    case Json.Value.Null -> Result.Ok(Option.None)
    case Json.Value.Array([]) -> Result.Ok(Option.Some(Option.None))
    case Json.Value.Array([Json.Value.String(text)]) -> Result.Ok(Option.Some(Option.Some(text)))
    case _ -> Result.Error(Codec.error(expected: "nested option", found: Codec.kind(input), reason: "invalid representation"))
  end match
end function
public function defaultNested() -> Result[Option[Option[String]], Codec.ConversionError]
  return Result.Ok(Option.Some(Option.None))
end function
''')
        target = self.config_value['targets'][0]
        target['json']['keys'] = {'nested': '${literal}\x00\b\f\n\r\t"\\日本語\u202e'}
        target['fields'] = {
            'number': {'encode': 'Custom.encodeNumber', 'decode': 'Custom.decodeNumber', 'decodeMissing': 'Custom.defaultNumber'},
            'nested': {'encode': 'Custom.encodeNested', 'decode': 'Custom.decodeNested', 'decodeMissing': 'Custom.defaultNested'}}
        self.save_config()
        self.install()
        self.normal('check')
        self.normal()
        self.manager.check()
        # Changing a custom signature, while retaining its body, invalidates
        # generation before any source/artifact write.
        custom = self.root / 'Custom.bnt'
        custom.write_text(custom.read_text().replace('encodeNumber(n: Integer)', 'encodeNumber(n: String)'))
        before = self.files()
        with self.assertRaisesRegex(ValueError, 'custom encode must be pure'):
            self.preview('bad-custom')
        self.assertEqual(self.files(), before)

    def test_unsupported_lossy_missing_dependency_and_wrong_custom_signatures(self):
        for annotation, explanation in [
            ('Option[Option[String]]', 'nested Option'),
            ('List[Option[Option[Integer]]]', 'nested Option'),
            ('Json.Value', 'unsupported JSON field type'),
            ('Character', 'unsupported JSON field type'),
            ('Map[Integer, String]', 'unsupported JSON field type'),
            ('Pair[String, Integer]', 'unsupported JSON field type'),
        ]:
            with self.subTest(annotation=annotation):
                self.source.write_text('import Benitoite.Unofficial.Json\npublic record Person\n  name: ' + annotation + '\nend record\n')
                before = self.files()
                with self.assertRaisesRegex(ValueError, explanation):
                    self.preview('unsupported')
                self.assertEqual(self.files(), before)
        self.source.write_text('import Address\npublic record Person\n  name: Address.Address\nend record\n')
        (self.root / 'Address.bnt').write_text('public record Address\n  city: String\nend record\n')
        with self.assertRaisesRegex(ValueError, 'requires a JSON target'):
            self.preview('missing-dependency')
        self.source.write_text('''import Benitoite.Unofficial.Json
import Benitoite.Unofficial.Json.Codec
public record Person
  name: String
end record
public function enc(value: String) -> Result[Json.Value, Codec.ConversionError]
  return Codec.encodeString(value)
end function
public function dec(value: Json.Value) -> Result[String, Codec.ConversionError]
  return Codec.decodeString(value)
end function
''')
        original = self.source.read_text()
        self.config_value['targets'][0]['fields'] = {'name': {'encode': 'People.enc', 'decode': 'People.dec'}}
        self.save_config()
        for change in [
            ('enc(value: String)', 'enc(value: Integer)'),
            ('-> Result[Json.Value, Codec.ConversionError]', '-> Result[String, Codec.ConversionError]'),
            ('-> Result[String, Codec.ConversionError]', '-> Result[String, Codec.ConversionError] uses IO.All'),
            ('enc(value: String)', 'enc[T](value: String)'),
        ]:
            with self.subTest(change=change):
                self.source.write_text(original.replace(*change))
                before = self.files()
                with self.assertRaisesRegex(ValueError, 'custom .*must be pure'):
                    self.preview('bad-signature')
                self.assertEqual(self.files(), before)


# 作成時の関門: preview/apply で生成した関数を本物の check/test から検査する。
# ライブラリ単体では生成時の接続・カスタム署名・依存の誤りを検出できない。
# コンパイラの内部の段は代用しない。
class PropertyGeneration(Project, unittest.TestCase):
    def setUp(self):
        super().setUp()
        self.config_value['targets'][0].pop('json')
        self.config_value['targets'][0]['property'] = {'generator': 'genPerson', 'shrinker': 'shrinkPerson'}
        self.save_config()
        self.manager = derive.Manager(self.root, self.config)

    def normal(self, command='test', expected=0):
        result = subprocess.run([derive.BENITOITE, command, self.source], capture_output=True)
        self.assertEqual(result.returncode, expected, result.stderr.decode() + result.stdout.decode())
        return result

    def test_field_order_state_size_custom_functions_and_one_field_shrinks(self):
        self.source.write_text('''import Benitoite.Unofficial.Test.Property as P
import Benitoite.Unofficial.IO.Random
public record Person
  first: Integer
  second: Integer
  sizeSeen: Integer
end record
public function draw() -> P.Gen[Integer]
  return P.Gen(run: lambda(generator, size) return Random.nextInteger(generator: generator, low: 0, high: 1000000) end lambda)
end function
public function sizes() -> P.Gen[Integer]
  return P.Gen(run: lambda(generator, size) return Pair(size, generator) end lambda)
end function
public function halves() -> P.Shrinker[Integer]
  return P.Shrinker(candidates: lambda(value) return if value = 0 then P.ShrinkStep.Done else P.ShrinkStep.Yield(0, lambda() return P.ShrinkStep.Yield(value div 2, lambda() return P.ShrinkStep.Done end lambda) end lambda) end if end lambda)
end function
function main() -> Unit
  ()
end function
function collect[T](steps: P.ShrinkStep[T], acc: List[T]) -> List[T]
  return match steps with
    case P.ShrinkStep.Done -> acc
    case P.ShrinkStep.Skip(next) -> collect(steps: next(), acc: acc)
    case P.ShrinkStep.Yield(value, next) -> collect(steps: next(), acc: List.append(xs: acc, x: value))
  end match
end function
@test
function generatedContracts() -> Unit uses Assert.Check
  bind initial <- Random.fromSeed(17)
  bind one <- Random.nextInteger(generator: initial, low: 0, high: 1000000)
  bind two <- Random.nextInteger(generator: Pair.second(one), low: 0, high: 1000000)
  bind next <- Random.nextInteger(generator: Pair.second(two), low: 0, high: 1000000)
  bind run <- P.Gen.run(genPerson())
  bind actual <- run(generator: initial, size: 7)
  Assert.equal(actual: Pair.first(actual), expected: Person(first: Pair.first(one), second: Pair.first(two), sizeSeen: 7))
  Assert.equal(actual: Pair.first(Random.nextInteger(generator: Pair.second(actual), low: 0, high: 1000000)), expected: Pair.first(next))
  Assert.equal(actual: Pair.first(run(generator: Random.fromSeed(17), size: 7)), expected: Pair.first(actual))
  Assert.equal(actual: Person.sizeSeen(Pair.first(run(generator: initial, size: 0))), expected: 0)
  bind shrink <- lambda(value) return collect(steps: P.Shrinker.candidates(shrinkPerson())(value), acc: []) end lambda
  Assert.equal(actual: shrink(Person(first: 8, second: 4, sizeSeen: 6)), expected: [Person(first: 0, second: 4, sizeSeen: 6), Person(first: 4, second: 4, sizeSeen: 6), Person(first: 8, second: 0, sizeSeen: 6), Person(first: 8, second: 2, sizeSeen: 6), Person(first: 8, second: 4, sizeSeen: 0), Person(first: 8, second: 4, sizeSeen: 3)])
  Assert.equal(actual: shrink(Person(first: 0, second: 0, sizeSeen: 0)), expected: [])
  bind config <- P.Config(seed: 17, trials: 3, size: 7, maxShrinks: 3, maxShrinkWork: 10000)
  bind failure <- P.check(config: config, gen: genPerson(), shrinker: shrinkPerson(), property: lambda(value) return Result.Error("fails") end lambda)
  Assert.equal(actual: failure, expected: P.check(config: config, gen: genPerson(), shrinker: shrinkPerson(), property: lambda(value) return Result.Error("fails") end lambda))
  match failure with
    case Result.Error(P.CheckFailure.Falsified(example)) ->
      Assert.equal(actual: P.Counterexample.original(example), expected: Pair.first(actual))
      Assert.equal(actual: P.Counterexample.reduced(example), expected: Person(first: 0, second: 0, sizeSeen: 0))
      Assert.equal(actual: P.Counterexample.shrinks(example), expected: 3)
    case _ -> Assert.fail("expected a generated counterexample")
  end match
end function
''')
        self.config_value['targets'][0]['fields'] = {
            name: {'gen': 'People.' + gen, 'shrink': 'People.halves'}
            for name, gen in [('first', 'draw'), ('second', 'draw'), ('sizeSeen', 'sizes')]}
        self.save_config()
        self.install()
        self.normal('check')
        self.normal()
        self.manager.check()
        second, _ = self.preview('second')
        self.assertEqual((second.parent / 'changes.diff').read_bytes(), b'')
        # 設定と構造は別々に検査し、もう一方の不一致で通る負の例にしない。
        self.config_value['targets'][0]['fields']['sizeSeen']['gen'] = 'People.draw'
        self.save_config()
        with self.assertRaisesRegex(ValueError, 'regeneration mismatch'):
            self.manager.check()
        self.config_value['targets'][0]['fields']['sizeSeen']['gen'] = 'People.sizes'
        self.save_config()
        self.manager.check()
        self.source.write_text(self.source.read_text().replace('  sizeSeen: Integer', '  sizeSeen: Integer\n  added: Boolean'))
        with self.assertRaisesRegex(ValueError, 'regeneration mismatch'):
            self.manager.check()

    def test_json_and_property_two_modules_all_basic_types_and_containers(self):
        # 保存した例そのものを生成入力にし、基本型と容器の実行結果も確かめる。
        for name in ('People.bnt', 'Address.bnt', 'derive.json', 'derive.generated.json'):
            (self.root / name).write_bytes((Path(derive.__file__).parent / 'examples' / name).read_bytes())
        self.source.write_text(self.source.read_text() + '''
@test
function generatedBasics() -> Unit uses Assert.Check
  bind run <- Property.Gen.run(genPerson())
  bind empty <- Pair.first(run(generator: Random.fromSeed(1), size: 0))
  Assert.equal(actual: Person.displayName(empty), expected: "")
  Assert.equal(actual: Address.Address.city(Person.address(empty)), expected: "")
  Assert.equal(actual: Person.scores(empty), expected: [])
  bind samples <- List.map(xs: List.range(start: 0, stop: 80), f: lambda(value) return Pair.first(run(generator: Random.fromSeed(value), size: 0)) end lambda)
  bind integers <- List.map(xs: samples, f: Person.count)
  Assert.equal(actual: List.contains(xs: integers, x: -9223372036854775808) and List.contains(xs: integers, x: 9223372036854775807), expected: true)
  bind booleans <- List.map(xs: samples, f: Person.active)
  Assert.equal(actual: List.contains(xs: booleans, x: true) and List.contains(xs: booleans, x: false), expected: true)
end function
''')
        self.manager.check()
        preview, _ = self.preview('bundled')
        self.assertEqual((preview.parent / 'changes.diff').read_bytes(), b'')
        self.normal('check')
        self.normal()
        path, _ = self.preview()
        plan = json.loads(path.read_bytes())
        self.assertEqual(plan['recordAfter']['version'], 2)
        self.assertEqual((path.parent / 'changes.diff').read_bytes(), b'')
        self.assertEqual(json.loads(self.manager.record.read_bytes())['version'], 2)

    def test_generated_shrinker_defers_later_factories_and_continuations(self):
        self.source.write_text('''import Benitoite.Unofficial.Test.Property
public record Person
  first: Integer
  later: Character
end record
public function charGen() -> Property.Gen[Character]
  return Property.constant('x')
end function
public function charShrink() -> Property.Shrinker[Character]
  bind never <- 1 div 0
  return Property.Shrinker(candidates: lambda(value) return Property.ShrinkStep.Done end lambda)
end function
function main() -> Unit
  ()
end function
@test
function deferredFactories() -> Unit uses Assert.Check
  bind shrinker <- shrinkPerson()
  bind config <- Property.Config(seed: 1, trials: 1, size: 0, maxShrinks: 1, maxShrinkWork: 2)
  bind initial <- Person(first: 8, later: 'x')
  bind result <- Property.check(config: config, gen: Property.constant(initial), shrinker: shrinker, property: lambda(value) return Result.Error("original") end lambda)
  match result with
    case Result.Error(Property.CheckFailure.Falsified(example)) ->
      Assert.equal(actual: Property.Counterexample.shrinkWork(example), expected: 2)
      Assert.equal(actual: Property.Counterexample.shrinks(example), expected: 0)
      Assert.equal(actual: Property.Counterexample.reduced(example), expected: initial)
      Assert.equal(actual: Property.Counterexample.limitReached(example), expected: true)
    case _ -> Assert.fail("expected an untried generated candidate")
  end match
end function
''')
        self.config_value['targets'][0]['fields'] = {'later': {'gen': 'People.charGen', 'shrink': 'People.charShrink'}}
        self.save_config()
        self.install()
        self.normal('check')
        self.normal()
        self.manager.check()

    def test_property_only_nested_option_private_record_and_custom_unsupported_field(self):
        self.source.write_text('''import Benitoite.Unofficial.Test.Property
record Person
  nested: Option[Option[Boolean]]
  custom: Character
end record
public function charGen() -> Property.Gen[Character]
  return Property.constant('x')
end function
public function charShrink() -> Property.Shrinker[Character]
  return Property.Shrinker(candidates: lambda(value) return Property.ShrinkStep.Done end lambda)
end function
function main() -> Unit
  ()
end function
function collect[T](steps: Property.ShrinkStep[T], acc: List[T]) -> List[T]
  return match steps with
    case Property.ShrinkStep.Done -> acc
    case Property.ShrinkStep.Skip(next) -> collect(steps: next(), acc: acc)
    case Property.ShrinkStep.Yield(value, next) -> collect(steps: next(), acc: List.append(xs: acc, x: value))
  end match
end function
@test
function propertyOnly() -> Unit uses Assert.Check
  bind run <- Property.Gen.run(genPerson())
  Assert.equal(actual: Person.custom(Pair.first(run(generator: Random.fromSeed(1), size: 0))), expected: 'x')
  bind shrink <- lambda(value) return collect(steps: Property.Shrinker.candidates(shrinkPerson())(value), acc: []) end lambda
  Assert.equal(actual: shrink(Person(nested: Option.Some(Option.Some(true)), custom: 'x')), expected: [Person(nested: Option.None, custom: 'x'), Person(nested: Option.Some(Option.None), custom: 'x'), Person(nested: Option.Some(Option.Some(false)), custom: 'x')])
end function
''')
        self.config_value['targets'][0]['fields'] = {'custom': {'gen': 'People.charGen', 'shrink': 'People.charShrink'}}
        self.save_config()
        self.install()
        self.normal('check')
        self.normal()
        self.manager.check()

    def test_unsupported_dependencies_and_custom_signatures_refuse_before_artifacts(self):
        for annotation in ('Character', 'Pair[String, Integer]', 'Map[Integer, String]'):
            with self.subTest(annotation=annotation):
                self.source.write_text('public record Person\n  name: ' + annotation + '\nend record\n')
                before = self.files()
                with self.assertRaisesRegex(ValueError, 'unsupported Property field type'):
                    self.preview('unsupported')
                self.assertEqual(self.files(), before)
        self.source.write_text('import Address\npublic record Person\n  name: Address.Address\nend record\n')
        (self.root / 'Address.bnt').write_text('public record Address\n  city: String\nend record\n')
        before = self.files()
        with self.assertRaisesRegex(ValueError, 'requires a Property target'):
            self.preview('missing')
        self.assertEqual(self.files(), before)
        original = '''import Benitoite.Unofficial.Test.Property
public record Person
  name: String
end record
public function customGen() -> Property.Gen[String]
  return Property.constant("")
end function
public function customShrink() -> Property.Shrinker[String]
  return Property.shrinkString()
end function
'''
        self.config_value['targets'][0]['fields'] = {'name': {'gen': 'People.customGen', 'shrink': 'People.customShrink'}}
        self.save_config()
        for old, new in [
            ('customGen()', 'customGen(value: Integer)'),
            ('-> Property.Gen[String]', '-> Property.Gen[Integer]'),
            ('-> Property.Shrinker[String]', '-> Property.Shrinker[Integer]'),
            ('-> Property.Gen[String]', '-> Property.Gen[String] uses IO.All'),
            ('customGen()', 'customGen[T]()'),
        ]:
            with self.subTest(change=new):
                self.source.write_text(original.replace(old, new))
                before = self.files()
                with self.assertRaisesRegex(ValueError, 'custom .*must be pure and monomorphic'):
                    self.preview('custom')
                self.assertEqual(self.files(), before)


class TraitGeneration(Project, unittest.TestCase):
    # 四問: preview/applyから実VMまで、表示・比較順・明示要求・手書き保護を守る。
    # 欄の逆順、暗黙の依存追加、既存implementの上書きで失敗する。
    # JSON/Propertyの既存テストはクラス辞書を生成しない。本番の差し込み口は不要である。
    normal = JsonGeneration.normal

    def setUp(self):
        super().setUp()
        self.config_value['targets'][0] = {
            'source': 'People.bnt', 'type': 'People.Person', 'region': 'person',
            'show': True, 'order': True}
        self.save_config()
        self.manager = derive.Manager(self.root, self.config)

    def test_review_apply_runtime_field_order_dependencies_opaque_and_replay(self):
        self.source.write_text('''import Address as Place
import Benitoite.Trait as T
import Benitoite.Assert
public record Person
  name: String
  age: Integer
  addresses: List[Place.Address]
end record
@opaque
public(package) record Secret
  value: Integer
end record
@test
function derived() -> Unit uses Assert.Check
  bind ada <- Person(name: "Ada", age: 7, addresses: [Place.Address(zip: 9)])
  Assert.equal(actual: T.Show.show(ada), expected: "Person(name: \\"Ada\\", age: 7, addresses: [Address(zip: 9)])")
  Assert.equal(actual: T.Order.compare(x: ada, y: Person(name: "Ada", age: 8, addresses: [])), expected: T.Ordering.Less)
  Assert.equal(actual: T.Order.compare(x: ada, y: Person(name: "Bob", age: 0, addresses: [])), expected: T.Ordering.Less)
  Assert.equal(actual: T.Order.compare(x: ada, y: Person(name: "Ada", age: 7, addresses: [Place.Address(zip: 8)])), expected: T.Ordering.Greater)
  Assert.equal(actual: T.Order.compare(x: ada, y: ada), expected: T.Ordering.Equal)
  Assert.equal(actual: T.Show.show(Secret(value: 42)), expected: "Secret(value: 42)")
  Assert.equal(actual: T.Order.compare(x: Secret(value: 42), y: Secret(value: 41)), expected: T.Ordering.Greater)
end function
function main() -> Unit
  ()
end function
''')
        address = self.root / 'Address.bnt'
        address.write_text('public record Address\n  zip: Integer\nend record\n')
        self.config_value['targets'] += [
            {'source': 'Address.bnt', 'type': 'Address.Address', 'region': 'address', 'show': True, 'order': True},
            {'source': 'People.bnt', 'type': 'People.Secret', 'region': 'secret', 'show': True, 'order': True}]
        self.save_config()
        before = self.source.read_bytes()
        manifest, checksum = self.preview()
        plan = derive.read_json(manifest.read_bytes())
        rows = plan['recordAfter']['targets']
        self.assertEqual(rows[0]['templates'], {'show': '1', 'order': '1'})
        self.assertTrue(rows[2]['traitTarget']['opaque'])
        self.assertTrue(any(d.get('template') == 'show' and d['target']['head']['name'] == 'Address.Address'
                            for d in rows[0]['implementationDependencies']))
        self.assertTrue(any(d.get('module') == 'Benitoite.Trait' and d['typeParams']
                            for d in rows[0]['implementationDependencies'] if 'typeParams' in d))
        self.assertEqual(self.source.read_bytes(), before)
        self.assertEqual(self.manager.apply(manifest, checksum), 2)
        self.normal('check')
        self.normal()
        self.manager.check()
        self.assertIsNone(self.manager.apply(manifest, checksum))
        again, _ = self.preview('again')
        self.assertEqual((again.parent / 'changes.diff').read_bytes(), b'')
        self.assertEqual(derive.read_json(again.read_bytes())['recordAfter'], plan['recordAfter'])
        self.assertIn(before, self.source.read_bytes())

    def test_independent_selections_and_combined_json_property(self):
        for show, order in ((True, False), (False, True), (True, True)):
            with self.subTest(show=show, order=order):
                self.source.write_text('public record Person\n  name: String\nend record\nfunction main() -> Unit\n ()\nend function\n')
                self.manager.record.unlink(missing_ok=True)
                target = self.config_value['targets'][0]
                target.update(show=show, order=order)
                target['json'] = {'encode': 'encodePerson', 'decode': 'decodePerson'}
                target['property'] = {'generator': 'genPerson', 'shrinker': 'shrinkPerson'}
                self.save_config()
                manifest, checksum = self.preview(f'selection-{show}-{order}')
                self.manager.apply(manifest, checksum)
                self.normal('check')
                self.normal()
                self.manager.check()
                record = derive.read_json(self.manager.record.read_bytes())['targets'][0]
                self.assertEqual(set(record['templates']), {'json', 'property'} | ({'show'} if show else set()) | ({'order'} if order else set()))

    def test_handwritten_dictionary_for_data_and_generic_record_is_used(self):
        self.source.write_text('''import Benitoite.Trait
import Benitoite.Assert
data Token
  Token
end data
implement Trait.Show[Token]
  function show(x: Token) -> String
    return "token"
  end function
end implement
implement Trait.Order[Token]
  function compare(x: Token, y: Token) -> Trait.Ordering
    return if 1 div 0 = 0 then Trait.Ordering.Less else Trait.Ordering.Greater end if
  end function
end implement
record Box[T]
  value: T
end record
implement[T: Trait.Show] Trait.Show[Box[T]]
  function show(x: Box[T]) -> String
    return "box:" + Trait.Show.show(Box.value(x))
  end function
end implement
implement[T: Trait.Order] Trait.Order[Box[T]]
  function compare(x: Box[T], y: Box[T]) -> Trait.Ordering
    return Trait.Order.compare(x: Box.value(x), y: Box.value(y))
  end function
end implement
record Person
  rank: Integer
  box: Box[Token]
end record
@test
function derived() -> Unit uses Assert.Check
  bind box <- Box(value: Token.Token)
  Assert.equal(actual: Trait.Show.show(Person(rank: 1, box: box)), expected: "Person(rank: 1, box: box:token)")
  Assert.equal(actual: Trait.Order.compare(x: Person(rank: 1, box: box), y: Person(rank: 2, box: box)), expected: Trait.Ordering.Less)
end function
function main() -> Unit
  ()
end function
''')
        self.save_config()
        self.install()
        self.normal('check')
        self.normal()
        self.manager.check()

    def test_refusals_preserve_source_and_report_specific_contract(self):
        for declaration, settings, explanation in (
            ('record Person\n  callback: function(value: Integer) -> Integer\nend record\n', {}, 'derive.missing_implementation'),
            ('record Person\n  next: Option[Person]\nend record\n', {}, 'derive.cyclic_dependency'),
            ('record Person[T]\n  value: T\nend record\n', {}, 'type parameters'),
            ('@opaque\npublic record Person\n  name: String\nend record\n', {'json': {'encode': 'enc', 'decode': 'dec'}}, 'derive.opaque_target'),
            ('@opaque\npublic record Person\n  name: String\nend record\n', {'property': {'generator': 'gen', 'shrinker': 'shrink'}}, 'derive.opaque_target'),
            ('record Child\n  value: Integer\nend record\nrecord Person\n  child: Child\nend record\n', {}, 'derive.missing_implementation'),
            ('import Benitoite.Trait\nrecord Person\n  name: String\nend record\n'
             'implement Trait.Show[Person]\n  function show(x: Person) -> String\n    return "handwritten"\n  end function\nend implement\n', {}, 'derive.overlapping_implementation'),
        ):
            with self.subTest(explanation=explanation):
                self.source.write_text(declaration)
                self.config_value['targets'][0] = {
                    'source': 'People.bnt', 'type': 'People.Person', 'region': 'person',
                    'show': True, 'order': True, **settings}
                self.save_config()
                before = self.files()
                with self.assertRaisesRegex(ValueError, explanation):
                    self.preview('refused')
                self.assertEqual(self.files(), before)

    def test_flags_are_strict_and_unselected_trait_is_not_loaded(self):
        target = self.config_value['targets'][0]
        for key, value in (('show', 1), ('show', 'true'), ('order', None), ('order', {})):
            with self.subTest(key=key, value=value):
                target.update(show=False, order=False)
                target[key] = value
                self.save_config()
                result = subprocess.run([derive.INVENTORY, '--root', self.root, '--config', self.config], capture_output=True)
                self.assertEqual(result.returncode, 2, result.stderr.decode())
                self.assertIn(b'expected boolean', result.stderr)
                self.assertEqual(result.stdout, b'')
        target.update(show=False, order=False)
        self.save_config()
        inv = derive.collect(self.root, self.config)
        self.assertNotIn('Benitoite.Trait.Show', inv['classes'])
        del target['show']
        del target['order']
        self.assertEqual(derive.normalized_config(inv['targets'][0]['config']), derive.normalized_config(target))

    def test_another_authenticated_region_cannot_authorize_replacing_an_implementation(self):
        body = ('implement Trait.Show[Person]\n  function show(x: Person) -> String\n'
                '    return "owned by another region"\n  end function\nend implement\n')
        self.source.write_text('import Benitoite.Trait\nrecord Person\n  value: Integer\nend record\n'
                               'record Other\n  value: Integer\nend record\n'
                               '// benitoite-derive:begin other\n' + body + '// benitoite-derive:end other\n')
        self.config_value['targets'].append({
            'source': 'People.bnt', 'type': 'People.Other', 'region': 'other', 'show': True})
        self.save_config()
        self.manager.record.write_text(json.dumps({
            'version': 2, 'generatorVersion': derive.GENERATOR_VERSION, 'targets': [{
                'source': 'People.bnt', 'type': 'People.Other', 'region': 'other',
                'templates': {'show': '1'}, 'outputSha256': hashlib.sha256(body.encode()).hexdigest()}]}))
        before = self.files()
        with self.assertRaisesRegex(ValueError, 'derive.overlapping_implementation.*People.bnt'):
            self.preview('other-region')
        self.assertEqual(self.files(), before)


if __name__ == '__main__':
    unittest.main()
