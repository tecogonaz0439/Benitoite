"""編集範囲、HEAD、ブランチ、実装・入力のハッシュを読み取り専用で確認する。"""
import hashlib
import json
from pathlib import Path
import subprocess

out = Path(__file__).parent
base = 'f6b0d974bfd80b834448325d8b8413824161a78c'

def git(*args):
    return subprocess.check_output(['git', '--no-optional-locks', *args])

tracked = git('diff', '--name-only', '-z').decode().strip('\0').split('\0')
untracked = git('ls-files', '--others', '--exclude-standard', '-z').decode().strip('\0').split('\0')
files = sorted(filter(None, set(tracked + untracked)))
chapters = {
    'docs/design/01-spec/01-06-type-system.md',
    'docs/design/01-spec/01-12-core-calculus.md',
    'docs/design/02-impl/02-05-typechecker.md',
    'docs/design/02-impl/02-10-diagnostics.md',
    'docs/design/07-quality/07-04-formal-semantics.md',
}
assert all(p.startswith(('crates/benitoite/', 'tools/bench/compare/', out.relative_to(Path.cwd()).as_posix() + '/')) or p in chapters for p in files)
assert git('rev-parse', 'HEAD').decode().strip() == base
assert git('branch', '--show-current').decode().strip() == 'm013/r20.5'
assert not git('diff', '--cached', '--name-only')
selected = [p for p in files if p.startswith('crates/benitoite/') or p in chapters]
hashes = {p: hashlib.sha256(Path(p).read_bytes()).hexdigest() for p in selected}
(out / 'checked-files.json').write_text(json.dumps(hashes, indent=2) + '\n')
index = Path(git('rev-parse', '--git-path', 'index').decode().strip())
record = dict(head=base, branch='m013/r20.5', staged_changes=[], changed_files=files,
              editing_scope_ok=True, index_sha256=hashlib.sha256(index.read_bytes()).hexdigest(),
              source_and_design_sha256=hashlib.sha256((out / 'checked-files.json').read_bytes()).hexdigest())
(out / 'final-state.json').write_text(json.dumps(record, indent=2) + '\n')
print(len(selected), 'implementation/design files; editing scope and git state verified')
