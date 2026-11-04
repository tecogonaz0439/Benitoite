"""後処理の有限表・原Sourceの順序と凍結済みLeanを局所照合する。"""
from pathlib import Path
from datetime import datetime, timezone
import hashlib, json, re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
MODULES = ['StandardRecordFields', 'StandardDecodeComparison', 'StandardDecodeBodies']

def digest(data):
    return {'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()}

def read(relative):
    return (ROOT / relative).read_text()

def function(source, signature):
    first = source.index(signature)
    return source[first:source.index('end function', first) + len('end function')]

def main():
    source_specs = {
        'crates/benitoite/src/prelude/stdlib/Json/Codec.bnt': [(6, 20), (34, 85), (120, 140)],
        'crates/benitoite/src/prelude/stdlib/Json.bnt': [(1, 35)],
        'tools/derive/examples/People.bnt': [(11, 18), (83, 95)],
        'tools/derive/examples/Address.bnt': [(30, 38), (68, 71)],
        'tools/derive/derive.py': [(895, 905), (930, 970)],
        'crates/benitoite/src/builtins/table.rs': [(235, 249), (974, 996), (1032, 1048)],
        'crates/benitoite/src/base/parameter_names.rs': [(1, 25)],
    }
    evidence = {}
    for relative, spans in source_specs.items():
        raw = (ROOT / relative).read_bytes()
        lines = raw.decode().splitlines(keepends=True)
        evidence[relative] = {'input': digest(raw), 'excerpts': [
            {'first': lo, 'last': hi, 'text': ''.join(lines[lo-1:hi])} for lo, hi in spans]}
    codec = read('crates/benitoite/src/prelude/stdlib/Json/Codec.bnt')
    person = read('tools/derive/examples/People.bnt')
    decoder = function(person, 'public function decodePerson(')
    markers = ['Codec.decodeObject(value)'] + [f'bind deriveField{i} <- try Codec.decodeField' for i in range(6)] + ['Codec.rejectExtra(', 'return Result.Ok(Person(']
    positions = [decoder.index(m) for m in markers]
    assert positions == sorted(positions)
    fields = ['displayName: String', 'address: Address.Address', 'nickname: Option[String]',
              'scores: List[Map[String, Float]]', 'active: Boolean', 'count: Integer']
    assert [person.index(x) for x in fields] == sorted(person.index(x) for x in fields)
    assert 'city: String' in read('tools/derive/examples/Address.bnt')
    decl = codec[codec.index('public record ConversionError'):codec.index('end record')]
    err_fields = ['path: List[PathPart]', 'expected: String', 'found: String', 'reason: String']
    assert [decl.index(x) for x in err_fields] == sorted(decl.index(x) for x in err_fields)
    prepend = function(codec, 'public function prepend(')
    assert 'ConversionError(..error, path: List.prepend(xs: ConversionError.path(error), x: part))' in prepend
    decode_field = function(codec, 'public function decodeField[')
    assert decode_field.count('decode(value)') == 1 and decode_field.count('decodeMissing()') == 1
    assert 'PathPart.Field(key)' in decode_field
    extra = function(codec, 'function rejectExtraFrom(')
    assert 'PathPart.Key(key)' in extra and 'Map.keys(members)' in codec
    assert not re.search(r'function\s+decode\[?\(', read('crates/benitoite/src/prelude/stdlib/Json.bnt'))
    generator = read('tools/derive/derive.py')
    generator = generator[generator.index('def generate_json('):generator.index('def generate_property(')]
    assert generator.index("for index, field in enumerate(target['fields'])") < generator.index('decodes.append(')
    assert generator.index("+ ''.join(decodes)") < generator.index('rejectExtra(members:')
    table = read('crates/benitoite/src/builtins/table.rs')
    assert '"%Integer.lessOrEqual"' in table
    assert 'vec![parameter_names::LEFT, parameter_names::RIGHT]' in table
    names = read('crates/benitoite/src/base/parameter_names.rs')
    assert 'LEFT: &str = "left"' in names and 'RIGHT: &str = "right"' in names
    assert 'OperatorKind::Lt | OperatorKind::Le | OperatorKind::Gt | OperatorKind::Ge' in table
    old = json.loads((HERE / 'inputs.json').read_text())
    manifest = HERE / 'r1-formal-baseline.txt'
    assert digest(manifest.read_bytes()) == old['manifest']
    retained = 0
    for line in manifest.read_text().splitlines():
        sha, relative = line.split('  ', 1)
        raw = (ROOT / relative).read_bytes()
        if relative == 'formal/Benitoite.lean':
            raw = raw[:old['files'][relative]['bytes']]
        assert hashlib.sha256(raw).hexdigest() == sha, relative
        retained += 1
    previous = json.loads((HERE / 'inputs-r1-u24.json').read_text())
    previous_modules = json.loads((HERE / 'modules-r1.json').read_text())
    root_before = previous['files']['formal/Benitoite.lean']
    assert digest((ROOT / 'formal/Benitoite.lean').read_bytes()[:root_before['bytes']]) == root_before
    for relative, expected in previous['files'].items():
        if relative.startswith('formal/Benitoite/Release/Refinement/'):
            assert digest((ROOT / relative).read_bytes()) == expected, relative
    current = list((ROOT / 'formal').rglob('*.lean'))
    current = [p for p in current if '.lake' not in p.parts]
    assert len(current) == previous['lean_sources'] + len(MODULES)
    imports = read('formal/Benitoite.lean')
    for name in MODULES:
        assert name in previous_modules
        assert f'import Benitoite.Release.Refinement.{name}' in imports
        relative = f'formal/Benitoite/Release/Refinement/{name}.lean'
        code = read(relative)
        assert not re.search(r'\b(sorry|axiom|admit|native_decide|implemented_by)\b|#eval', code)
        assert not re.search(r'\b(?:L\d{2}(?:\.\d+)?|O\d{3}|TODO-\d{3})\b|/Users/', code)
        olean = ROOT / f'formal/.lake/build/lib/lean/Benitoite/Release/Refinement/{name}.olean'
        assert olean.exists() and olean.stat().st_mtime >= (ROOT / relative).stat().st_mtime
        evidence[relative] = {'input': digest((ROOT / relative).read_bytes())}
    for relative in ['docs/design/01-spec/01-12-core-calculus.md', 'docs/design/07-quality/07-04-formal-semantics.md']:
        for name in MODULES:
            assert name in read(relative)
    ids = re.findall(r'^\| (O\d{3}) \|', (HERE / 'obligations.md').read_text(), re.M)
    assert len(ids) == len(set(ids)) == 64
    for p in HERE.iterdir():
        if p.is_file():
            assert p.stat().st_size <= 100000, p.name
            content = p.read_text()
            assert str(ROOT) not in content, p.name
            if p.suffix == '.md':
                for link in re.findall(r'\]\(([^)]+)\)', content):
                    target = link.split('#')[0]
                    if '://' not in target and target:
                        assert (p.parent / target).exists(), (p.name, target)
    result = {'observed_utc': datetime.now(timezone.utc).isoformat(), 'exit': 0,
              'scope': '局所のSource対応と不変入力。全公理監査・独立レビューは含まない',
              'frozen_baseline_sources': retained, 'current_lean_sources': len(current),
              'previous_sources': previous['lean_sources'], 'retained_previous_sources': previous['lean_sources'], 'modules': MODULES,
              'source_evidence': evidence}
    (HERE / 'source-evidence-u25.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({k: v for k, v in result.items() if k != 'source_evidence'}, ensure_ascii=False))

if __name__ == '__main__':
    main()
