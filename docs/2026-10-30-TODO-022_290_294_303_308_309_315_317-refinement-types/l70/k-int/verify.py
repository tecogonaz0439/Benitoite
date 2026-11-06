"""表層の追随の変更範囲、署名、既定 import、最終検査、公理と記録を照合する。

開始時の個別ハッシュと根ごとの集約を使い、Git を呼ばない。監査対象は個別ハッシュから再構成する。
使い方: python3 verify.py --tmp <tmp>（build.log と axioms.log が必要）。
"""
import argparse
import collections
import hashlib
import json
from pathlib import Path
import re
from run_check import inputs, fingerprint

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
SURFACE = 'formal/Benitoite/Release/Refinement/Surface/'
DESIGN = ['docs/design/01-spec/01-12-core-calculus.md',
          'docs/design/07-quality/07-04-formal-semantics.md']
ALLOWED = {'propext', 'Quot.sound', 'Classical.choice'}
B_WORK = '676e870224ca5c2e37cb76d66f6139e4729d585a'
# 属性と宣言修飾子を許す。署名の終端は下の走査で括弧の外だけを見る。
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


def aggregate(data):
    """相対パスとファイルの SHA-256 の対をパス順の JSON にして SHA-256 を取る。"""
    return dict(count=len(data), sha256=fingerprint(data))


def inventory():
    # 元の目録と同じ対象集合。追加・削除も集約の件数とハッシュに反映する。
    paths = [p for p in (ROOT / 'formal').rglob('*.lean') if '.lake' not in p.parts]
    paths += list((ROOT / 'docs/design').rglob('*.md'))
    paths += [p for p in HERE.parent.parent.rglob('*')
              if p.is_file() and not p.is_relative_to(HERE)]
    return {str(p.relative_to(ROOT)): digest(p) for p in paths}


def rest_groups(data):
    return {root: aggregate({p: h for p, h in data.items() if p.startswith(root)})
            for root in ['formal/', 'docs/design/', str(HERE.parent.parent.relative_to(ROOT)) + '/']}


def digest(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def module(path):
    return path[7:-5].replace('/', '.')


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--tmp', type=Path)
parser.add_argument('--self-test', action='store_true')
parser.add_argument('--write-audit-modules', action='store_true')
args = parser.parse_args()
selftest_count = signature_selftest()
if args.self_test:
    print(json.dumps(dict(signature_selftest=selftest_count)))
    raise SystemExit(0)
assert args.tmp is not None or args.write_audit_modules, '--tmp が必要'
baseline_files = sorted(HERE.glob('baseline-[0-9]*.json'))
assert sum(p.stat().st_size for p in HERE.glob('baseline-*.json')) <= 10_000
assert len(baseline_files) == 1
record = json.loads(baseline_files[0].read_text())
info = json.loads((HERE / 'baseline-info.json').read_text())
assert info['b_work'] == B_WORK and info['sha256'] == digest(baseline_files[0])
assert info['bytes'] == baseline_files[0].stat().st_size and info['rest'] == record['rest']
baseline = record['files']
assert len(baseline) == 27
assert len([p for p in baseline if p.startswith(SURFACE)]) == 25
assert all(p in DESIGN or (p.startswith(SURFACE) and p.endswith('.lean')) for p in baseline)
current = inventory()
assert baseline.keys() <= current.keys(), '開始時のファイルの削除'
# 再開前に作られたレビューは開始時目録にない。読み取り専用の追加入力として照合する。
readonly = record['resume_readonly']
assert readonly == {p: current[p] for p in readonly}
rest = {p: h for p, h in current.items() if p not in baseline and p not in readonly
        and not (p.startswith(SURFACE) and p.endswith('.lean'))}
assert rest_groups(rest) == record['rest'], '許可した範囲外の追加・削除・変更'
changed = sorted(p for p, h in baseline.items() if current[p] != h)
new = sorted(p for p in current if p.startswith(SURFACE) and p.endswith('.lean') and p not in baseline)
modules = sorted(module(p) for p in changed + new if p.endswith('.lean'))
visited = set()


def visit(name):
    if name in visited:
        return
    visited.add(name)
    p = ROOT / 'formal' / (name.replace('.', '/') + '.lean')
    if p.exists():
        for child in re.findall(r'^import (\S+)', p.read_text(), re.M):
            visit(child)


visit('Benitoite')
assert set(modules) <= visited
assert all(module(p) in visited for p in new)
if args.write_audit_modules:
    (HERE / 'audit-modules.json').write_text(json.dumps(modules, indent=1) + '\n')
    print(json.dumps(dict(audit_modules=len(modules), added_modules=new)))
    raise SystemExit(0)
assert modules == json.loads((HERE / 'audit-modules.json').read_text())
# 群 D の既存の全定理の署名を検査する（別名展開の定理も含む）。
signatures = json.loads((HERE / 'theorem-signatures.json').read_text())
assert set(signatures) == {p for p in baseline if p.endswith('.lean')}
assert sum(map(len, signatures.values())) == 266
for p, expected in signatures.items():
    actual = signature_hashes((ROOT / p).read_text())
    assert all(actual.get(n) == h for n, h in expected.items()), p

# 禁止した構文や設定の追加がない。既存の二つの局所設定も同じ値を保つ。
for p in changed:
    if p.endswith('.lean'):
        source = (ROOT / p).read_text()
        assert not re.search(r'\bsorry\b|^\s*axiom\b|#eval|#check|#print|maxRecDepth|\bL\d\d\.\d', source, re.M), p
        options = re.findall(r'^.*maxHeartbeats.*$', source, re.M)
        allowed = ['set_option maxHeartbeats 400000 in'] if p.endswith(('/Property1.lean', '/ScopedProof.lean')) else []
        assert options == allowed, (p, options)

# 両検査が同じ入力を検査し、検査後も入力が変わっていない。
check_summaries = {}
for kind in ['build', 'axioms']:
    summary = json.loads((HERE / (kind + '-summary.json')).read_text())
    log = args.tmp / (kind + '.log')
    assert summary['exit_code'] == 0 and summary['sha256'] == digest(log)
    assert summary['bytes'] == log.stat().st_size
    assert summary['fingerprint'] == fingerprint(inputs())
    assert re.search(r'^rc=0$', log.read_text(), re.M)
    check_summaries[kind] = summary
build = (args.tmp / 'build.log').read_text()
assert 'error:' not in build
jobs = int(re.search(r'Build completed successfully \((\d+) jobs\)', build)[1])
assert not [m for m in modules if re.search(r'warning: ' + re.escape(m.replace('.', '/') + '.lean:'), build)]
audit = (args.tmp / 'axioms.log').read_text()
assert not re.search(r'error:|sorryAx|AUDIT_(MISSING|AXIOM|FIXED_POINT_LIMIT|REQUIRED_MISSING|MODULE_MISSING)', audit)
targets = re.findall(r'^AUDIT_TARGET (.+)$', audit, re.M)
assert len(targets) == len(set(targets)) == int(re.search(r'^AUDIT_COUNT (\d+)$', audit, re.M)[1])
axioms = re.findall(r"^'(.*?)' (?:does not depend on any axioms|depends on axioms: \[([^]]*)\])", audit, re.M | re.S)
assert collections.Counter(n for n, _ in axioms) == collections.Counter(targets)
sets = collections.Counter(tuple(sorted(a.strip() for a in ax.split(',') if a.strip())) for _, ax in axioms)
assert all(set(s) <= ALLOWED for s in sets)
per_module = {m: int(c) for m, c in re.findall(r'^AUDIT_MODULE (\S+) (\d+)$', audit, re.M)}
assert sorted(per_module) == modules and sum(per_module.values()) == len(targets)
decls = re.findall(r'^AUDIT_DECL (\S+) (\S+) (\d+) (.+)$', audit, re.M)
assert len(decls) == len(targets) and set(n for _, _, _, n in decls) == set(targets)
required = json.loads((HERE / 'required-names.json').read_text())
assert set(required) <= set(targets)
# 宣言名の完全一覧は生出力にのみ置き、件数とハッシュを保存する。
names = ('\n'.join(sorted(targets)) + '\n').encode()
summary = dict(b_work=B_WORK, baseline_count=len(baseline), baseline_rest=record['rest'],
               signature_selftest=selftest_count, changed=changed, added_modules=new,
               modules=per_module, theorem_signatures=sum(map(len, signatures.values())),
               build_jobs=jobs, declarations=len(targets), private=sum(n.startswith('_private.') for n in targets),
               rounds=int(re.search(r'^AUDIT_ROUNDS (\d+)$', audit, re.M)[1]), required=len(required),
               axioms={','.join(s) or '(none)': c for s, c in sorted(sets.items())},
               declaration_names=dict(bytes=len(names), sha256=hashlib.sha256(names).hexdigest()),
               source_hashes={p: digest(ROOT / p) for p in changed},
               fingerprint=fingerprint(inputs()))
(HERE / 'verification.json').write_text(json.dumps(summary, ensure_ascii=False, indent=1) + '\n')
size = 0
for p in HERE.iterdir():
    if p.is_file():
        assert p.stat().st_size <= 100_000, p.name
        size += p.stat().st_size
        text = p.read_text()
        assert '/Us' + 'ers/' not in text and '/priv' + 'ate/tmp' not in text, p.name
        assert not re.search(r'\]\([^)]*docs/todo', text), p.name
assert size < 3_000_000, size
print(json.dumps(dict(changed=len(changed), modules=len(modules), jobs=jobs, declarations=len(targets),
                      private=summary['private'], theorem_signatures=summary['theorem_signatures'],
                      records_bytes=size, axioms=summary['axioms']), ensure_ascii=False))
