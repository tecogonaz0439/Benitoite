"""基準との差分・中心命題・既存言明・固定入力を照合する。git の書込みはしない。"""
from pathlib import Path
import hashlib
import json
import re
import subprocess

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
BASE = '335caabf3b08b98ae7f8c3c7311f1c116ae28072'
CHANGED = {'formal/Benitoite/Interval/EvalClosed.lean', 'formal/Benitoite/Interval/Examples.lean'}
DOCS = {'docs/design/01-spec/01-12-core-calculus.md',
        'docs/design/07-quality/07-04-formal-semantics.md'}

def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)

def sha(data):
    return hashlib.sha256(data).hexdigest()

def before(path):
    return git('show', BASE + ':' + path)

def norm(source):
    return re.sub(r'\s+', ' ', source).strip()

def declarations(data):
    source = re.sub(r'/\-.*?\-/', '', data.decode(), flags=re.S)
    source = re.sub(r'(?m)^\s*--[^\n]*$', '', source)
    pattern = (r'(?m)^(?:@\[[^\n]*\]\s+)?(?:(?:private|protected|noncomputable)\s+)?'
               r'(?:inductive|structure|def|theorem|lemma|abbrev|example|end|namespace|mutual)\b[^\n]*')
    starts = list(re.finditer(pattern, source))
    result = {}
    for i, start in enumerate(starts):
        named = re.match(r'(?:@\[[^\n]*\]\s+)?(?:(?:private|protected|noncomputable)\s+)?'
                         r'(inductive|structure|def|theorem|lemma|abbrev)\s+(\S+)', start.group())
        if named:
            end = starts[i + 1].start() if i + 1 < len(starts) else len(source)
            result[named.group(2)] = (named.group(1), source[start.start():end].strip())
    return result

unchanged = []
all_declarations = {}
for path in git('ls-files', 'formal').decode().splitlines():
    old = before(path)
    new = (ROOT / path).read_bytes()
    if path not in CHANGED:
        assert old == new, path
        unchanged.append(path)
    if path.endswith('.lean'):
        all_declarations[path] = (declarations(old), declarations(new))

preserved, auxiliary = [], []
for path, (old, new) in all_declarations.items():
    if path.endswith('/Examples.lean'):
        continue
    for name, (kind, body) in old.items():
        if kind not in ('theorem', 'lemma'):
            continue
        assert name in new, (path, name)
        same = norm(body.split(':=', 1)[0]) == norm(new[name][1].split(':=', 1)[0])
        if name == 'evalClosed_call' and path.endswith('/EvalClosed.lean'):
            assert not same
            assert '(unrecognized : rangeCallBinding env' in new[name][1]
            auxiliary.append({'file': path, 'name': name, 'change':
                '認定されない call の評価不能に限定。中心命題・入口の健全性の変更ではない。'})
        else:
            assert same, (path, name)
            preserved.append([path, name])

central = {}
for name in ('NormalSoundness', 'WarningSoundness'):
    old, new = all_declarations['formal/Benitoite/Interval/Eval.lean']
    assert old[name] == new[name]
    central[name] = sha(new[name][1].encode())

references = []
reference_names = {
    'EvalPartial', 'EvalBlock', 'EvalArms', 'EvalWidthArms', 'EvalResultArms', 'EvalArguments',
    'Unmodeled', 'UnknownAt', 'Unsupported', 'ConcreteValue', 'ConcreteValue.type', 'EvalStandard',
    'StandardRule.finish', 'AbstractSlot', 'topSlot', 'SlotModels', 'Models', 'targetOperationAt',
    'concreteRule', 'Reached', 'WarningLocated', 'RangeState', 'RangeState.Models',
    'analyzeBase', 'analyzeBaseExpr', 'analyzeBaseBlock', 'analyze', 'expr', 'independent',
    'analyzeBody', 'analyzeWhole', 'evalClosed', 'sameType', 'typeOf', 'blockType',
}
for path, (old, new) in all_declarations.items():
    if '/Interval/' not in path or path.endswith('/Examples.lean'):
        continue
    for name, (_, body) in old.items():
        if name not in reference_names:
            continue
        current = new[name][1]
        references.append({'file': path, 'name': name, 'changed': norm(body) != norm(current),
                           'before_sha256': sha(norm(body).encode()),
                           'after_sha256': sha(norm(current).encode())})
assert {r['file'] for r in references if r['changed']} == {'formal/Benitoite/Interval/EvalClosed.lean'}
assert {r['name'] for r in references if r['changed']} == {'sameType', 'typeOf', 'blockType', 'expr'}

# 例は追加部分を除けば元のファイルと同じである。
path = 'formal/Benitoite/Interval/Examples.lean'
new = (ROOT / path).read_text()
a = new.index('-- 閉じた評価器の入口で、実際')
b = new.index('end Benitoite.Interval.Examples.RangeSurface', a)
assert (new[:a] + new[b:]).encode() == before(path)
assert len(re.findall(r'(?m)^example\s*:', new[a:b])) == 6

fixed = {}
for path in git('ls-files', 'crates/benitoite/testdata/interval-budget', 'formal/lakefile.toml').decode().splitlines():
    data = (ROOT / path).read_bytes()
    assert data == before(path), path
    fixed[path] = sha(data)
assert len(fixed) == 8
assert git('diff', BASE, '--', 'crates') == b''

changed_tracked = set(git('diff', '--name-only', BASE).decode().splitlines())
assert changed_tracked == CHANGED | DOCS, changed_tracked
added = '\n'.join(line[1:] for line in git('diff', BASE, '--', 'formal').decode().splitlines()
                  if line.startswith('+') and not line.startswith('+++'))
clean = re.sub(r'/\-.*?\-/', '', added, flags=re.S)
clean = re.sub(r'(?m)--.*$', '', clean)
for forbidden in [r'\bsorry\b', r'\badmit\b', r'\baxiom\b', r'\bnative_decide\b',
                  r'\bimplemented_by\b', r'\bextern\b', r'\bunsafe\b', r'\bpartial\s+def\b']:
    assert not re.search(forbidden, clean), forbidden
subprocess.run(['git', 'diff', '--check'], cwd=ROOT, check=True)
(OUT / 'definition-diff.patch').write_bytes(git('diff', BASE, '--', 'formal'))
record = {'base': BASE, 'head': git('rev-parse', 'HEAD').decode().strip(),
          'unchanged_formal_files': len(unchanged), 'central': central,
          'preserved_theorem_statements': len(preserved), 'auxiliary_statement_changes': auxiliary,
          'reference_definitions': references, 'fixed_inputs': fixed,
          'existing_examples_preserved': True, 'new_examples': 6,
          'changed_inputs': {path: sha((ROOT / path).read_bytes()) for path in sorted(CHANGED | DOCS)},
          'added_lines_no_forbidden_proofs': True, 'diff_check': 0}
(OUT / 'contract-check.json').write_text(json.dumps(record, ensure_ascii=False, indent=2) + '\n')
print(json.dumps({k: v for k, v in record.items() if k not in ('reference_definitions', 'fixed_inputs')},
                 ensure_ascii=False, indent=2))
