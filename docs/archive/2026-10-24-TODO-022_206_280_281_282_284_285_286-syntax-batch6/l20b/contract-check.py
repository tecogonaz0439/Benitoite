"""今回の基準・言明・参照定義・固定入力を照合する作業用の点検。"""
from pathlib import Path
import hashlib
import json
import re
import subprocess

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
BASE = '6eccf6254d7cc387a44b45df3722482852b72d37'
CHANGED_FORMAL = {
    'formal/Benitoite/Interval/' + name + '.lean'
    for name in ('Eval', 'Range', 'Sound', 'BudgetNormal', 'BudgetSound', 'Examples')
}
DOCS = {'docs/design/01-spec/01-12-core-calculus.md',
        'docs/design/07-quality/07-04-formal-semantics.md'}

def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)

def sha(data):
    return hashlib.sha256(data).hexdigest()

def before(path):
    return git('show', f'{BASE}:{path}')

def declarations(data):
    source = re.sub(r'/\-.*?\-/', '', data.decode(), flags=re.S)
    source = re.sub(r'(?m)^\s*--[^\n]*$', '', source)
    starts = list(re.finditer(
        r'(?m)^(?:@\[[^\n]*\]\s+)?(?:(?:private|protected|noncomputable)\s+)?'
        r'(?:inductive|structure|def|theorem|lemma|abbrev|example|end|namespace|mutual)\b[^\n]*', source))
    found = {}
    for i, start in enumerate(starts):
        named = re.match(r'(?:@\[[^\n]*\]\s+)?(?:(?:private|protected|noncomputable)\s+)?'
                         r'(inductive|structure|def|theorem|lemma|abbrev)\s+(\S+)', start.group())
        if named:
            end = starts[i + 1].start() if i + 1 < len(starts) else len(source)
            body = source[start.start():end].strip()
            found[named.group(2)] = (named.group(1), body)
    return found

def normal(text):
    return re.sub(r'\s+', ' ', text).strip()

old_all, current_all, unchanged = {}, {}, []
for path in git('ls-files', 'formal').decode().splitlines():
    data, old = (ROOT / path).read_bytes(), before(path)
    if path not in CHANGED_FORMAL:
        assert data == old, path
        unchanged.append(path)
    if path.endswith('.lean'):
        for name, declaration in declarations(old).items():
            old_all[(path, name)] = declaration
        for name, declaration in declarations(data).items():
            current_all[(path, name)] = declaration

def current_named(path, name):
    value = current_all.get((path, name))
    if value is not None:
        return path, value
    matches = [(p, v) for (p, n), v in current_all.items() if n == name]
    assert len(matches) == 1, (path, name, [p for p, _ in matches])
    return matches[0]

preserved_statements, moved = [], []
for (path, name), (kind, body) in old_all.items():
    if path not in CHANGED_FORMAL or path.endswith('/Examples.lean') or kind not in ('theorem', 'lemma'):
        continue
    new_path, (new_kind, new_body) = current_named(path, name)
    assert normal(body.split(':=', 1)[0]) == normal(new_body.split(':=', 1)[0]), (path, name)
    preserved_statements.append([new_path, name])
    if new_path != path:
        moved.append([name, path, new_path])

central = {}
for name in ('NormalSoundness', 'WarningSoundness'):
    path = 'formal/Benitoite/Interval/Eval.lean'
    old, new = old_all[(path, name)][1], current_all[(path, name)][1]
    assert old == new, name
    central[name] = sha(new.encode())

reference_names = {
    'ConcreteValue', 'ConcreteValue.type', 'EvalStandard', 'StandardRule', 'StandardRule.finish',
    'EvalPartial', 'EvalBlock', 'EvalArms', 'EvalWidthArms', 'Unmodeled', 'UnknownAt', 'Unsupported',
    'AbstractSlot', 'topSlot', 'SlotModels', 'Models', 'targetOperationAt', 'concreteRule',
    'Reached', 'WarningLocated', 'NormalTyped', 'RangeNames.IsOk', 'RangeNames.OkPayload',
    'RangeOrigin', 'RangeOrigin.ResultModels', 'RangeOrigin.CheckedModels', 'RangeState',
    'RangeState.Models', 'rangeCallOrigin', 'rangeValueCall', 'rangeBindOk', 'rangeSaveResult',
    'analyzeBaseExpr', 'analyzeBaseBlock', 'analyzeBaseArms', 'analyzeBaseKindArms', 'analyzeBase',
}
references = []
for (path, name), (_, body) in old_all.items():
    if '/Interval/' not in path or name not in reference_names:
        continue
    new_path, (_, new_body) = current_named(path, name)
    references.append({'name': name, 'before_file': path, 'after_file': new_path,
                       'changed': normal(body) != normal(new_body),
                       'before_sha256': sha(normal(body).encode()),
                       'after_sha256': sha(normal(new_body).encode())})
assert {r['name'] for r in references if r['changed']} == {'EvalPartial', 'Unmodeled', 'UnknownAt'}

# 区間の解析と閉じた評価器の実行定義を変更していないことも別に確かめる。
for (path, name), (kind, body) in old_all.items():
    if path in CHANGED_FORMAL and not path.endswith('/Examples.lean') and kind in ('def', 'structure', 'abbrev'):
        _, (_, new_body) = current_named(path, name)
        if name not in ('Unmodeled', 'UnknownAt'):
            assert normal(body) == normal(new_body), (path, name)

fixed = {}
for path in git('ls-files', 'crates/benitoite/testdata/interval-budget', 'formal/lakefile.toml').decode().splitlines():
    data = (ROOT / path).read_bytes()
    assert data == before(path), path
    fixed[path] = sha(data)
assert git('diff', BASE, '--', 'crates') == b''
examples = 'formal/Benitoite/Interval/Examples.lean'
assert (ROOT / examples).read_bytes().replace(b'import Benitoite.Interval.Range\n', b'', 1).startswith(before(examples))

changed = git('diff', '--name-only', BASE).decode().splitlines()
assert set(changed) == CHANGED_FORMAL | DOCS, changed
patch = git('diff', BASE, '--', 'formal').decode()
assert not re.search(r'(?m)^\+(?!\+).*\b(?:sorry|admit|axiom|native_decide|implemented_by|extern)\b', patch)
(OUT / 'definition-diff.patch').write_text(patch)
axioms = (OUT / 'axioms.log').read_text()
deps = re.findall(r'depends on axioms: \[([^]]*)\]', axioms, re.S)
without = len(re.findall(r'does not depend on any axioms', axioms))
expected = len(re.findall(r'^#print axioms ', (OUT / 'axioms.lean').read_text(), re.M))
assert len(deps) + without == expected, (len(deps), without, expected)
for names in deps:
    assert {n.strip() for n in names.split(',') if n.strip()} <= {'propext', 'Classical.choice', 'Quot.sound'}, names
subprocess.run(['git', 'diff', '--check'], cwd=ROOT, check=True)
record = {
    'base': BASE, 'head': git('rev-parse', 'HEAD').decode().strip(),
    'changed_tracked': changed, 'unchanged_formal_files': len(unchanged),
    'preserved_theorem_statements_in_changed_files': len(preserved_statements),
    'preserved_statement_list': preserved_statements, 'moved_theorems': moved,
    'central_definition_sha256': central, 'reference_definitions': references,
    'axiom_dependencies_checked': expected, 'no_added_sorry_axiom_admit': True,
    'fixed_file_sha256': fixed,
    'final_inputs_sha256': {p: sha((ROOT / p).read_bytes()) for p in changed},
    'diff_numstat': git('diff', '--numstat', BASE).decode().splitlines(),
}
(OUT / 'contract-check.json').write_text(json.dumps(record, ensure_ascii=False, indent=2) + '\n')
print(json.dumps({k: record[k] for k in ('base', 'head', 'unchanged_formal_files',
    'preserved_theorem_statements_in_changed_files', 'axiom_dependencies_checked', 'no_added_sorry_axiom_admit')}, ensure_ascii=False))
