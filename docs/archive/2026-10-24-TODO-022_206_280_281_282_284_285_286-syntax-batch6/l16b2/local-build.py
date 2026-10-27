"""ローカルの import を依存順に一モジュールずつビルドする。"""
from pathlib import Path
import subprocess, sys, time
OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2] / 'formal'
seen, order = set(), []
def visit(name):
    if name in seen:
        return
    seen.add(name)
    path = ROOT / (name.replace('.', '/') + '.lean')
    if not path.is_file():
        return
    for line in path.read_text().splitlines():
        if line.startswith('import '):
            for dependency in line[7:].split():
                visit(dependency)
    order.append(name)
if len(sys.argv) > 1:
    for name in sys.argv[1:]:
        visit(name)
else:
    for path in sorted(ROOT.rglob('*.lean')):
        if '.lake' not in path.parts and 'docs' not in path.parts:
            visit('.'.join(path.relative_to(ROOT).with_suffix('').parts))
started = time.monotonic()
with (OUT / 'sequential-build.log').open('a') as log:
    for name in order:
        log.write('\n$ lake build ' + name + '\n')
        log.flush()
        before = time.monotonic()
        result = subprocess.run(['lake', 'build', name], cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
        log.write(f'\nexit={result.returncode}, seconds={time.monotonic() - before:.3f}\n')
        log.flush()
        if result.returncode:
            print(f'FAILED {name}', flush=True)
            raise SystemExit(result.returncode)
print(f'OK: {len(order)} modules, {time.monotonic() - started:.3f} seconds', flush=True)
