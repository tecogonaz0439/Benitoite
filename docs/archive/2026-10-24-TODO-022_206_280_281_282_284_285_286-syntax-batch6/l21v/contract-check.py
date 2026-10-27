"""L21V の保存対象を基準と照合する。git と固定表は読み取りだけにする。"""
from pathlib import Path
import hashlib
import json
import re
import subprocess

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
BASE = 'a7944afaa0d93f8beaebce37f45e242d2c8dadbb'

def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)

def digest(data):
    return hashlib.sha256(data).hexdigest()

theorem_prefix = r'^[ \t]*(?:@\[[^\n]*?\][ \t]*)?(?:(?:private|protected|noncomputable)[ \t]+)*'

def declaration(source, kind, name):
    prefix = theorem_prefix if kind in ('theorem', 'lemma') else '^'
    start = re.search(prefix + kind + r' ' + re.escape(name) + r'(?=\s|\{|\(|:)', source, re.M)
    assert start, (kind, name)
    tail = source[start.start():]
    if kind in ('theorem', 'lemma'):
        # 引数の既定の証明「(start : ... := by rfl)」を本文の開始と誤認しない。
        depth, comment, quoted, index = 0, 0, False, 0
        while index < len(tail):
            if comment:
                if tail.startswith('/-', index):
                    comment += 1; index += 2
                elif tail.startswith('-/', index):
                    comment -= 1; index += 2
                else:
                    index += 1
                continue
            if quoted:
                if tail[index] == '\\': index += 2; continue
                if tail[index] == '"': quoted = False
                index += 1; continue
            if tail.startswith('/-', index): comment = 1; index += 2; continue
            if tail.startswith('--', index):
                index = tail.index('\n', index); continue
            char = tail[index]
            if char == '"': quoted = True
            elif char in '([{⟨': depth += 1
            elif char in ')]}⟩': depth -= 1
            elif depth == 0 and tail.startswith(':=', index):
                return tail[:index].rstrip()
            index += 1
        raise AssertionError(name)
    end = re.search(r'\n\n(?=/--|/-!|--|(?:def|theorem|inductive|structure|namespace|end|example|mutual)\b)', tail)
    assert end, name
    return tail[:end.start()]

paths = git('ls-files', 'formal', 'crates/benitoite/testdata/interval-budget').decode().splitlines()
changed, unchanged, statements, internal = {}, {}, {}, {}
count = 0
for path in paths:
    current = (ROOT / path).read_bytes()
    before = git('show', BASE + ':' + path)
    if before == current:
        unchanged[path] = digest(current)
    else:
        assert path.startswith('formal/Benitoite/Interval/'), path
        changed[path] = {'before': digest(before), 'after': digest(current)}
    if not path.endswith('.lean'):
        continue
    left, right = before.decode(), current.decode()
    if before == current:
        count += len(re.findall(theorem_prefix + r'(theorem|lemma) (\S+?)(?=\s|\{|\(|:)', left, re.M))
        continue
    for kind, name in re.findall(theorem_prefix + r'(theorem|lemma) (\S+?)(?=\s|\{|\(|:)', left, re.M):
        a, b = declaration(left, kind, name), declaration(right, kind, name)
        if a == b:
            count += 1
        else:
            internal[path + ':' + name] = {'before': a, 'after': b}
            assert not name.startswith('analyze'), (path, name)
        if name.startswith('analyze'):
            statements[path + ':' + name] = digest(a.encode())

protected = {
 'Eval.lean': [('def', x) for x in ['NormalSoundness','WarningSoundness','Unmodeled','UnknownAt','NormalTyped','rangeCallBinding']] + [('inductive', x) for x in ['EvalPartial','ConcreteValue','EvalStandard','StandardRule','RangeNames.IsOk','RangeNames.OkPayload','RangeNames.ResultView']] + [('structure',x) for x in ['RangeNames','RangeRecord']] + [('def',x) for x in ['ConcreteValue.type','rangeCheck','rangePayload','rangeStoredValue']],
 'Environment.lean': [('inductive','AbstractSlot')] + [('def', x) for x in ['SlotModels','Models','topSlot']],
 'SyntacticReach.lean': [('def','concreteRule')],
 'Sound.lean': [('def','targetOperationAt')],
 'RangeState.lean': [('def','RangeOrigin.ResultModels'),('def','RangeState.Models'),('def','RangeOrigin.CheckedModels'),('def','RangeLocalFact.Models')],
 'BudgetIndependent.lean': [('def','IndependentResult.Sound')],
}
for filename, declarations in protected.items():
    path = 'formal/Benitoite/Interval/' + filename
    before = git('show', BASE + ':' + path).decode()
    after = (ROOT / path).read_text()
    for kind, name in declarations:
        a, b = declaration(before,kind,name), declaration(after,kind,name)
        assert a == b, (path, name)
        statements[path + ':' + name] = digest(a.encode())

# 独立の補助定理一件だけの言明を変更し、公開の解析入口は上で拒否する。
condition_changes = list(internal)
expected_internal = {'range_check_small_model'}
assert {name.rsplit(':', 1)[1] for name in internal} == expected_internal
for path in paths:
    if path.startswith('crates/') or not path.startswith('formal/Benitoite/Interval/'):
        assert path in unchanged, path
for path in (ROOT / 'formal/Benitoite/Interval').glob('*.lean'):
    code = re.sub(r'/\-.*?\-/', '', path.read_text(), flags=re.S)
    code = re.sub(r'--[^\n]*','',code)
    assert not re.search(r'\b(sorry|native_decide|implemented_by|extern|unsafe)\b|^\s*axiom\b|\bby\s+admit\b|^\s*admit\s*$',code,re.M), path.name
subprocess.run(['git','diff','--check'],cwd=ROOT,check=True)
record = {'base': BASE, 'head': git('rev-parse','HEAD').decode().strip(),
 'protected_declarations_sha256': statements, 'unchanged_existing_theorems': count,
 'changed_internal_theorems': list(internal), 'condition_changes': condition_changes,
 'changed_files_sha256': changed, 'unchanged_files_sha256': unchanged,
 'no_new_axioms_or_proof_holes': True, 'outside_interval_and_fixed_tables_unchanged': True,
 'central_definitions_and_public_analyze_statements_byte_equal': True,
 'models_slotModels_byte_equal': True, 'git_diff_check': 0}
(OUT/'contract-check.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n')
(OUT/'internal-statement-diff.json').write_text(json.dumps(internal,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({key: record[key] for key in ['base','head','unchanged_existing_theorems','condition_changes']},ensure_ascii=False,indent=2))
print('保護した宣言:',len(statements),'三欄の対応を戻した内部言明:',len(internal))

def without_comments(source):
    return re.sub(r'--[^\n]*', '', re.sub(r'/\-.*?\-/', '', source, flags=re.S))
for name in ['Eval.lean','RangeState.lean']:
    path = 'formal/Benitoite/Interval/' + name
    assert without_comments(git('show', BASE + ':' + path).decode()) == without_comments((ROOT/path).read_text()), name
path = 'formal/Benitoite/Interval/Range.lean'
a, b = git('show', BASE + ':' + path).decode(), (ROOT/path).read_text()
def omit_changed_parts(source):
    source = re.sub(r'theorem range_check_small_model .*?(?=\n/-- 逆転は所属)', '', source, flags=re.S)
    source = re.sub(r'example \(names : RangeNames\) \(key : OperationKey\)(?: \(different : names.ok ≠ names.err\))? :\n    let origin : RangeOrigin := ⟨names, key, ⟨0, by decide⟩, ⟨10, by decide⟩⟩\n    let payload := rangePayload.*?(?=\n-- 境界の early return)', '', source, flags=re.S)
    return source
assert a != b
assert omit_changed_parts(a) == omit_changed_parts(b), '補助定理と合成例以外の差分'
assert not git('diff', BASE, '--', 'crates', 'fuzz', 'scripts', 'formal/lakefile.toml', 'formal/lean-toolchain')
print('Eval・RangeState はコメントだけ。Range は独立の補助定理一件と合成例だけを変更。')
