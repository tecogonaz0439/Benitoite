"""開始版とC4前の基準について、主定理・参照定義・固定表の差分を記録する。"""
from pathlib import Path
import hashlib
import json
import re
import subprocess
import run
ROOT, OUT, BASE = run.ROOT, run.OUT, run.BASE
PRIOR = 'be57d4e92d7a48fb74dc33a4d3c3867b60207aeb'

def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, text=True)

def old(base, path):
    return git('show', base + ':' + path)

def declaration(source, name):
    found = re.search(r'(?m)^(?:private )?(?:def|inductive|structure|theorem) ' + re.escape(name) + r'(?=\s|\{|\()', source)
    assert found, name
    end = re.search(r'(?m)^(?:/--|/\*!|-- |end\b|(?:private )?(?:def|inductive|structure|theorem|example|instance)\b)', source[found.end():])
    return source[found.start():found.end()+end.start() if end else len(source)].strip()

protected = {}
for path, names in {
    'formal/Benitoite/Interval/Eval.lean': ['NormalSoundness', 'WarningSoundness', 'ConcreteValue', 'ConcreteValue.type', 'EvalInput', 'Reached'],
    'formal/Benitoite/Interval/Environment.lean': ['Models', 'SlotModels', 'AbstractSlot', 'AbstractEnv'],
    'formal/Benitoite/Interval/Sound.lean': ['targetOperationAt', 'arithmeticOperationAt', 'WarningLocated'],
}.items():
    source = (ROOT/path).read_text()
    for name in names:
        before, after = declaration(old(BASE, path), name), declaration(source, name)
        assert before == after, (path, name)
        protected[name] = dict(sha256=hashlib.sha256(after.encode()).hexdigest(),
            same_as_work=True, same_as_prior=(declaration(old(PRIOR, path), 'targetOperationAt').replace('targetOperationAt', 'arithmeticOperationAt') == after if name == 'arithmeticOperationAt' else declaration(old(PRIOR, path), name) == after)
            if name not in ['targetOperationAt', 'WarningLocated'] else False)

paths = git('ls-files', 'formal').splitlines()
headers = {}
for version in [BASE, PRIOR, 'current']:
    table = {}
    for path in paths:
        if not path.endswith('.lean'):
            continue
        if version == 'current':
            if not (ROOT/path).is_file():
                continue
            source = (ROOT/path).read_text()
        else:
            proc = subprocess.run(['git', 'show', version+':'+path], cwd=ROOT, text=True, capture_output=True)
            if proc.returncode:
                continue
            source = proc.stdout
        for found in re.finditer(r'(?m)^(?:@\[[^\n]*?\] )?(theorem|lemma) ([\w.\x27]+)\b', source):
            tail, depth, end = source[found.start():], 0, None
            for index, char in enumerate(tail):
                if char in '({[':
                    depth += 1
                elif char in ')}]':
                    depth -= 1
                if depth == 0 and tail[index:index+2] == ':=':
                    end = index
                    break
            if end is not None:
                table[(path, found.group(2))] = re.sub(r'\s+', ' ', tail[:end].strip())
    headers[version] = table
changes = {}
for version in [BASE, PRIOR]:
    rows = []
    for (path, name), before in headers[version].items():
        after = headers['current'].get((path, name))
        if before != after:
            moves = [list(key) for key, header in headers['current'].items() if header == before] if after is None else []
            rows.append(dict(path=path, name=name, before=before, after=after, moved=moves))
    changes[version] = rows

# 公開の入口にある正常値・警告原因・位置・範囲・独立入力の主定理を照合する。
main_pattern = r'^(analyze(?:Base|Expr|Body)?_(?:normal_sound|warning_sound|warning_located|warning_syntactic_reach|warning_call_reach|independent_sound|unrecognized_call_warnings)|analyzeBody_(?:normal|property)|evalClosed_(?:sound|call|unsupported|trace_keys))$'
main_checks = {}
for version in [BASE, PRIOR]:
    mains = {key: value for key, value in headers[version].items() if re.match(main_pattern, key[1]) and not (version == PRIOR and key[1] in ['analyzeBody_warning_located', 'analyzeExpr_warning_located'])}
    for key, header in mains.items():
        assert header in headers['current'].values(), (version, key)
    main_checks[version] = [list(key) for key in mains]

unchanged = {}
for path in paths:
    if path == 'formal/Benitoite.lean' or path.startswith('formal/Benitoite/Interval/'):
        continue
    content = (ROOT/path).read_bytes()
    assert content == subprocess.check_output(['git', 'show', BASE+':'+path], cwd=ROOT), path
    assert content == subprocess.check_output(['git', 'show', PRIOR+':'+path], cwd=ROOT), path
    unchanged[path] = hashlib.sha256(content).hexdigest()
fixtures = {}
for path in git('ls-files', 'crates/benitoite/testdata/interval-budget').splitlines():
    content = (ROOT/path).read_bytes()
    assert content == subprocess.check_output(['git', 'show', BASE+':'+path], cwd=ROOT), path
    fixtures[path] = hashlib.sha256(content).hexdigest()
violations = []
for path in (ROOT/'formal').rglob('*.lean'):
    if '.lake' in path.parts:
        continue
    source = path.read_text()
    source = re.sub(r'/-.*?-/', '', source, flags=re.S)
    source = re.sub(r'--[^\n]*', '', source)
    if re.search(r'\b(sorry|admit|axiom|native_decide)\b', source):
        relative = str(path.relative_to(ROOT))
        if relative == 'formal/Benitoite/Interval/Budget.lean' and path.read_text() == old(BASE, relative):
            continue  # 既存の予算関数 Budget.admit。
        violations.append(relative)
assert not violations, violations
assert git('diff', '--cached', '--name-only').strip() == ''
assert git('diff', BASE, '--', 'crates', 'scripts', 'Cargo.toml', 'Cargo.lock', 'fuzz').strip() == ''
assert git('diff', BASE, '--', 'formal/lakefile.toml').strip() == ''
assert git('diff', BASE, '--', str(OUT.parent.relative_to(ROOT)/'plan.md'), str(OUT.parent.relative_to(ROOT)/'decisions.md')).strip() == ''
assert git('rev-parse', 'HEAD').strip() == BASE
subprocess.run(['git', 'diff', '--check'], cwd=ROOT, check=True)
record = dict(base=BASE, prior=PRIOR, head=git('rev-parse', 'HEAD').strip(),
    protected=protected, main_statements=main_checks, header_changes=changes,
    unchanged_formal=unchanged, fixed_files=fixtures, forbidden_proof_commands=violations,
    changed_files=git('diff', BASE, '--name-only').splitlines())
(OUT/'audit.json').write_text(json.dumps(record, ensure_ascii=False, indent=2)+'\n')
print(json.dumps(dict(protected=list(protected), main_counts={k:len(v) for k,v in main_checks.items()},
    header_changes={k:[(r['path'].split('/')[-1],r['name'],bool(r['moved']),r['after'] is not None) for r in v] for k,v in changes.items()}), ensure_ascii=False,indent=2))
