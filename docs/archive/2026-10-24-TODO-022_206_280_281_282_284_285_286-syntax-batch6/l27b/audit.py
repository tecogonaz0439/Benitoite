"""基準との内容照合。git の変更操作は行わない。"""
from pathlib import Path
import ast, hashlib, json, re, subprocess, sys

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
BASE = '9f857805dab73e6253a3574d237b5c9b83711a87'

def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)

paths = ['formal', 'crates', 'fuzz', 'scripts', 'docs/design', 'Cargo.toml',
         'Cargo.lock', 'deny.toml', 'rust-toolchain.toml']
entries = git('ls-tree', '-r', '-z', BASE, '--', *paths).split(b'\0')
changed, checked, lean_theorems = [], 0, 0
for entry in filter(None, entries):
    metadata, name = entry.split(b'\t', 1)
    mode, kind, expected = metadata.decode().split()
    name = name.decode()
    if kind != 'blob' or mode == '120000':
        continue
    path = ROOT / name
    if not path.is_file():
        changed.append(name)
        continue
    data = path.read_bytes()
    actual = hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()
    if actual != expected:
        changed.append(name)
    if name.endswith('.lean'):
        lean_theorems += len(re.findall(rb'(?m)^\s*(?:(?:private|protected)\s+)?theorem\s+', data))
    checked += 1
assert changed == ['formal/lakefile.toml'], changed

before = git('show', BASE + ':formal/lakefile.toml').decode()
after = (ROOT / 'formal/lakefile.toml').read_text()
old_targets = re.search(r'^defaultTargets = (.*)$', before, re.M).group(1)
new_targets = re.search(r'^defaultTargets = (.*)$', after, re.M).group(1)
assert ast.literal_eval(new_targets) == ast.literal_eval(old_targets) + ['intervalDiff']
addition = '\n[[lean_exe]]\nname = "intervalDiff"\nroot = "IntervalDiff.Main"\n'
assert after == before.replace('defaultTargets = ' + old_targets,
                               'defaultTargets = ' + new_targets, 1) + addition
assert 'moreLeanArgs = ["-M", "12288"]' in after

main = ROOT / 'formal/IntervalDiff/Main.lean'
assert not re.search(r'\b(sorry|axiom)\b', main.read_text())
subprocess.run(['git', 'diff', '--check'], cwd=ROOT, check=True)
inputs = ['formal/IntervalDiff/Main.lean', 'formal/lakefile.toml',
          'formal/Benitoite/Interval/Exchange.lean',
          'formal/Benitoite/Interval/ExchangeExamples.lean', 'formal/Benitoite.lean']
hashes = {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in inputs}
snapshot = OUT / 'work-inputs-sha256.json'
if snapshot.exists():
    assert json.loads(snapshot.read_text()) == hashes, 'work inputs changed'
else:
    snapshot.write_text(json.dumps(hashes, indent=2) + '\n')
record = dict(base=BASE, head=git('rev-parse', 'HEAD').decode().strip(),
              checked_files=checked, changed=changed, unchanged_named_theorems=lean_theorems,
              old_executables=re.findall(r'\[\[lean_exe\]\]\nname = "([^"]+)"', before),
              new_executable=dict(name='intervalDiff', root='IntervalDiff.Main'),
              moreLeanArgs=['-M', '12288'],
              input_hashes_unchanged=True, diff_check='passed')
(OUT / sys.argv[1]).write_text(json.dumps(record, ensure_ascii=False, indent=2) + '\n')
print(json.dumps(record, ensure_ascii=False))
