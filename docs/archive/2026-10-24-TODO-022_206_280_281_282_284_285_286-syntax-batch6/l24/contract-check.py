"""開始版との全追跡差分と、保護した入力のバイト一致を確認する。"""
from pathlib import Path
import ast
import hashlib
import json
import re
import subprocess

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
BASE = '19a200f18c94e43e82b9e9b03fe088d377bad72a'


def git(*arguments):
    return subprocess.check_output(['git', *arguments], cwd=ROOT)


def sha256(content):
    return hashlib.sha256(content).hexdigest()


head = git('rev-parse', 'HEAD').decode().strip()
assert head == BASE
assert not git('diff', '--name-only', BASE, '--').strip()
assert not git('diff', '--cached', '--name-only').strip()
git('diff', '--check')
paths = git('ls-files', '-z', '--', 'formal', 'docs/design',
            'crates/benitoite/testdata/interval-budget').decode().split('\0')
inputs = {}
statements = 0
for name in filter(None, paths):
    content = (ROOT / name).read_bytes()
    original = git('show', f'{BASE}:{name}')
    assert content == original, name
    inputs[name] = sha256(content)
    if name.endswith('.lean'):
        statements += len(re.findall(r'(?m)^\s*(?:private\s+|protected\s+)?(?:theorem|lemma)\s+',
                                     content.decode()))

untracked = git('ls-files', '--others', '--exclude-standard', '-z').decode().split('\0')
prefix = str(OUT.relative_to(ROOT)) + '/'
assert all(name.startswith(prefix) for name in untracked if name)
for script in OUT.glob('*.py'):
    ast.parse(script.read_text())
evidence = (OUT / 'contract-obstruction.lean').read_text()
assert not re.search(r'\b(sorry|admit|axiom|native_decide)\b', evidence)
fixed = {path: digest for path, digest in inputs.items() if '/interval-budget/' in path}
record = dict(base=BASE, head=head, branch=git('symbolic-ref', '--short', 'HEAD').decode().strip(),
              tracked_diff=[], staged_diff=[], protected_files=len(inputs),
              unchanged_line_start_theorem_declarations=statements,
              fixed_table_files=fixed, protected_sha256=inputs,
              evidence_sha256=sha256(evidence.encode()),
              evidence_not_in_default_build=True,
              lean_version=subprocess.check_output(['lake', 'env', 'lean', '--version'],
                  cwd=ROOT / 'formal', text=True).strip(),
              rust_version=subprocess.check_output(['rustc', '--version'], cwd=ROOT, text=True).strip())
(OUT / 'contract-check.json').write_text(json.dumps(record, ensure_ascii=False, indent=2) + '\n')
print(json.dumps({key: value for key, value in record.items()
                  if key not in ['protected_sha256', 'fixed_table_files']}, ensure_ascii=False, indent=2))
