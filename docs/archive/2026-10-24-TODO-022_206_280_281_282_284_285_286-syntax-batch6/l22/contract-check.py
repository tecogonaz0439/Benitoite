"""保護対象と言明の差分を基準から読み取り、位置の一般化以外の変更を拒否する。"""
from pathlib import Path
import hashlib
import json
import re
import subprocess

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
BASE = 'be57d4e92d7a48fb74dc33a4d3c3867b60207aeb'

def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)

def sha(data):
    return hashlib.sha256(data).hexdigest()

prefix = r'^[ \t]*(?:@\[[^\n]*?\][ \t]*)?(?:(?:private|protected|noncomputable)[ \t]+)*'

def declaration(source, kind, name):
    start = re.search(prefix + kind + r' ' + re.escape(name) + r'(?=\s|\{|\(|:)', source, re.M)
    assert start, (kind, name)
    tail = source[start.start():]
    if kind not in ('theorem', 'lemma'):
        end = re.search(r'\n\n(?=/--|/-!|--|(?:def|theorem|inductive|structure|namespace|end|example|mutual)\b)', tail)
        assert end, name
        return tail[:end.start()]
    depth, comment, quoted, index = 0, 0, False, 0
    while index < len(tail):
        if comment:
            if tail.startswith('/-', index): comment += 1; index += 2
            elif tail.startswith('-/', index): comment -= 1; index += 2
            else: index += 1
            continue
        if quoted:
            if tail[index] == '\\': index += 2; continue
            if tail[index] == '"': quoted = False
            index += 1
            continue
        if tail.startswith('/-', index): comment = 1; index += 2; continue
        if tail.startswith('--', index): index = tail.index('\n', index); continue
        char = tail[index]
        if char == '"': quoted = True
        elif char in '([{⟨': depth += 1
        elif char in ')]}⟩': depth -= 1
        elif depth == 0 and tail.startswith(':=', index): return tail[:index].rstrip()
        index += 1
    raise AssertionError(name)

assert git('rev-parse', 'HEAD').decode().strip() == BASE
assert git('branch', '--show-current').decode().strip() == 'mod012/L22'
paths = git('ls-files', 'formal', 'crates/benitoite/testdata/interval-budget').decode().splitlines()
changed, unchanged, statements = {}, {}, {}
count = 0
for path in paths:
    before = git('show', BASE + ':' + path)
    after = (ROOT / path).read_bytes()
    if before == after:
        unchanged[path] = sha(after)
    else:
        assert path == 'formal/Benitoite.lean' or path.startswith('formal/Benitoite/Interval/'), path
        changed[path] = {'before': sha(before), 'after': sha(after)}
    if not path.endswith('.lean'): continue
    old, new = before.decode(), after.decode()
    if before == after:
        count += len(re.findall(prefix + r'(theorem|lemma) (\S+?)(?=\s|\{|\(|:)', old, re.M))
        continue
    for kind, name in re.findall(prefix + r'(theorem|lemma) (\S+?)(?=\s|\{|\(|:)', old, re.M):
        a, b = declaration(old, kind, name), declaration(new, kind, name)
        if a == b: count += 1
        else: statements[path + ':' + name] = {'before': a, 'after': b}

position = {'analyzeExpr_warning_located', 'analyzeBody_warning_located'}
for key, value in statements.items():
    if key.rsplit(':', 1)[1] not in position:
        assert value['before'].replace('targetOperationAt', 'arithmeticOperationAt') == value['after'], key
assert {key.rsplit(':', 1)[1] for key in statements if key.rsplit(':', 1)[1].startswith('analyze')} == position

protected_files = ['Eval.lean', 'Environment.lean', 'Range.lean', 'RangeState.lean',
    'Analyze.lean', 'Arithmetic.lean', 'Flow.lean', 'EvalClosed.lean',
    'BudgetAnalyze.lean', 'Budget.lean', 'BudgetScan.lean', 'BudgetRange.lean',
    'BudgetRangeBorrow.lean', 'RangeBorrowed.lean', 'BudgetEnvironment.lean',
    'BudgetChildren.lean', 'BudgetWhole.lean', 'BudgetDiscover.lean',
    'BudgetIndependent.lean', 'BudgetIndependentRun.lean']
for name in protected_files:
    assert 'formal/Benitoite/Interval/' + name in unchanged, name
for path in paths:
    if path.startswith('crates/') or (path.startswith('formal/') and
        path != 'formal/Benitoite.lean' and not path.startswith('formal/Benitoite/Interval/')):
        assert path in unchanged, path

# 中心二命題・評価・Models は上でファイル全体を照合した。
# 構文的な到達可能性と位置の内部不変条件も、関数名の置換後に同じ定義である。
protected = {
 'SyntacticReach.lean': ['concreteRule', 'InSyntacticReach', 'WarningsInSyntacticReach'],
 'BudgetLocated.lean': ['LocatedIn', 'Located', 'RootWarning'],
}
for name, names in protected.items():
    path = 'formal/Benitoite/Interval/' + name
    old = git('show', BASE + ':' + path).decode()
    new = (ROOT / path).read_text()
    for declaration_name in names:
        a, b = declaration(old, 'def', declaration_name), declaration(new, 'def', declaration_name)
        assert a.replace('targetOperationAt', 'arithmeticOperationAt') == b, declaration_name
path = 'formal/Benitoite/Interval/Sound.lean'
old = declaration(git('show', BASE + ':' + path).decode(), 'def', 'targetOperationAt')
new = declaration((ROOT / path).read_text(), 'def', 'arithmeticOperationAt')
assert old.replace('targetOperationAt', 'arithmeticOperationAt') == new
assert not git('diff', BASE, '--', 'crates', 'fuzz', 'scripts', 'formal/lakefile.toml', 'formal/lean-toolchain')
for path in (ROOT / 'formal/Benitoite/Interval').glob('*.lean'):
    code = re.sub(r'/\-.*?\-/', '', path.read_text(), flags=re.S)
    code = re.sub(r'--[^\n]*', '', code)
    assert not re.search(r'\b(sorry|native_decide|implemented_by|extern|unsafe)\b|^\s*axiom\b|\bby\s+admit\b|^\s*admit\s*$', code, re.M), path.name
subprocess.run(['git', 'diff', '--check'], cwd=ROOT, check=True)
record = dict(base=BASE, head=BASE, unchanged_existing_theorem_statements=count,
    changed_position_statements=statements, changed_tracked_formal_sha256=changed,
    unchanged_tracked_sha256=unchanged,
    central_definitions_eval_models_unchanged=True,
    public_normal_causal_and_syntactic_statements_unchanged=True,
    syntactic_reach_and_internal_locations_definitionally_unchanged=True,
    arithmetic_recognition_definitionally_unchanged=True,
    no_new_axioms_or_proof_holes=True, fixed_tables_unchanged=True,
    analysis_budget_and_closed_evaluator_unchanged=True, git_diff_check=0)
(OUT / 'contract-check.json').write_text(json.dumps(record, ensure_ascii=False, indent=2) + '\n')
print(json.dumps({k: record[k] for k in ['base', 'unchanged_existing_theorem_statements',
    'central_definitions_eval_models_unchanged', 'fixed_tables_unchanged']}, ensure_ascii=False))
print('位置の補助言明の差分:', len(statements))
