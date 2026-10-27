"""既存定義・主定理・公理と検査入力の保持を基準との差で確認する。"""
from pathlib import Path
import ast, hashlib, json, os, re, subprocess
OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
BASE = '258735b076842aebf3498505b7238be67a5fba31'
def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)
def digest(data):
    return hashlib.sha256(data).hexdigest()
entries = git('ls-tree', '-r', '-z', BASE, '--', 'formal', 'crates', 'Cargo.toml', 'Cargo.lock',
              'fuzz', 'rust-toolchain.toml').split(b'\0')
tracked = []
for entry in entries:
    if not entry:
        continue
    header, filename = entry.split(b'\t', 1)
    mode, kind, oid = header.split()
    assert kind == b'blob'
    tracked.append((filename.decode(), mode, oid.decode()))
checked, statements = [], 0
protected = {}
for filename, mode, oid in tracked:
    if filename == 'formal/Benitoite.lean':
        continue
    path = ROOT / filename
    after = os.readlink(path).encode() if mode == b'120000' else path.read_bytes()
    assert hashlib.sha1(b'blob '+str(len(after)).encode()+b'\0'+after).hexdigest() == oid, filename
    before = after
    checked.append(filename)
    if filename.endswith('.lean'):
        statements += len(re.findall(rb'(?m)^(?:private )?theorem ', before))
        if filename in ['formal/Benitoite/Interval/'+name+'.lean' for name in
                        ['Eval', 'Environment', 'Domain', 'RangeState', 'Sound', 'SyntacticReach']]:
            protected[filename] = dict(sha256=digest(after), unchanged=True)
root = 'formal/Benitoite.lean'
assert (ROOT / root).read_bytes() == git('show', BASE+':'+root) + b'\nimport Benitoite.Interval.Exchange\nimport Benitoite.Interval.ExchangeExamples\n'
new = ['formal/Benitoite/Interval/Exchange.lean', 'formal/Benitoite/Interval/ExchangeExamples.lean']
for filename in new:
    source = (ROOT / filename).read_text()
    assert not re.search(r'\b(sorry|axiom)\b', source), filename
    assert not re.search(r'(?m)^example|by (?:rfl|decide)|decide \+kernel', source), filename
subprocess.run(['git', 'diff', '--check', BASE], cwd=ROOT, check=True)
inputs = [root] + new + ['docs/design/01-spec/01-12-core-calculus.md',
                        'docs/design/07-quality/07-04-formal-semantics.md']
for filename in inputs:
    source = (ROOT / filename).read_text()
    assert source.endswith('\n') and all(line.rstrip() == line for line in source.splitlines()), filename
hashes = {filename: digest((ROOT / filename).read_bytes()) for filename in inputs}
previous = OUT / 'work-inputs-sha256.json'
if previous.is_file():
    assert json.loads(previous.read_text()) == hashes, 'work入力が変更された'
else:
    previous.write_text(json.dumps(hashes, indent=2)+'\n')
for path in OUT.iterdir():
    if path.is_file():
        source = path.read_text()
        assert str(ROOT) not in source and str(Path.home()) not in source, path.name
        if path.suffix == '.py':
            ast.parse(source)
report = dict(base=BASE, head=git('rev-parse', 'HEAD').decode().strip(),
    checked_existing_files=len(checked), unchanged_existing_named_theorems=statements,
    protected_definitions_files=protected, no_new_axiom_or_sorry=True,
    no_kernel_examples=True, rust_and_budget_tables_unchanged=True,
    old_six_entries_and_lakefile_unchanged=True, work_inputs_sha256=hashes,
    saved_paths_redacted=True, diff_check=True)
(OUT / 'audit.json').write_text(json.dumps(report, indent=2)+'\n')
print(json.dumps({k:v for k,v in report.items() if k not in ['protected_definitions_files', 'work_inputs_sha256']}, ensure_ascii=False))
