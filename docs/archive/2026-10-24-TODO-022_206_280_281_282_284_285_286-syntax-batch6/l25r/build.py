"""依存順に一モジュールずつ検査し、Lake に未ビルドの依存を並行起動させない。"""
from pathlib import Path
import fcntl
import sys
import tempfile
import run

lock = open(Path(tempfile.gettempdir()) / 'benitoite-l20d-lean.lock', 'a')
fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
seen, order = set(), []
def visit(name):
    if name in seen:
        return
    seen.add(name)
    path = run.ROOT / 'formal' / (name.replace('.', '/') + '.lean')
    if not path.is_file():
        return
    for line in path.read_text().splitlines():
        if line.startswith('import '):
            for dependency in line[7:].split():
                visit(dependency)
    order.append(name)
for name in sys.argv[2:]:
    visit(name)
for index, name in enumerate(order):
    source = run.ROOT / 'formal' / (name.replace('.', '/') + '.lean')
    artifact = run.ROOT / 'formal/.lake/build/lib/lean' / (name.replace('.', '/') + '.olean')
    dependencies = []
    for line in source.read_text().splitlines():
        if line.startswith('import '):
            dependencies.extend(run.ROOT / 'formal/.lake/build/lib/lean' / (dep.replace('.', '/') + '.olean') for dep in line[7:].split())
    if artifact.is_file() and artifact.stat().st_mtime > source.stat().st_mtime and all(
            not dep.is_file() or dep.stat().st_mtime < artifact.stat().st_mtime for dep in dependencies):
        continue
    timeout = {'Benitoite.Interval.Examples': 25, 'Benitoite.Interval.Sound': 175}.get(name, 300)
    code = run.run(sys.argv[1] + '-' + name, ['lake', 'build', name], run.ROOT / 'formal', timeout)
    if code:
        raise SystemExit(code)
print(f'依存順の {len(order)} モジュールが終了0。', flush=True)
