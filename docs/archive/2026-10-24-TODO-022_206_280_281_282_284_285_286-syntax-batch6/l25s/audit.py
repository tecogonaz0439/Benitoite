"""基準との宣言・主定理・公理・固定表の一致と、承認された差分を点検する。"""
from pathlib import Path
import hashlib
import json
import re
import subprocess
import run

ROOT, OUT, BASE = run.ROOT, run.OUT, run.BASE


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, text=True)


def old(path):
    return git('show', BASE + ':' + path)


def declaration(source, name):
    start = re.search(r'(?m)^(?:private )?(?:def|inductive|structure|theorem) '
                      + re.escape(name) + r'(?=\s|\{|\()', source)
    assert start, name
    end = re.search(r'(?m)^(?:/--|/\*!|-- |end\b|(?:private )?'
                    r'(?:def|inductive|structure|theorem|example|instance)\b)', source[start.end():])
    return source[start.start():start.end() + end.start() if end else len(source)].strip()


def headers(source):
    result = {}
    for start in re.finditer(r'(?m)^(?:@\[[^\n]*?\] )?(theorem|lemma) ([\w.\x27]+)\b', source):
        tail, depth = source[start.start():], 0
        for index, char in enumerate(tail):
            if char in '({[':
                depth += 1
            elif char in ')}]':
                depth -= 1
            if depth == 0 and tail[index:index + 2] == ':=':
                result[start.group(2)] = tail[:index].strip()
                break
    return result


protected = {}
for filename, names in {
    'Eval': ['NormalSoundness', 'WarningSoundness', 'ConcreteValue', 'ConcreteValue.type',
             'EvalInput', 'Reached', 'Unmodeled', 'UnknownAt', 'EvalPartial', 'EvalStandard'],
    'Environment': ['Models', 'SlotModels', 'LocalsModels', 'AbstractSlot', 'AbstractEnv'],
    'RangeState': ['RangeLocalFact', 'RangeLocalFact.Models', 'RangeState.Models'],
    'Sound': ['arithmeticOperationAt', 'WarningLocated'],
    'SyntacticReach': ['concreteRule', 'syntacticReachChildren'],
}.items():
    path = f'formal/Benitoite/Interval/{filename}.lean'
    before, after = old(path), (ROOT / path).read_text()
    for name in names:
        left, right = declaration(before, name), declaration(after, name)
        assert left == right, (path, name)
        protected[name] = dict(path=path, sha256=hashlib.sha256(right.encode()).hexdigest())

paths = git('ls-files', 'formal').splitlines()
changed_headers, main_statements, unchanged = [], [], {}
for path in paths:
    if not path.endswith('.lean'):
        continue
    before, after = old(path), (ROOT / path).read_text()
    left, right = headers(before), headers(after)
    for name in left.keys() | right.keys():
        if left.get(name) != right.get(name):
            changed_headers.append(dict(path=path, name=name,
                                        before=left.get(name), after=right.get(name)))
        if re.match(r'^(analyze(?:Base|Expr|Body)?_(?:normal_sound|warning_sound|warning_located|'
                    r'warning_syntactic_reach|warning_arithmetic|warning_call_reach|independent_sound|'
                    r'unrecognized_call_warnings)|analyzeBody_(?:normal|property)|'
                    r'evalClosed_(?:sound|call|unsupported|trace_keys))$', name):
            assert left.get(name) == right.get(name), (path, name)
            main_statements.append(dict(path=path, name=name))
    if '/Interval/' not in path:
        assert before == after, path
        unchanged[path] = hashlib.sha256(after.encode()).hexdigest()
assert [(item['path'], item['name'], item['after']) for item in changed_headers] == [
    ('formal/Benitoite/Interval/Sound.lean', 'target_at_operation', None)]

fixed_files = {}
for path in git('ls-files', 'crates/benitoite/testdata/interval-budget').splitlines():
    content = (ROOT / path).read_bytes()
    assert content == subprocess.check_output(['git', 'show', BASE + ':' + path], cwd=ROOT)
    fixed_files[path] = hashlib.sha256(content).hexdigest()
table_comparisons = {}
for name in ['body', 'whole', 'summary']:
    saved = (ROOT / 'crates/benitoite/testdata/interval-budget' / (name + '.tsv')).read_text()
    rows = [line for line in saved.splitlines() if not line.startswith('#')]
    actual = (OUT / 'reference-output' / (name + '-new.tsv')).read_text().splitlines()
    assert rows == actual, name
    table_comparisons[name] = dict(rows=len(rows), ordered_all_columns_equal=True)

additions = '\n'.join(line[1:] for line in git('diff', BASE, '--', 'formal').splitlines()
                      if line.startswith('+') and not line.startswith('+++'))
assert not re.search(r'\b(sorry|axiom|native_decide|implemented_by|admit|set_option)\b|@\[extern', additions)
assert git('diff', BASE, '--', 'crates', 'scripts', 'Cargo.toml', 'Cargo.lock', 'fuzz',
           'formal/lakefile.toml', 'formal/lean-toolchain').strip() == ''
assert git('diff', BASE, '--', str(OUT.parent.relative_to(ROOT) / 'plan.md'),
           str(OUT.parent.relative_to(ROOT) / 'decisions.md'),
           str(OUT.parent.relative_to(ROOT) / 'l25r')).strip() == ''
assert git('diff', '--cached', '--name-only').strip() == ''
assert git('rev-parse', 'HEAD').strip() == BASE
subprocess.run(['git', 'diff', '--check'], cwd=ROOT, check=True)
record = dict(base=BASE, protected=protected, changed_headers=changed_headers,
              main_statements=main_statements, unchanged_formal=unchanged,
              fixed_files=fixed_files, tables=table_comparisons,
              numstat=git('diff', BASE, '--numstat').splitlines())
(OUT / 'audit.json').write_text(json.dumps(record, ensure_ascii=False, indent=2) + '\n')
print(json.dumps(dict(protected=len(protected), unchanged_formal=len(unchanged),
                      main_statements=len(main_statements), changed_headers=changed_headers,
                      tables=table_comparisons), ensure_ascii=False, indent=2))
