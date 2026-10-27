"""中心命題・既存公開定理・公理・固定入力を開始版と照合する。"""
from pathlib import Path
import hashlib, json, re, subprocess
OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
BASE = '9d18f7d233dbea603fcb6f1ea3ebbcf1c45d0e66'
def old(path):
    return subprocess.check_output(['git', 'show', f'{BASE}:{path}'], cwd=ROOT, text=True)
def declarations(text):
    result = {}
    for match in re.finditer(r'(?m)^(?:@\[[^\n]*\]\s*)?(private\s+)?(?:theorem|lemma)\s+([\w.]+)', text):
        depth, pos = 0, match.end()
        while pos < len(text):
            if text[pos] in '([{': depth += 1
            if text[pos] in ')]}': depth -= 1
            if depth == 0 and text[pos:pos+2] == ':=': break
            pos += 1
        result[match[2]] = (bool(match[1]), re.sub(r'\s+', ' ', text[match.start():pos]).strip())
    return result
paths = subprocess.check_output(['git', 'diff', '--name-only', BASE], cwd=ROOT, text=True).splitlines()
summary = {}
for path in paths:
    if not path.endswith('.lean'): continue
    assert path.startswith('formal/Benitoite/Interval/'), path
    before, after = declarations(old(path)), declarations((ROOT/path).read_text())
    changed = [name for name, declaration in before.items() if after.get(name) != declaration]
    public = [name for name in changed if not before[name][0]]
    assert not public, (path, public)
    summary[path] = {'existing_public_unchanged': sum(not d[0] for d in before.values()),
                     'private_auxiliary_statements_changed': changed,
                     'new_theorems': sorted(after.keys() - before.keys())}
    diff = subprocess.check_output(['git', 'diff', '--unified=0', BASE, '--', path], cwd=ROOT, text=True)
    assert not re.search(r'^\+(?!\+).*\b(?:axiom|sorry|admit)\b', diff, re.M), path
for name in ('NormalSoundness', 'WarningSoundness'):
    def extract(text):
        start = text.index('def ' + name)
        stop = text.find('\n/--', start)
        return text[start:stop if stop >= 0 else len(text)]
    path = 'formal/Benitoite/Interval/Eval.lean'
    assert extract(old(path)) == extract((ROOT/path).read_text()), name
fixed = ['formal/lakefile.toml'] + [f'crates/benitoite/testdata/interval-budget/{name}.tsv' for name in ('body', 'whole', 'summary')]
for path in fixed:
    assert old(path) == (ROOT/path).read_text(), path
for path in ('docs/design/01-spec/01-12-core-calculus.md', 'docs/design/07-quality/07-04-formal-semantics.md'):
    before, after = old(path), (ROOT/path).read_text()
    assert re.findall(r'^#+ .*$', before, re.M) == re.findall(r'^#+ .*$', after, re.M), path
    assert re.findall(r'```text\n.*?```', before, re.S) == re.findall(r'```text\n.*?```', after, re.S), path
print('B_WORK =', BASE)
print('HEAD =', subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip())
print(json.dumps(summary, ensure_ascii=False, indent=2))
print('NormalSoundness/WarningSoundness: full definition bodies identical')
print('Existing public theorem statements: identical; no new axiom/sorry/admit')
print('Outside Interval: no Lean changes; lakefile -M 12288 and three fixed tables: identical')
print('Document headings/text fences: identical')
print('Fixed SHA-256:', json.dumps({p: hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in fixed}, indent=2))
