"""再開7の表層の拡張を、開始時の指紋・266署名・全宣言の監査と照合する。

Git は呼ばない。新規モジュールの既定 import への到達、保護範囲、追加の全宣言、
private と生成宣言を含む公理依存を照合する。生出力は --tmp に置く。
"""
import argparse
import collections
import hashlib
import json
from pathlib import Path
import re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
ALLOWED_AXIOMS = {'propext', 'Quot.sound', 'Classical.choice'}

PATTERN = re.compile(
    r'(?m)^[ \t]*(?:(?:@\[[\s\S]*?\]|private|protected|noncomputable)\s+)*'
    r'theorem\s+([^\s{(:]+)')


def code_only(source):
    """コメントと文字列を空白にし、位置と改行を保つ。入れ子のコメントも読む。"""
    chars = list(source)
    i = 0
    while i < len(source):
        start = i
        if source.startswith('--', i):
            end = source.find('\n', i)
            i = len(source) if end < 0 else end
        elif source.startswith('/-', i):
            depth = 1
            i += 2
            while i < len(source) and depth:
                if source.startswith('/-', i):
                    depth += 1
                    i += 2
                elif source.startswith('-/', i):
                    depth -= 1
                    i += 2
                else:
                    i += 1
            assert depth == 0, '閉じていないコメント'
        elif source[i] == '"':
            i += 1
            while i < len(source):
                if source[i] == '\\':
                    i += 2
                elif source[i] == '"':
                    i += 1
                    break
                else:
                    i += 1
        else:
            i += 1
            continue
        chars[start:i] = ['\n' if c == '\n' else ' ' for c in source[start:i]]
    return ''.join(chars)


def theorem_headers(source):
    code = code_only(source)
    headers = {}
    for match in PATTERN.finditer(code):
        name = match[1]
        stack = []
        i = match.end()
        while i < len(code):
            c = code[i]
            if not stack and (code.startswith(':=', i) or
                              (c == '|' and not code[code.rfind('\n', 0, i) + 1:i].strip())):
                break
            if c in '([{⟨':
                stack.append(c)
            elif c in ')]}⟩':
                assert stack and stack.pop() == dict(zip(')]}⟩', '([{⟨'))[c], name
            i += 1
        assert i < len(code) and not stack, ('署名の終端がない', name)
        assert name not in headers, ('名前の重複', name)
        headers[name] = ' '.join((name + source[match.end():i]).split())
    return headers


def signature_hashes(source):
    return {n: hashlib.sha256(h.encode()).hexdigest() for n, h in theorem_headers(source).items()}


def signature_selftest():
    # 名前付き引数・既定値の := と、等式形式の | を別々に検査する。
    source = r'''
/- theorem ignored : False := by /- nested -/ trivial -/
@[simp] theorem attributed (x : Nat) : x = x := by rfl
@[simp]
@[local simp] private theorem hidden (x : Nat := 1) : x = x := by rfl
protected theorem Namespace.kept : True := by trivial
private protected theorem Namespace.both : True := by trivial
@[simp] protected theorem Namespace.decorated : True := by trivial
theorem named : (id (α := Nat) 0) = 0 := by rfl
theorem equations : (n : Nat) → n = n
  | n => rfl
theorem quoted : ("theorem fake : False := |" = ":=") := by rfl
'''
    expected = {
        'attributed': 'attributed (x : Nat) : x = x',
        'hidden': 'hidden (x : Nat := 1) : x = x',
        'Namespace.kept': 'Namespace.kept : True',
        'Namespace.both': 'Namespace.both : True',
        'Namespace.decorated': 'Namespace.decorated : True',
        'named': 'named : (id (α := Nat) 0) = 0',
        'equations': 'equations : (n : Nat) → n = n',
        'quoted': 'quoted : ("theorem fake : False := |" = ":=")',
    }
    assert theorem_headers(source) == expected
    assert signature_hashes(source)['named'] != signature_hashes(
        source.replace('(α := Nat) 0) = 0', '(α := Nat) 0) = 1'))['named']
    assert signature_hashes(source) == signature_hashes(source.replace(':= by rfl', ':= by exact rfl'))
    return len(expected)



def digest(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def fingerprint(data):
    return hashlib.sha256(json.dumps(data, sort_keys=True).encode()).hexdigest()


def aggregate(data):
    return dict(count=len(data), sha256=fingerprint(data))


def module(path):
    return path[7:-5].replace('/', '.')


def default_imports():
    visited = set()
    pending = ['Benitoite']
    while pending:
        name = pending.pop()
        if name in visited:
            continue
        visited.add(name)
        path = ROOT / 'formal' / (name.replace('.', '/') + '.lean')
        source = path.read_text()
        pending += re.findall(r'^import (Benitoite(?:\.[\w]+)*)$', source, re.M)
    return visited


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--tmp', type=Path)
parser.add_argument('--self-test', action='store_true')
parser.add_argument('--write-modules', action='store_true')
args = parser.parse_args()
assert signature_selftest() == 8
if args.self_test:
    print('signature_selftest=8')
    raise SystemExit(0)
base = json.loads((HERE / 'resume7-baseline.json').read_text())
assert base['b_work'] == 'e70794188e24de95b5bb424f9d75090f77d1c703'
allowed = set(base['files'])
new_paths = set(json.loads((HERE / 'resume7-new-paths.json').read_text()))
all_sources = [p for p in (ROOT / 'formal').rglob('*.lean') if '.lake' not in p.parts]
all_design = list((ROOT / 'docs/design').rglob('*.md'))
data = {str(p.relative_to(ROOT)): digest(p) for p in all_sources + all_design}
for prefix in ('formal', 'docs/design'):
    rest = {p: h for p, h in data.items()
            if p.startswith(prefix + '/') and p not in allowed | new_paths}
    assert aggregate(rest) == base['protected'][prefix], ('保護範囲の変更', prefix)
change = HERE.parent.parent
rest = {str(p.relative_to(ROOT)): digest(p) for p in change.rglob('*')
        if p.is_file() and not p.is_relative_to(HERE)}
assert aggregate(rest) == base['protected']['change'], '他群の記録が変わった'
settings = {f'formal/{n}': digest(ROOT / 'formal' / n)
            for n in ('lakefile.toml', 'lake-manifest.json', 'lean-toolchain')}
assert aggregate(settings) == base['protected']['settings']
changed = sorted(p for p, h in base['files'].items() if data[p] != h)
assert set(changed) <= allowed, changed
assert all((ROOT / p).is_file() for p in new_paths)
witness_modules = ['Benitoite.Release.Refinement.Surface.RangeAdmissibilityExample',
                   'Benitoite.Release.Refinement.Surface.RangeSignatureExample']
modules = sorted({module(p) for p in changed + sorted(new_paths)
                  if p.startswith('formal/') and p.endswith('.lean')} | set(witness_modules))
if args.write_modules:
    (HERE / 'audit-modules.json').write_text(json.dumps(modules, indent=1) + '\n')
assert modules == json.loads((HERE / 'audit-modules.json').read_text())
reachable = default_imports()
assert set(modules) <= reachable
assert {module(p) for p in base['files'] if p.endswith('.lean')} <= reachable

# 固定した台帳と開始時の全署名を比較し、許可済みの範囲一般化だけを別表で照合する。
ledger = json.loads((HERE.parent / 'k-int/theorem-signatures.json').read_text())
assert sum(map(len, ledger.values())) == 266
baseline = json.loads((HERE / 'resume7-signatures.json').read_text())
assert sum(map(len, baseline.values())) == 308
current = {p: signature_hashes((ROOT / p).read_text()) for p in baseline}
differences = json.loads((HERE / 'resume7-signature-differences.json').read_text())
actual_differences = {}
for p, rows in baseline.items():
    for name, hashed in rows.items():
        assert name in current[p], ('既存の定理の削除', p, name)
        if current[p][name] != hashed:
            actual_differences.setdefault(p, {})[name] = dict(before=hashed, after=current[p][name])
assert actual_differences == differences, '記録した署名差と実物が一致しない'
for p, rows in ledger.items():
    for name, hashed in rows.items():
        assert baseline[p][name] == hashed, ('台帳と開始版の不一致', p, name)
all_theorems = {p: signature_hashes((ROOT / p).read_text()) for p in sorted(set(changed) | new_paths)
                if p.endswith('.lean')}
new_theorems = {p: {n: h for n, h in rows.items() if n not in baseline.get(p, {})}
                for p, rows in all_theorems.items()}
new_theorems = {p: rows for p, rows in new_theorems.items() if rows}
limits = json.loads((HERE / 'resume7-limits.json').read_text())
for p in set(changed) | new_paths:
    if not p.endswith('.lean'):
        continue
    source = (ROOT / p).read_text()
    assert not re.search(r'\bsorry\b|\baxiom\b|\badmit\b|#eval|#print|#check', code_only(source)), p
    if p in new_paths:
        options = re.findall(r'(?m)^set_option (?:maxHeartbeats|maxRecDepth) \d+(?: in)?$', code_only(source))
        assert options == limits.get(p, {}).get('options', []), ('証明用設定', p, options)
    if p in new_paths:
        assert not re.search(r'\bL\d\d\.\d|\bJ\d\d-\d|\bU0\d\b', source), p
# 全表層の規則を同じ順序で保持し、実装した場合が落ちていないことを数える。
def constructors(path):
    code = code_only(path.read_text())
    declarations = list(re.finditer(r'\binductive\s+(\w+)\s', code))
    result = {}
    for i, match in enumerate(declarations):
        end = declarations[i + 1].start() if i + 1 < len(declarations) else len(code)
        result[match[1]] = re.findall(r'(?m)^\s*\|\s*(\w+)\s*(?:\{|:)', code[match.end():end])
    return result
rules = constructors(ROOT / 'formal/Benitoite/Release/Refinement/Surface/Rules.lean')
opened = constructors(ROOT / 'formal/Benitoite/Release/Refinement/Surface/OpenSurface.lean')
rule_counts = dict(HasTypeQ=72, HasTypesQ=2, HasEachQ=2, HasFixedQ=3,
                   HasArmsQ=3, HasClausesQ=2, HasBlockQ=11)
for name, count in rule_counts.items():
    assert rules[name] == opened[name] and len(opened[name]) == count, ('表層規則', name)
assert opened['BodyTy'] == ['done', 'param']
lookup_rows = re.findall(r'(?m)^private theorem lookup_(p\d+) : primitive ',
                        (ROOT / 'formal/Benitoite/Release/Refinement/StandardModelPrimitiveLookup.lean').read_text())
assert len(lookup_rows) == len(set(lookup_rows)) == 377
for p in HERE.iterdir():
    if p.is_file():
        assert p.stat().st_size <= 100_000, p
        if p.suffix in ('.json', '.lean', '.md', '.py'):
            text = p.read_text()
            assert '/Us' + 'ers/' not in text and '/priv' + 'ate/tmp' not in text, p
            assert not re.search(r'\]\([^)]*docs/todo', text), p
assert sum(p.stat().st_size for p in HERE.rglob('*') if p.is_file()) < 3_000_000
if args.write_modules:
    print(json.dumps(dict(modules=modules, statements=308, ledger=266,
                          added_theorems=sum(map(len, new_theorems.values())))))
    raise SystemExit(0)
assert args.tmp is not None
aborted = json.loads((HERE / 'resume7-aborted-start.json').read_text())
aborted_log = args.tmp / 'aborted-start.log'
assert aborted['bytes'] == aborted_log.stat().st_size == 0
assert aborted['sha256'] == digest(aborted_log)
summaries = {kind: json.loads((HERE / f'resume7-{kind}-summary.json').read_text())
             for kind in ('build', 'axioms')}
for kind, summary in summaries.items():
    path = args.tmp / f'{kind}.log'
    assert summary['exit_code'] == 0 and summary['bytes'] == path.stat().st_size
    assert summary['sha256'] == digest(path)
assert summaries['build']['fingerprint'] == summaries['axioms']['fingerprint']
live_inputs = {str(p.relative_to(ROOT)): digest(p) for p in all_sources}
live_inputs.update(settings)
assert fingerprint(live_inputs) == summaries['build']['fingerprint'], '検査後に本番の入力が変わった'
text = (args.tmp / 'build.log').read_text()
assert re.search(r'^rc=0$', text, re.M)
assert 'error:' not in text
jobs = int(re.search(r'Build completed successfully \((\d+) jobs\)', text)[1])
assert not any(re.search(rf'warning: {re.escape(m.replace(".", "/"))}\.lean:', text)
               for m in modules)
audit = (args.tmp / 'axioms.log').read_text()
assert re.search(r'^rc=0$', audit, re.M)
assert not re.search(r'error:|sorryAx|AUDIT_(MISSING|AXIOM|FIXED_POINT_LIMIT|REQUIRED_MISSING|MODULE_MISSING)', audit)
targets = re.findall(r'^AUDIT_TARGET (.+)$', audit, re.M)
assert len(targets) == len(set(targets)) == int(re.search(r'^AUDIT_COUNT (\d+)$', audit, re.M)[1])
axioms = re.findall(r"^'(.*?)' (?:does not depend on any axioms|depends on axioms: \[([^]]*)\])", audit, re.M | re.S)
assert collections.Counter(n for n, _ in axioms) == collections.Counter(targets)
sets = collections.Counter(tuple(sorted(x.strip() for x in a.split(',') if x.strip())) for _, a in axioms)
assert all(set(s) <= ALLOWED_AXIOMS for s in sets)
per_module = dict((m, int(c)) for m, c in re.findall(r'^AUDIT_MODULE (\S+) (\d+)$', audit, re.M))
assert sorted(per_module) == modules and sum(per_module.values()) == len(targets)
decls = re.findall(r'^AUDIT_DECL (\S+) (\S+) (\d+) (.+)$', audit, re.M)
assert len(decls) == len(targets)
required = json.loads((HERE / 'required-names.json').read_text())
assert set(required) <= set(targets)
names = ('\n'.join(sorted(targets)) + '\n').encode()
summary = dict(b_work=base['b_work'], changed=changed, new=sorted(new_paths),
               modules=modules, default_imports=True, ledger=266, existing_statements=308,
               rule_counts=rule_counts, body_rules=2, primitive_rows=len(lookup_rows),
               changed_statements=sum(map(len, differences.values())),
               added_theorems=sum(map(len, new_theorems.values())),
               added_signatures_sha256=fingerprint(new_theorems), jobs=jobs, declarations=len(targets),
               private=sum(n.startswith('_private.') for n in targets),
               names_bytes=len(names), names_sha256=hashlib.sha256(names).hexdigest(),
               axiom_sets={','.join(k) or '(none)': v for k, v in sorted(sets.items())},
               per_module=per_module,
               sources={p: digest(ROOT / p) for p in sorted(allowed | new_paths)},
               build=summaries['build'], axioms=summaries['axioms'])
(HERE / 'resume7-verification.json').write_text(json.dumps(summary, ensure_ascii=False, indent=1) + '\n')
print(json.dumps({k: v for k, v in summary.items() if k not in ('build', 'axioms', 'sources', 'new_signatures')},
                 ensure_ascii=False, indent=1))
