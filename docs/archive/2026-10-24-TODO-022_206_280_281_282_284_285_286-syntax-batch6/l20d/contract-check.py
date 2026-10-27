"""L20d の保存対象を基準と照合する。git と固定表は読み取りだけにする。"""
from pathlib import Path
import hashlib
import json
import re
import subprocess

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
BASE = '8a59b630f9fdef8d1e1595f7999c6242d167d739'

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
    end = re.search(r'\n\n(?=/--|/-!|(?:def|theorem|inductive|structure|namespace|end)\b)', tail)
    assert end, name
    return tail[:end.start()]

paths = git('ls-files', 'formal', 'crates/benitoite/testdata/interval-budget').decode().splitlines()
unchanged, changed, statements, internal_changes = {}, {}, {}, {}
unchanged_theorems = 0
for path in paths:
    current = (ROOT / path).read_bytes()
    old = git('show', BASE + ':' + path)
    if old == current:
        unchanged[path] = digest(current)
    else:
        changed[path] = {'before': digest(old), 'after': digest(current)}
        assert path.startswith('formal/Benitoite/Interval/'), path
    if path.endswith('.lean'):
        before, after = old.decode(), current.decode()
        for kind, name in re.findall(theorem_prefix + r'(theorem|lemma) (\S+?)(?=\s|\{|\(|:)', before, re.M):
            if old == current:
                unchanged_theorems += 1
                continue
            target = after
            if not re.search(theorem_prefix + kind + ' ' + re.escape(name) + r'(?=\s|\{|\(|:)', target, re.M):
                matches = [file.read_text() for file in (ROOT / 'formal/Benitoite/Interval').glob('*.lean')
                    if re.search(theorem_prefix + kind + ' ' + re.escape(name) + r'(?=\s|\{|\(|:)', file.read_text(), re.M)]
                assert len(matches) == 1, (path, name)
                target = matches[0]
            left, right = declaration(before, kind, name), declaration(target, kind, name)
            if left != right:
                internal_changes[path + ':' + name] = {'before': left, 'after': right}
                assert path.startswith('formal/Benitoite/Interval/'), (path, name)
                assert not name.startswith('analyze'), (path, name)
            else:
                unchanged_theorems += 1
        for name in re.findall(r'^theorem (analyze\w*)\b', before, re.M):
            left = declaration(before, 'theorem', name)
            right = declaration(after, 'theorem', name)
            assert left == right, (path, name, left, right)
            statements[path + ':' + name] = digest(left.encode())
        if path.endswith('/Environment.lean'):
            for name in ('Models', 'SlotModels', 'topSlot'):
                left, right = declaration(before, 'def', name), declaration(after, 'def', name)
                assert left == right, name
                statements[path + ':' + name] = digest(left.encode())

for path, definitions in {
    'formal/Benitoite/Interval/Eval.lean': ('NormalSoundness', 'WarningSoundness'),
    'formal/Benitoite/Interval/BudgetIndependent.lean': ('IndependentResult.Sound',),
}.items():
    before = git('show', BASE + ':' + path).decode()
    after = (ROOT / path).read_text()
    for name in definitions:
        left, right = declaration(before, 'def', name), declaration(after, 'def', name)
        assert left == right, name
        statements[path + ':' + name] = digest(left.encode())

for path in paths:
    if (path.startswith('crates/') or not path.startswith('formal/Benitoite/Interval/') or
            path.endswith(('/Eval.lean', '/Budget.lean', '/BudgetWhole.lean'))):
        assert path in unchanged, path

new_files = {}
for path in sorted((ROOT / 'formal/Benitoite/Interval').glob('*.lean')):
    relative = str(path.relative_to(ROOT))
    if relative not in paths:
        new_files[relative] = digest(path.read_bytes())
    code = re.sub(r'/\-.*?\-/', '', path.read_text(), flags=re.S)
    code = re.sub(r'--[^\n]*', '', code)
    assert not re.search(r'\b(sorry|native_decide|implemented_by|extern|unsafe)\b|^\s*axiom\b|\bby\s+admit\b|^\s*admit\s*$', code, re.M), relative

subprocess.run(['git', 'diff', '--check'], cwd=ROOT, check=True)
record = {'base': BASE, 'head': git('rev-parse', 'HEAD').decode().strip(),
          'protected_statements_sha256': statements,
          'unchanged_files_sha256': unchanged, 'changed_files_sha256': changed, 'new_files_sha256': new_files,
          'no_new_axioms_or_proof_holes_in_interval': True,
          'central_definitions_entire_eval_file_unchanged': True,
          'public_analyze_theorem_statements_byte_equal': True,
          'models_slotModels_topSlot_byte_equal': True,
          'outside_interval_and_fixed_tables_unchanged': True,
          'git_diff_check': 0}
(OUT / 'internal-statement-diff.json').write_text(json.dumps(internal_changes, ensure_ascii=False, indent=2) + '\n')
record['unchanged_existing_theorems'] = unchanged_theorems
record['changed_internal_theorems'] = list(internal_changes)
(OUT / 'contract-check.json').write_text(json.dumps(record, ensure_ascii=False, indent=2) + '\n')
print(json.dumps({'base': BASE, 'protected_statements': len(statements),
                  'unchanged_existing_theorems': unchanged_theorems,
                  'changed_internal_theorems': len(internal_changes),
                  'unchanged_files': len(unchanged), 'changed_files': len(changed), 'new_files': len(new_files),
                  'git_diff_check': 0}, ensure_ascii=False, indent=2))
